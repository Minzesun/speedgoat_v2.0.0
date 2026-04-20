# speedgoat_v2_minimal 模型逻辑显式说明

本文档用于学习和复盘 `speedgoat_v2_minimal` 的搭建逻辑。它描述的是当前代码生成出来的 Simulink Real-Time 模型，而不是额外的新功能。

核心边界：

- 目标应用名：`speedgoat_v2_minimal`
- 目标文件：`matlab/model/models/speedgoat_v2_minimal.slx`
- 本地构建产物：`matlab/speedgoat_v2_minimal.mldatx`
- 运行方式：以 `slrtExplorer` 加载、启动、观察和人工下发速度
- 控制对象：单轴 SV660N，CSV 模式
- EtherCAT 数据面：只使用 `1702h Outputs + 1B04h Inputs`
- 自动逻辑边界：自动上电/上使能到 `ready_to_run`，非零速度仍由人工给定

## 1. 代码入口和生成链路

### 1.1 顶层入口

生成模型的入口是：

```matlab
matlab/model/build_speedgoat_v2_minimal.m
```

它只做一件事：

```matlab
modelPath = sgv2.internal.buildMinimalModel(target_minimal_slrtexplorer());
```

也就是说，模型不是手工拖出来的，而是由配置合同 `target_minimal_slrtexplorer()` 驱动生成。

### 1.2 配置合同

配置入口是：

```matlab
matlab/config/target_minimal_slrtexplorer.m
```

它组合了三类信息：

- 项目默认值：`project_defaults.m`
- 单轴配置：`axes/sv660n_axis1.m`
- EtherCAT/ENI/PDO 合同：
  - `ethercat/sv660n_eni_contract.m`
  - `ethercat/sv660n_pdo_map.m`

关键配置值：

| 项 | 当前值 | 含义 |
|---|---:|---|
| `ModelName` | `speedgoat_v2_minimal` | Simulink 模型名 |
| `ApplicationName` | `speedgoat_v2_minimal` | SLRT 应用名 |
| `SampleTime` | `0.002` | 2 ms 固定步长 |
| `ExpectedNetworkState` | `8` | EtherCAT 期望 OP 状态 |
| `ExpectedModeOfOperation` | `9` | CSV 模式 |
| `SGV2_SPEED_COMMAND_60FF` | `int32(0)` 默认 | 人工速度命令 |
| `SGV2_SPEED_LIMIT_607F` | `uint32(1000)` 默认 | 保守速度上限 |

### 1.3 模型生成函数

真正创建 Simulink 模型的是：

```matlab
matlab/model/+sgv2/+internal/buildMinimalModel.m
```

它的主要步骤：

1. 创建或覆盖 `speedgoat_v2_minimal` 模型。
2. 设置为固定步长离散模型。
3. 设置目标文件为 `slrealtime.tlc`。
4. 把默认 tunable 写进 model workspace：
   - `SGV2_SPEED_COMMAND_60FF = int32(0)`
   - `SGV2_SPEED_LIMIT_607F = uint32(1000)`
5. 添加 EtherCAT Init / Get State / PDO Rx / PDO Tx。
6. 添加 `SV660N Sequence Controller` 子系统。
7. 添加人工命令 Constant。
8. 添加顶层观察 Outport。
9. 保存为 `.slx`。

## 2. 顶层模型结构

可以把顶层模型理解成四个区域：

```text
+---------------------------------------------------------------+
| speedgoat_v2_minimal                                          |
|                                                               |
|  EtherCAT Init                                                |
|  EtherCAT Get State  ---- actual_network_state ---------------+----> observability
|                                                               |
|  PDO Receive 603F ---- error_code_603f ----+                  |
|  PDO Receive 6041 ---- statusword_6041 ----+                  |
|  PDO Receive 6061 ---- mode_display_6061 --+                  |
|  PDO Receive 606C ---- velocity_actual ----+                  |
|                                            |                  |
|  Manual Constants                          v                  |
|    expected_network_state ----------> SV660N Sequence          |
|    speed_command_60ff -------------> Controller               |
|    speed_limit_607f --------------->                         |
|                                            |                  |
|                                            v                  |
|  PDO Transmit 6040 <---- controlword_6040                     |
|  PDO Transmit 60FF <---- velocity_command_60ff                |
|  PDO Transmit 6060 <---- mode_command_6060                    |
|  PDO Transmit 607F <---- speed_limit_out_607f                 |
|                                                               |
+---------------------------------------------------------------+
```

