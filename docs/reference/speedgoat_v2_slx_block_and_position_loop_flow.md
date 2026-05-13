# speedgoat_v2_minimal SLX 块功能与位置环信号流说明

本文对应当前生成模型：

```text
matlab/model/models/speedgoat_v2_minimal.slx
```

模型由 `matlab/model/build_speedgoat_v2_minimal.m` 生成。当前版本已经不再使用 Stateflow Chart；启动逻辑和位置环中较复杂的状态更新逻辑改为 MATLAB Function 块，简单算术、比较、限幅、切换、延迟和数据类型转换尽量使用 Simulink 基础块。

## 1. 顶层模型整体信号流

顶层模型可以按从左到右理解：

```text
EtherCAT Init / Get State / PDO Receive
    -> SV660N Sequence Controller
    -> PDO Transmit

position_command_6064 / position_actual_6064
    -> PT-5 Position Loop
    -> position_loop_speed_command_60ff_delay
    -> SV660N Sequence Controller speed_command_60ff 输入
    -> Tx Target velocity 60FF
```

`SV660N Sequence Controller` 负责总线状态、驱动状态、模式和诊断门禁。只有它输出 `ready_to_run == 1` 时，`PT-5 Position Loop` 才允许闭环速度命令生效。

`PT-5 Position Loop` 输出的 `position_loop_speed_command_60ff` 会先经过顶层 `position_loop_speed_command_60ff_delay` 延迟一拍，再送入启动控制器的 `speed_command_60ff` 输入。这一拍延迟用于打断位置环和启动控制器之间的直接反馈路径。

## 2. 顶层块功能

| 块名 | 类型 | 功能 |
|---|---|---|
| `EtherCAT Init` | EtherCAT Init S-Function | 载入 ENI 文件并初始化 Speedgoat EtherCAT 主站，设置 device、端口、DC 和采样时间。 |
| `EtherCAT Get State` | EtherCAT Get State S-Function | 读取 EtherCAT 网络当前状态，输出到 `actual_network_state` 和启动控制器输入 1。 |
| `Rx Error code 603F` | EtherCAT PDO Receive | 从驱动 `603Fh` 读取错误码 `error_code_603f`。 |
| `Rx Statusword 6041` | EtherCAT PDO Receive | 从驱动 `6041h` 读取状态字 `statusword_6041`。 |
| `Rx Position actual 6064` | EtherCAT PDO Receive | 从驱动 `6064h` 读取实际位置 `position_actual_6064`，同时进入位置环。 |
| `Rx Mode display 6061` | EtherCAT PDO Receive | 从驱动 `6061h` 读取当前运行模式 `mode_display_6061`。 |
| `Rx Velocity actual 606C` | EtherCAT PDO Receive | 从驱动 `606Ch` 读取实际速度 `velocity_actual_606c`，当前主要用于观测。 |
| `SV660N Sequence Controller` | Subsystem | 启动、使能、故障诊断和速度命令门禁子系统。 |
| `PT-5 Position Loop` | Subsystem | 外层位置环子系统，计算位置误差、PID 速度和最终 60FF 速度命令。 |
| `Tx Controlword 6040` | EtherCAT PDO Transmit | 把启动控制器输出的 `controlword_6040` 写入驱动 `6040h`。 |
| `Tx Target velocity 60FF` | EtherCAT PDO Transmit | 把启动控制器门禁后的 `velocity_command_60ff` 写入驱动 `60FFh`。 |
| `Tx Modes of operation 6060` | EtherCAT PDO Transmit | 把 `mode_command_6060` 写入驱动 `6060h`，当前固定 CSV 模式 `9`。 |
| `Tx Max profile velocity 607F` | EtherCAT PDO Transmit | 把 `speed_limit_out_607f` 写入驱动 `607Fh`。 |

## 3. 顶层可调输入块

这些块是顶层 Constant，值来自 model workspace 中的 `SGV2_*` tunable，便于在 `slrtExplorer` 参数页调整。

