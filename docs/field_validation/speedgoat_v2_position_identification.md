# speedgoat_v2_position_identification

这份文档描述位置辨识数据怎么采、怎么记、怎么存。它服务于后续的逆模型和位置环，不替代当前的 `speedgoat_v2_minimal` 速度控制 runbook。
这里的“记录”指的是在 `slrtExplorer` 里实时记录并同步导出原始信号，不是人工抄录数值。

## 1. 目的

先用现场数据确认三件事：

1. `speed_command_60ff` 和 `velocity_actual_606c` 的响应关系。
2. `velocity_actual_606c` 和 `position_actual_6064` 的方向、比例和延迟关系。
3. 低风险位置步进下，系统是否能在保守包络内稳定运动。

## 2. 要记录什么

每次试验都要保留两类东西：

1. 原始采样数据（在 `slrtExplorer` 中实时记录并导出）
2. 同名元数据记录

建议最少记录这些信号：

- `ready_to_run`
- `speed_command_60ff`
- `velocity_command_60ff`
- `velocity_actual_606c`
- `position_actual_6064`
- `statusword_6041`
- `error_code_603f`

## 3. 采集元数据格式

元数据建议和原始数据同名保存，后缀用 `.md`，方便操作员直接读，也方便后续转成表格或脚本。

### 3.1 文件名

推荐格式：

```text
data/field_validation/YYYYMMDD_axis1_<sequence>_<direction>_v<speed>_tr<travel>.mat
data/field_validation/YYYYMMDD_axis1_<sequence>_<direction>_v<speed>_tr<travel>.csv
data/field_validation/YYYYMMDD_axis1_<sequence>_<direction>_v<speed>_tr<travel>.md
```

示例：

```text
data/field_validation/20260510_axis1_step_pos_v200_tr1000.mat
data/field_validation/20260510_axis1_step_pos_v200_tr1000.csv
data/field_validation/20260510_axis1_step_pos_v200_tr1000.md
```

### 3.2 元数据内容

最小元数据字段如下：

| 字段 | 含义 | 示例 |
|---|---|---|
| `date` | 试验日期 | `2026-05-10` |
| `axis` | 轴名 | `axis1` |
| `sequence` | 试验序列名 | `step` / `ramp` / `triangle` |
| `direction` | 方向 | `pos` / `neg` |
| `IdentificationMaxSpeed60FF` | 辨识阶段最大速度包络 | `200` |
| `IdentificationMaxTravel6064` | 辨识阶段最大位移包络 | `1000` |
| `IdentificationStep6064` | 辨识阶段小步长 | `100` |
| `IdentificationStopBand6064` | 辨识阶段停止带 | `20` |
| `IdentificationTransientGuardSamples` | 线性拟合时换向后剔除的采样点数 | `1` |
| `sample_time_s` | 采样周期 | `0.002` |
| `ready_to_run_at_start` | 起始时是否 ready | `1` |
| `result` | 结果 | `pass` / `fail` |
| `fault_code_603f` | 若失败，记录错误码 | `0x3230` |
| `note` | 简短备注 | `position moved cleanly` |

### 3.3 元数据模板

```md
# Identification Session
- date: 2026-05-10
- axis: axis1
- sequence: step
- direction: pos
- IdentificationMaxSpeed60FF: 200
- IdentificationMaxTravel6064: 1000
- IdentificationStep6064: 100
- IdentificationStopBand6064: 20
- IdentificationTransientGuardSamples: 1
- sample_time_s: 0.002
- ready_to_run_at_start: 1
- result: pass
- fault_code_603f: 0
- note: short positive step within conservative limits
```

## 4. 记录流程

1. 打开 `SPEEDGOAT_V2_MINIMAL_LOGIC.md` 第 15 节，确认当前流程仍是位置辨识规划中的版本。
2. 在 `slrtExplorer` 中加载 `speedgoat_v2_minimal`。
3. 打开信号：
   - `ready_to_run`
   - `speed_command_60ff`
   - `velocity_command_60ff`
   - `velocity_actual_606c`
   - `position_actual_6064`
   - `statusword_6041`
   - `error_code_603f`
4. 确认 `ready_to_run == 1` 且 `diag_code == 0` 后再开始采集。
5. 先做零速保持，再做一个最小正向或反向测试。
6. 逐步增加到 `step_6064` 级别的小步试验，不要直接跳到大位移。
7. 每次试验结束后，把速度回到 `0`，确认 `position_actual_6064` 重新稳定。
8. 在 `slrtExplorer` 中把原始信号实时记录并同步导出成数据文件，同时保存同名 `.md` 元数据文件和必要的截图或备注。

## 5. 停止条件

只要出现下面任一情况，就停止采集：

- `ready_to_run` 变成 `0`
- `diag_code != 0`
- `error_code_603f != 0`
- `statusword_6041` 不再是正常允许状态
- 位置变化超过 `max_travel_6064`
- 速度超过 `max_speed_60ff`

停止后只做两件事：

1. 把 `speed_command_60ff` 拉回 `0`
2. 在元数据里写明失败原因

## 6. 复现说明

同一个试验应该能被别人按下面步骤复现：

1. 读元数据。
2. 读原始数据。
3. 确认试验序列、速度档位、方向、位移包络和停止条件。
4. 重新在 `slrtExplorer` 里跑同样的序列。
5. 对比 `position_actual_6064` 和 `velocity_actual_606c` 的曲线是否一致。

如果别人不能按这份文档复现，说明记录不合格，需要重做。

## 7. 试后摘要

采集完之后，先把原始数据整理成一个 capture 结构，再调用：

```matlab
summary = sgv2.analysis.summarizeIdentificationCapture(capture);
```

这个摘要会给出：

- `SampleTime`
- `Duration`
- `PositionDelta6064`
- `ApproxVelocityFromPosition6064`
- `VelocityError606C`
- `MaxAbsTravel6064`
- `MaxAbsSpeedCommand60FF`
- `ReadyFraction`
- `FaultSeen`

操作员看摘要时，先关注三件事：

1. `FaultSeen` 是否为 `false`
2. `MaxAbsTravel6064` 是否小于设定包络
3. `VelocityError606C` 是否大到不合理

如果这三项不对，先别急着做逆模型，先重做采集。

## 8. 线性拟合

如果摘要通过，再做第一版线性拟合：

```matlab
fit = sgv2.analysis.fitIdentificationRelationship(capture);
```

这个拟合会先过滤掉未 ready、带故障、零速度命令、超出 `IdentificationMaxSpeed60FF` / `IdentificationMaxTravel6064` 的样本。若元数据里给了 `IdentificationTransientGuardSamples`，它还会把换向后的瞬态样本剔除，再对 `diff(position_actual_6064)/Ts` 和 `speed_command_60ff` 做最小二乘拟合，输出：

- `K_cmd`
- `B_cmd`
- `RSquared`
- `UsedSampleIndex`
- `Selection.TransientMask`
- `Selection.ValidMask`

操作员先看三件事：

1. `RSquared` 是否足够高。
2. `K_cmd` 是否和预期方向一致。
3. `UsedSampleIndex` / `Selection.ValidMask` 是否主要来自稳定运动区间，而不是起步、换向和停机瞬态。

如果拟合结果不稳，先回到更低速、更小位移的试验，不要直接往逆模型里塞。