更直白地说：

- 左侧从 EtherCAT/驱动读状态。
- 中间 `StartupChart` 判断当前能不能运行。
- 右侧把控制字、速度、模式、速度上限写回驱动。
- 顶层 Outport 把关键变量暴露给 `slrtExplorer` 看。

## 3. EtherCAT I/O 逻辑

实现文件：

```matlab
matlab/model/+sgv2/+internal/addEthercatIo.m
```

### 3.1 EtherCAT Init

模型中添加 `EtherCAT Init` 块。

关键参数来自 `sv660n_eni_contract.m`：

| 参数 | 当前值 | 含义 |
|---|---:|---|
| `config_file` | `matlab/config/ethercat/eni/ENI2.xml` | ENI 文件 |
| `device_id` | `0` | EtherCAT device index |
| `portnum` | `1` | Speedgoat Ethernet port |
| `initstate` | `2` | 初始化状态参数 |
| `enaDC` | `on` | 启用 DC |
| `DCMode` | `2` | DC 模式 |
| `sample_time` | `0.002` | 2 ms |

### 3.2 EtherCAT Get State

模型中添加 `EtherCAT Get State` 块，输出接入 Startup chart 的第 1 个输入：

```text
actual_network_state -> StartupChart input 1
```

如果它不等于 `expected_network_state = 8`，Startup chart 会认为 EtherCAT 未到 OP。

### 3.3 PDO Receive: 从驱动读

`1B04h Inputs` 当前只取四个量：

| 信号 | 对象 | 偏移 | 类型 | 进入 chart |
|---|---|---:|---|---|
| `error_code_603f` | `603Fh` Error code | `568` | `uint16` | input 4 |
| `statusword_6041` | `6041h` Statusword | `584` | `uint16` | input 3 |
| `mode_display_6061` | `6061h` Mode display | `648` | `int8` | input 5 |
| `velocity_actual_606c` | `606Ch` Actual velocity | `768` | `int32` | input 6 |

### 3.4 PDO Transmit: 写给驱动

`1702h Outputs` 当前只写四个量：

| 信号 | 对象 | 偏移 | 类型 | 来自 chart |
|---|---|---:|---|---|
| `controlword_6040` | `6040h` Controlword | `568` | `uint16` | output 1 |
| `velocity_command_60ff` | `60FFh` Target velocity | `616` | `int32` | output 2 |
| `mode_command_6060` | `6060h` Mode of operation | `664` | `int8` | output 3 |
| `speed_limit_out_607f` | `607Fh` Max profile velocity | `688` | `uint32` | output 4 |

## 4. 人工命令入口

实现文件：

```matlab
matlab/model/+sgv2/+internal/addManualCommandInterface.m
```

模型里有三个 Constant 作为人工或配置输入：

| 模型块 | 值 | 接入 chart |
|---|---|---|
| `command_expected_network_state` | `int32(8)` | input 2 |
| `command_speed_command_60ff` | `SGV2_SPEED_COMMAND_60FF` | input 7 |
| `command_speed_limit_607f` | `SGV2_SPEED_LIMIT_607F` | input 8 |

其中：

- `SGV2_SPEED_COMMAND_60FF` 默认是 `int32(0)`。
- `SGV2_SPEED_LIMIT_607F` 默认是 `uint32(1000)`。
- 这两个变量被写入 model workspace，所以 `slbuild` 不需要用户手工 `assignin('base', ...)`。

现场操作时，非零速度由人在 `slrtExplorer` 中改 `speed_command_60ff`。

## 5. StartupChart 输入输出