| 块名 | 送往 | 功能 |
|---|---|---|
| `command_expected_network_state` | `SV660N Sequence Controller` 输入 2 | EtherCAT 期望状态，当前为 OP 状态 `8`。 |
| `command_speed_limit_607f` | `SV660N Sequence Controller` 输入 8 | 写给 `607Fh` 的速度上限。 |
| `position_command_6064` | `PT-5 Position Loop` 输入 1 | 位置目标值，原始 6064 单位。 |
| `position_loop_enabled_request` | `PT-5 Position Loop` 输入 4 | 位置环使能请求，`0` 关闭，非零请求开启。 |
| `position_loop_kp` | `PT-5 Position Loop` 输入 5 | 位置环 P 增益，内部按 `value * 0.001` 使用。 |
| `position_loop_ki` | `PT-5 Position Loop` 输入 6 | 位置环 I 增益，内部按 `value * 0.001` 使用。 |
| `position_loop_kd` | `PT-5 Position Loop` 输入 7 | 位置环 D 增益，内部按 `value * 0.001` 使用。 |
| `position_loop_sample_time` | `PT-5 Position Loop` 输入 8 | 位置环采样时间，当前和模型固定步长一致。 |
| `position_loop_integrator_limit` | `PT-5 Position Loop` 输入 9 | 积分项上下限，防止积分过大。 |
| `max_tracking_speed` | `PT-5 Position Loop` 输入 10 | 位置环最终速度命令的限幅值，默认 `6000`。 |
| `position_loop_speed_command_60ff_delay` | 启动控制器输入 7 | 位置环速度命令延迟一拍后再进入 `speed_command_60ff` 门禁。 |

## 4. 顶层观测 Outport

这些 Outport 用于 `slrtExplorer` 的 Signals 页直接观察模型内部状态。

| Outport | 来源 | 含义 |
|---|---|---|
| `actual_network_state` | `EtherCAT Get State` | EtherCAT 实际状态。 |
| `expected_network_state` | `command_expected_network_state` | EtherCAT 期望状态。 |
| `statusword_6041` | `Rx Statusword 6041` | 驱动状态字。 |
| `error_code_603f` | `Rx Error code 603F` | 驱动错误码。 |
| `position_actual_6064` | `Rx Position actual 6064` | 实际位置。 |
| `mode_display_6061` | `Rx Mode display 6061` | 驱动实际模式。 |
| `velocity_actual_606c` | `Rx Velocity actual 606C` | 实际速度。 |
| `diag_code` | `SV660N Sequence Controller` 输出 7 | 当前诊断码。 |
| `diag_message_id` | `SV660N Sequence Controller` 输出 8 | 当前诊断消息 ID。 |
| `diag_lookup_group` | `SV660N Sequence Controller` 输出 9 | 建议查表分组。 |
| `diag_lookup_hint` | `SV660N Sequence Controller` 输出 10 | 给操作员看的诊断提示字符串。 |
| `ready_to_run` | `SV660N Sequence Controller` 输出 5 | 驱动是否已经允许速度命令生效。 |
| `auto_start_step` | `SV660N Sequence Controller` 输出 6 | 自动启动步骤。 |
| `position_error_6064` | `PT-5 Position Loop` 输出 2 | 位置误差。 |
| `position_ff_velocity_60ff` | `PT-5 Position Loop` 输出 3 | 保留观测量，当前 PID-only 架构固定为 `0`。 |
| `position_pid_velocity_60ff` | `PT-5 Position Loop` 输出 4 | PID 速度分量。 |
| `position_loop_enabled` | `PT-5 Position Loop` 输出 5 | 位置环实际使能状态。 |
| `position_loop_speed_command_60ff` | `PT-5 Position Loop` 输出 1 | 位置环合成后的速度命令。 |
| `speed_command_60ff` | `position_loop_speed_command_60ff_delay` | 延迟一拍后送入启动控制器的速度命令。 |
| `speed_limit_607f` | `command_speed_limit_607f` | 当前速度上限参数。 |

## 5. SV660N Sequence Controller 子系统

### 5.1 输入输出端口