Startup chart 由下面这个函数生成：

```matlab
matlab/model/+sgv2/+internal/buildStartupChart.m
```

### 5.1 输入

| 端口 | 名称 | 类型 | 含义 |
|---:|---|---|---|
| 1 | `actual_network_state` | `int32` | EtherCAT 实际状态 |
| 2 | `expected_network_state` | `int32` | 期望 EtherCAT 状态，当前为 8 |
| 3 | `statusword_6041` | `uint16` | 驱动状态字 |
| 4 | `error_code_603f` | `uint16` | 驱动错误码 |
| 5 | `mode_display_6061` | `int8` | 驱动当前模式 |
| 6 | `velocity_actual_606c` | `int32` | 实际速度，当前只观察，不参与判定 |
| 7 | `speed_command_60ff` | `int32` | 人工速度命令 |
| 8 | `speed_limit_607f` | `uint32` | 速度上限 |

### 5.2 输出

| 端口 | 名称 | 类型 | 含义 |
|---:|---|---|---|
| 1 | `controlword_6040` | `uint16` | 写给驱动的控制字 |
| 2 | `velocity_command_60ff` | `int32` | 写给驱动的目标速度 |
| 3 | `mode_command_6060` | `int8` | 写给驱动的运行模式，固定 CSV=9 |
| 4 | `speed_limit_out_607f` | `uint32` | 写给驱动的速度上限 |
| 5 | `ready_to_run` | `uint8` | 是否允许人工速度生效 |
| 6 | `auto_start_step` | `uint8` | 自动起机步骤 |
| 7 | `diag_code` | `uint8` | 诊断码 |
| 8 | `diag_message_id` | `uint8` | 诊断消息 ID |
| 9 | `diag_lookup_group` | `uint8` | 建议查哪类手册/对象 |
| 10 | `diag_lookup_hint` | `uint8[1x48]` | 给 slrtExplorer 看的文字提示 |

## 6. StartupChart 每个周期的默认动作

每个 2 ms 周期进入 chart 时，先设一组安全默认值：

```matlab
controlword_6040       = disable_voltage;  % 0x0000
velocity_command_60ff  = int32(0);
mode_command_6060      = int8(9);          % CSV
speed_limit_out_607f   = speed_limit_607f;
ready_to_run           = uint8(0);
auto_start_step        = WAIT_BUS_OP;
diag_code              = NONE;
diag_message_id        = NONE;
diag_lookup_group      = NONE;
diag_lookup_hint       = zeros(1, 48);
```

然后进入一串 `if / elseif` 判定。后面的分支只有在前面的条件不满足时才会继续判断。

## 7. StartupChart 判定逻辑展开

### 7.1 第一优先级：EtherCAT 是否 OP

```matlab
if actual_network_state ~= expected_network_state
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `WAIT_BUS_OP = 1` |
| `diag_code` | `BUS_NOT_OP = 1` |
| `diag_message_id` | `CHECK_ETHERCAT_STATE = 10` |
| `diag_lookup_group` | `ETHERCAT = 1` |
| `controlword_6040` | `0x0000` |
| `velocity_command_60ff` | `0` |
| `ready_to_run` | `0` |

含义：总线没有到 OP，先不要碰驱动使能。

### 7.2 第二优先级：驱动是否报 603F 错误

```matlab
elseif error_code_603f ~= 0
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `WAIT_DRIVE_CLEAR = 2` |
| `diag_code` | `DRIVE_ERROR = 2` |
| `diag_message_id` | `CHECK_603F = 20` |
| `diag_lookup_group` | `ERROR_CODE_603F = 2` |
| `controlword_6040` | `0x0000` |
| `velocity_command_60ff` | `0` |
| `ready_to_run` | `0` |

含义：驱动自己报了错误码。当前模型不主动发 fault reset，只等待错误消失。

你昨天看到的：

```text
error_code_603f = 12848 = 0x3230
auto_start_step = 2
diag_code = 2
diag_message_id = 20
diag_lookup_group = 2
```