| 端口 | 名称 | 功能 |
|---:|---|---|
| 1 | `actual_network_state` | EtherCAT 实际状态。 |
| 2 | `expected_network_state` | EtherCAT 期望状态。 |
| 3 | `statusword_6041` | 驱动状态字。 |
| 4 | `error_code_603f` | 驱动错误码。 |
| 5 | `mode_display_6061` | 驱动实际模式。 |
| 6 | `velocity_actual_606c` | 实际速度，当前不参与控制，进入 Terminator。 |
| 7 | `speed_command_60ff` | 来自位置环延迟后的速度命令。 |
| 8 | `speed_limit_607f` | 速度上限。 |

| 端口 | 名称 | 功能 |
|---:|---|---|
| 1 | `controlword_6040` | 写给驱动控制字。 |
| 2 | `velocity_command_60ff` | 门禁后的目标速度。 |
| 3 | `mode_command_6060` | 写给驱动模式，固定为 CSV `9`。 |
| 4 | `speed_limit_out_607f` | 速度上限直通输出。 |
| 5 | `ready_to_run` | 是否允许速度命令生效。 |
| 6 | `auto_start_step` | 当前自动启动步骤。 |
| 7 | `diag_code` | 诊断码。 |
| 8 | `diag_message_id` | 诊断消息 ID。 |
| 9 | `diag_lookup_group` | 诊断查表分组。 |
| 10 | `diag_lookup_hint` | 诊断提示字符串。 |

### 5.2 内部块功能

| 块名 | 类型 | 功能 |
|---|---|---|
| `startup_decision` | MATLAB Function | 根据 EtherCAT 状态、603F 错误码、6041 状态字和 6061 模式，输出控制字、ready、启动步骤和诊断信息。 |
| `velocity_command_ready_switch` | Switch | `ready_to_run ~= 0` 时放行 `speed_command_60ff`，否则输出 0。 |
| `zero_velocity_command_60ff` | Constant | 速度门禁关闭时使用的 `int32(0)`。 |
| `mode_command_csv` | Constant | 固定输出 `int8(9)`，表示 CSV 模式。 |
| `velocity_actual_606c_terminator` | Terminator | 当前版本不使用实际速度参与启动判定，用 Terminator 明确终止。 |
| `diag_message_id_to_double` | Data Type Conversion | 把 `diag_message_id` 转成 double，便于后续比例和偏置计算。 |
| `diag_message_id_scale` | Gain | 把诊断 ID 按 `0.1` 缩放，例如 `10 -> 1`、`20 -> 2`。 |
| `diag_message_id_bias` | Bias | 给缩放后的 ID 加 1，转换为 Multiport Switch 的一路选择索引。 |
| `diag_message_id_to_uint8` | Data Type Conversion | 把查表索引转成 `uint8`。 |
| `diag_lookup_hint_switch` | Multiport Switch | 根据诊断索引选择一条 48 字节诊断提示。 |
| `diag_lookup_hint_1` | Constant | 无诊断时输出 48 个 0。 |
| `diag_lookup_hint_2` | Constant | EtherCAT 状态异常时提示检查 EtherCAT state machine。 |
| `diag_lookup_hint_3` | Constant | 603F 错误码非零时提示检查 SV660N 603Fh。 |
| `diag_lookup_hint_4` | Constant | 6041 状态字异常时提示检查 CiA402/statusword。 |
| `diag_lookup_hint_5` | Constant | 6061 模式不匹配时提示检查 mode display。 |

### 5.3 `startup_decision` 判定顺序

`startup_decision` 保留原来 Chart 的优先级：

1. `actual_network_state ~= expected_network_state`：不使能，等待 EtherCAT OP。
2. `error_code_603f ~= 0`：不使能，等待驱动错误清除。
3. `sgv2.statusState(statusword_6041) >= faultStatusSentinel()`：不使能，等待故障清除。
4. 状态为 switch on disabled：输出 `shutdown` 控制字。
5. 状态为 ready to switch on：输出 `switch_on` 控制字。
6. 状态为 switched on：输出 `enable_operation` 控制字。
7. 状态为 operation enabled 但 `mode_display_6061 ~= 9`：保持 enable，报模式不匹配。
8. 状态为 operation enabled 且模式为 9：输出 `ready_to_run = 1`。
9. 其他状态：安全等待，报 `WAITING_ENABLE`。