正是这条分支。

### 7.3 第三优先级：Statusword 是否进入 fault

```matlab
elseif statusState(statusword_6041) >= faultStatusSentinel()
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `WAIT_DRIVE_CLEAR = 2` |
| `diag_code` | `DRIVE_FAULT = 3` |
| `diag_message_id` | `CHECK_6041 = 30` |
| `diag_lookup_group` | `STATUSWORD_6041 = 3` |
| `controlword_6040` | `0x0000` |
| `velocity_command_60ff` | `0` |
| `ready_to_run` | `0` |

含义：即使 603F 没有非零，只要状态字显示故障，也停在等待驱动清除。

### 7.4 第四优先级：Switch on disabled

```matlab
elseif statusState(statusword_6041) == 1
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `AUTO_POWER_ON = 3` |
| `controlword_6040` | `shutdown = 0x0006` |
| `velocity_command_60ff` | `0` |
| `ready_to_run` | `0` |

含义：驱动还没进入 ready 状态，先发 shutdown，让 CiA402 往 ready to switch on 走。

### 7.5 第五优先级：Ready to switch on

```matlab
elseif statusState(statusword_6041) == 2
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `AUTO_ENABLE = 4` |
| `controlword_6040` | `switch_on = 0x0007` |
| `velocity_command_60ff` | `0` |
| `ready_to_run` | `0` |

含义：驱动已经 ready，发 switch on。

### 7.6 第六优先级：Switched on

```matlab
elseif statusState(statusword_6041) == 3
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `AUTO_ENABLE = 4` |
| `controlword_6040` | `enable_operation = 0x000F` |
| `velocity_command_60ff` | `0` |
| `ready_to_run` | `0` |

含义：驱动已经 switched on，发 enable operation。

### 7.7 第七优先级：Operation enabled 但模式不对

```matlab
elseif statusState(statusword_6041) == 4 && mode_display_6061 ~= 9
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `AUTO_ENABLE = 4` |
| `controlword_6040` | `enable_operation = 0x000F` |
| `velocity_command_60ff` | `0` |
| `ready_to_run` | `0` |
| `diag_code` | `MODE_MISMATCH = 4` |
| `diag_message_id` | `CHECK_6061 = 40` |
| `diag_lookup_group` | `MODE_DISPLAY_6061 = 4` |

含义：驱动虽然 enable 了，但还不是 CSV 模式，所以不给速度。

### 7.8 第八优先级：真正 ready

```matlab
elseif statusState(statusword_6041) == 4
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `READY_TO_RUN = 5` |
| `controlword_6040` | `enable_operation = 0x000F` |
| `velocity_command_60ff` | `speed_command_60ff` |
| `ready_to_run` | `1` |
| `diag_code` | `0` |
| `diag_message_id` | `0` |
| `diag_lookup_group` | `0` |

含义：只有到了这里，人工输入的 `speed_command_60ff` 才真正传给驱动的 `60FFh`。

### 7.9 兜底分支

```matlab
else
```

动作：

| 输出 | 值 |
|---|---|
| `auto_start_step` | `WAIT_DRIVE_CLEAR = 2` |
| `diag_code` | `WAITING_ENABLE = 5` |
| `diag_message_id` | `CHECK_6041 = 30` |
| `diag_lookup_group` | `STATUSWORD_6041 = 3` |
| `controlword_6040` | `0x0000` |
| `velocity_command_60ff` | `0` |
| `ready_to_run` | `0` |

含义：状态字不属于当前支持的 CiA402 正常路径，先安全等待。

## 8. Statusword 解码逻辑

实现文件：

```matlab
matlab/model/+sgv2/statusState.m
```

它不是直接比较完整状态字，而是按 CiA402 常见掩码取关键 bit。

| `statusState()` 返回 | 判定 | 含义 |
|---:|---|---|
| `10` | `(statusword & 0x004F) == 0x0008` | fault |
| `4` | `(statusword & 0x006F) == 0x0027` | operation enabled |
| `3` | `(statusword & 0x006F) == 0x0023` | switched on |
| `2` | `(statusword & 0x006F) == 0x0021` | ready to switch on |
| `1` | `(statusword & 0x004F) == 0x0040` | switch on disabled |
| `0` | 其他 | 未识别状态 |

你现场看到的几个值：

| 十进制 | 十六进制 | 解码结果 | chart 行为 |
|---:|---:|---:|---|
| `5687` | `0x1637` | `4` | `READY_TO_RUN = 5`，速度命令生效 |
| `5840` | `0x16D0` | 不作为主因，因为 `603F != 0` 先命中 | `WAIT_DRIVE_CLEAR = 2` |
| `5681` | `0x1631` | `2` | `AUTO_ENABLE = 4`，发 `0x0007` |
| `5683` | `0x1633` | `3` | `AUTO_ENABLE = 4`，发 `0x000F` |

## 9. Controlword 输出逻辑

实现文件：

```matlab
matlab/model/+sgv2/controlword.m
```

当前只支持四个控制字：

| 名称 | 值 | 作用 |
|---|---:|---|
| `disable_voltage` | `0x0000` | 安全默认，不使能 |
| `shutdown` | `0x0006` | 推进到 ready to switch on |
| `switch_on` | `0x0007` | 推进到 switched on |
| `enable_operation` | `0x000F` | 推进到 operation enabled |

注意：当前模型没有发 fault reset 控制字。因此，如果 `603F` 出错后又恢复，是驱动侧错误清除了，模型再按正常状态机重新上使能，不是模型主动复位故障。

## 10. 诊断码映射

### 10.1 auto_start_step

实现文件：

```matlab
matlab/model/+sgv2/+internal/autoStartStepIds.m
```

| 值 | 名称 | 含义 |
|---:|---|---|
| `1` | `WAIT_BUS_OP` | 等 EtherCAT OP |
| `2` | `WAIT_DRIVE_CLEAR` | 等驱动错误/故障清除 |
| `3` | `AUTO_POWER_ON` | 自动发 shutdown |
| `4` | `AUTO_ENABLE` | 自动发 switch on / enable operation |
| `5` | `READY_TO_RUN` | 可以人工给速度 |

### 10.2 diag_code

实现文件：

```matlab
matlab/model/+sgv2/+internal/diagCodes.m
```

| 值 | 名称 | 含义 |
|---:|---|---|
| `0` | `NONE` | 无诊断 |
| `1` | `BUS_NOT_OP` | EtherCAT 未 OP |
| `2` | `DRIVE_ERROR` | `603Fh` 非零 |
| `3` | `DRIVE_FAULT` | `6041h` 显示 fault |
| `4` | `MODE_MISMATCH` | `6061h` 不是 CSV=9 |
| `5` | `WAITING_ENABLE` | 状态字暂不在支持路径 |

### 10.3 diag_message_id

实现文件：

```matlab
matlab/model/+sgv2/+internal/diagMessageIds.m
```

| 值 | 名称 | 查什么 |
|---:|---|---|
| `0` | `NONE` | 不需要查 |
| `10` | `CHECK_ETHERCAT_STATE` | EtherCAT 状态机 |
| `20` | `CHECK_603F` | SV660N 的 `603Fh` 错误码 |
| `30` | `CHECK_6041` | SV660N 的 `6041h` 状态字 |
| `40` | `CHECK_6061` | SV660N 的 `6061h` 模式显示 |

### 10.4 diag_lookup_group

实现文件：

```matlab
matlab/model/+sgv2/+internal/diagLookupGroups.m
```

| 值 | 名称 | 含义 |
|---:|---|---|
| `0` | `NONE` | 无诊断 |
| `1` | `ETHERCAT` | 查 EtherCAT |
| `2` | `ERROR_CODE_603F` | 查 `603Fh` |
| `3` | `STATUSWORD_6041` | 查 `6041h` |
| `4` | `MODE_DISPLAY_6061` | 查 `6061h` |

## 11. 顶层观察口

实现文件：