## 6. PT-5 Position Loop 子系统

### 6.1 输入输出端口

| 端口 | 名称 | 功能 |
|---:|---|---|
| 1 | `position_command_6064` | 位置目标。 |
| 2 | `position_actual_6064` | 实际位置。 |
| 3 | `ready_to_run` | 启动控制器给出的位置环外部门禁。 |
| 4 | `position_loop_enabled_request` | 操作员或上位参数给出的位置环使能请求。 |
| 5 | `position_loop_kp` | P 增益整数刻度。 |
| 6 | `position_loop_ki` | I 增益整数刻度。 |
| 7 | `position_loop_kd` | D 增益整数刻度。 |
| 8 | `position_loop_sample_time` | 位置环采样时间。 |
| 9 | `position_loop_integrator_limit` | 积分限幅。 |
| 10 | `max_tracking_speed` | 最大跟踪速度。 |

| 端口 | 名称 | 功能 |
|---:|---|---|
| 1 | `position_loop_speed_command_60ff` | 最终位置环速度命令。 |
| 2 | `position_error_6064` | 位置误差。 |
| 3 | `position_ff_velocity_60ff` | 保留观测量，当前固定为 `0`。 |
| 4 | `position_pid_velocity_60ff` | PID 速度分量。 |
| 5 | `position_loop_enabled` | 位置环实际使能状态。 |

### 6.2 使能门禁块

| 块名 | 类型 | 功能 |
|---|---|---|
| `ready_to_run_one` | Constant | 提供 `uint8(1)` 比较值。 |
| `ready_to_run_equals_1` | Relational Operator | 判断 `ready_to_run == 1`。 |
| `enable_request_zero` | Constant | 提供 `int32(0)` 比较值。 |
| `enable_request_nonzero` | Relational Operator | 判断 `position_loop_enabled_request ~= 0`。 |
| `position_loop_enable_gate` | Logical Operator | 对上面两个条件做 AND。 |
| `position_loop_enabled_to_uint8` | Data Type Conversion | 把逻辑使能转成 `uint8` 输出。 |

位置环实际使能条件是：

```text
position_loop_enabled = (ready_to_run == 1) && (position_loop_enabled_request ~= 0)
```

### 6.3 位置误差支路

| 块名 | 类型 | 功能 |
|---|---|---|
| `position_error_sum` | Sum | 计算 `position_command_6064 - position_actual_6064`。 |
| `position_error_to_double` | Data Type Conversion | 把 int32 误差转为 double，供 PID 计算使用。 |
| `zero_int32_error` | Constant | 位置环未使能时输出的零误差。 |
| `position_error_enabled_switch` | Switch | 使能时输出真实误差，未使能时输出 0。 |

这一路的观测输出是 `position_error_6064`。

### 6.4 前馈观测口

当前版本是 PID-only 位置闭环，没有轨迹速度前馈输入，也没有前馈计算支路。`position_ff_velocity_60ff` 作为兼容观测口保留，由 `zero_int32_ff` 固定输出 `int32(0)`。

### 6.5 PID 状态支路

| 块名 | 类型 | 功能 |
|---|---|---|
| `integral_6064_delay` | Unit Delay | 保存上一拍积分项。 |
| `previous_error_6064_delay` | Unit Delay | 保存上一拍位置误差。 |
| `pid_state_update` | MATLAB Function | 更新积分、计算微分、合成 PID 速度分量，并在未使能时清零状态。 |

`pid_state_update` 的核心逻辑是：

```text
kp_gain = position_loop_kp * 0.001
ki_gain = position_loop_ki * 0.001
kd_gain = position_loop_kd * 0.001

integral_next = integral_previous + ki_gain * error * sample_time
integral_next = clamp(integral_next, -integrator_limit, integrator_limit)

derivative = (error - previous_error) / sample_time
pid_raw = kp_gain * error + integral_next + kd_gain * derivative
position_pid_velocity_60ff = round(pid_raw)
```

如果 `position_loop_enable_gate` 为 false，`pid_state_update` 输出：

```text
raw_pid_velocity_60ff = 0
position_pid_velocity_60ff = 0
integral_6064_next = 0
previous_error_6064_next = 0
```

这样位置环关闭或驱动未 ready 时，积分和上一拍误差都会复位，避免重新使能时带入旧状态。

### 6.6 最终速度命令支路

| 块名 | 类型 | 功能 |
|---|---|---|
| `final_lower_limit` | MinMax | 对最终速度做下限保护：不小于 `-max_tracking_speed`。 |
| `final_upper_limit` | MinMax | 对最终速度做上限保护：不大于 `max_tracking_speed`。 |
| `final_speed_round` | Rounding Function | 对最终速度四舍五入。 |
| `final_speed_to_int32` | Data Type Conversion | 把最终速度转为 `int32`。 |
| `zero_int32_command` | Constant | 位置环未使能时输出的零命令。 |
| `final_speed_enabled_switch` | Switch | 使能时输出最终速度命令，未使能时输出 0。 |

最终输出公式可以理解为：

```text
speed_limited = clamp(position_pid_velocity_raw, -max_tracking_speed, max_tracking_speed)
position_loop_speed_command_60ff = round(speed_limited)
```

其中最终输出还会被 `position_loop_enable_gate` 再门禁一次，未使能时强制为 0。

## 7. 位置环完整信号流

完整位置环按下面顺序运行：

1. 顶层 `position_command_6064` 给出位置目标。
2. 顶层 `Rx Position actual 6064` 给出实际位置。
3. `position_error_sum` 计算位置误差：

   ```text
   position_error = position_command_6064 - position_actual_6064
   ```

4. `ready_to_run_equals_1` 和 `enable_request_nonzero` 同时为真时，`position_loop_enable_gate` 输出 true。
5. 误差进入 `pid_state_update`，结合 `kp/ki/kd`、采样时间、积分限幅和上一拍状态，得到 PID 速度分量。
6. `position_ff_velocity_60ff` 固定为 `0`，表示当前没有手动速度前馈。
7. 最终速度支路把 PID raw 值做 `max_tracking_speed` 限幅。
8. `final_speed_enabled_switch` 在位置环未使能时把最终命令强制为 0。
9. `position_loop_speed_command_60ff` 从 `PT-5 Position Loop` 输出。
10. 顶层 `position_loop_speed_command_60ff_delay` 延迟一拍，作为 `speed_command_60ff` 送入 `SV660N Sequence Controller`。
11. `SV660N Sequence Controller` 再用 `ready_to_run` 做一次速度门禁：

    ```text
    ready_to_run == 1 -> velocity_command_60ff = speed_command_60ff
    ready_to_run == 0 -> velocity_command_60ff = 0
    ```

12. `Tx Target velocity 60FF` 把 `velocity_command_60ff` 写入驱动 `60FFh`。

## 8. 读模型时的建议顺序

打开 `.slx` 后建议按这个顺序看：

1. 先看顶层左侧 EtherCAT Rx 块，确认现场反馈信号从哪里来。
2. 看 `SV660N Sequence Controller`，确认 `ready_to_run` 如何产生，以及速度命令如何被放行。
3. 看 `PT-5 Position Loop` 左侧输入，确认位置目标、实际位置和参数从哪里进入。
4. 在 `PT-5 Position Loop` 内按上到下看三条主支路：
   - 位置误差和 PID 支路
   - 固定为零的前馈观测口
   - 最终速度限幅支路
5. 回到顶层看 `position_loop_speed_command_60ff_delay`，确认最终速度命令先延迟一拍再进入启动控制器。
6. 最后看右侧 EtherCAT Tx 块，确认写给驱动的 `6040h / 60FFh / 6060h / 607Fh`。

这样读，模型基本就是一张从状态反馈、位置环计算、启动门禁到 PDO 输出的控制框图。