```matlab
matlab/model/+sgv2/+internal/addObservabilityPorts.m
```

这些信号被做成模型顶层 Outport，方便 `slrtExplorer` 直接看：

| 顶层信号 | 来源 |
|---|---|
| `actual_network_state` | EtherCAT Get State |
| `expected_network_state` | Constant `int32(8)` |
| `statusword_6041` | PDO Rx |
| `error_code_603f` | PDO Rx |
| `mode_display_6061` | PDO Rx |
| `velocity_actual_606c` | PDO Rx |
| `diag_code` | StartupChart |
| `diag_message_id` | StartupChart |
| `diag_lookup_group` | StartupChart |
| `diag_lookup_hint` | StartupChart 外部 lookup 网络 |
| `ready_to_run` | StartupChart |
| `auto_start_step` | StartupChart |
| `speed_command_60ff` | 人工命令 Constant |
| `speed_limit_607f` | 人工命令 Constant |

## 12. 一次正常启动的信号路径

正常情况下大概是：

```text
1. EtherCAT actual_network_state == 8
2. error_code_603f == 0
3. statusword_6041 从 switch on disabled / ready / switched on 推进
4. chart 依次输出：
   0x0006 -> 0x0007 -> 0x000F
5. statusword_6041 被识别为 operation enabled
6. mode_display_6061 == 9
7. ready_to_run = 1
8. velocity_command_60ff = speed_command_60ff
```

简化成状态推进：

```text
WAIT_BUS_OP
  -> AUTO_POWER_ON
  -> AUTO_ENABLE
  -> READY_TO_RUN
```

## 13. 你昨天现场现象对应的模型解释

你描述的异常序列：

```text
正常：statusword = 5687, speed = command, step = 5, ready = 1
异常：statusword = 5840, error_code_603f = 12848, actual speed = 3
恢复1：statusword = 5681, error = 0, speed = 0, step = 4
恢复2：statusword = 5683, error = 0, speed = 0, step = 4
恢复3：statusword = 5687, error = 0, speed = command, step = 5, ready = 1
```

按当前模型逻辑解释：

1. `5687 = 0x1637` 被识别为 operation enabled。
2. `ready_to_run = 1`，所以人工速度命令生效。
3. 后来 `error_code_603f = 12848 = 0x3230`，chart 优先命中 `error_code_603f ~= 0`。
4. chart 输出：
   - `auto_start_step = 2`
   - `diag_code = 2`
   - `diag_message_id = 20`
   - `diag_lookup_group = 2`
   - `velocity_command_60ff = 0`
   - `ready_to_run = 0`
5. 驱动侧错误消失后，`603Fh` 回到 0。
6. 状态字变成 `5681 = 0x1631`，被识别为 ready to switch on，于是 chart 发 `0x0007`。
7. 状态字变成 `5683 = 0x1633`，被识别为 switched on，于是 chart 发 `0x000F`。
8. 状态字回到 `5687 = 0x1637`，chart 重新进入 `READY_TO_RUN`，速度命令重新生效。

因此，这个循环不是 chart 自己随机跳变，而是驱动先报了 `603Fh` 错误，然后 chart 按设计把速度清零、等待错误消失、再重新使能。

## 14. 当前模型刻意没有做的事

这些不是遗漏，是第一版边界：

- 不改 ENI。
- 不自动查询或解释 SV660N 详细错误码。
- 不发 fault reset。
- 不做自动速度曲线。
- 不在出错后锁存停机。
- 不做 MATLAB host helper。
- 不做多轴。
- 不做 TwinCAT。
- 不引入旧 `demo_stable`。

如果后续要增强现场调试能力，最值得加的是：

- 故障锁存：一旦 `603Fh != 0`，保持停机，等待人工复位。
- 首次故障快照：锁存第一次出现故障时的 `603Fh / 6041h / 6061h / 606Ch / command`。
- 运行计时器：记录从 `READY_TO_RUN` 到故障出现的时间。
- 可调速度斜坡：避免人工速度阶跃太硬。

