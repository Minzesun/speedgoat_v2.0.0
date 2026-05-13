# speedgoat_v2_position_tuning

这是 PT-8 的现场调参 runbook。它只用于低速、小位移、保守默认值下的位置环确认，不用于大行程跑图。

## 目的

确认 `position_actual_6064` 能跟随 `position_command_6064`，并把 PID-only 位置闭环的最小速度命令调到可用状态。

## 先决条件

- `speedgoat_v2_minimal` 已加载到 `slrtExplorer`
- EtherCAT 已到 `OP`
- `ready_to_run == 1`
- 位置环默认仍处于保守状态
- 现场允许的最大速度和最大位移已经确认

## 要看哪些信号

在 `slrtExplorer` 里同时打开：

- `actual_network_state`
- `statusword_6041`
- `error_code_603f`
- `ready_to_run`
- `position_command_6064`
- `position_actual_6064`
- `velocity_actual_606c`
- `position_error_6064`
- `position_ff_velocity_60ff`
- `position_pid_velocity_60ff`
- `position_loop_speed_command_60ff`
- `speed_command_60ff`
- `position_loop_enabled`
- `diag_lookup_hint`

## 要改哪些参数

在 `Parameters` 页签里修改：

- `SGV2_POSITION_COMMAND_6064`
- `SGV2_POSITION_LOOP_ENABLED`
- `SGV2_POSITION_LOOP_KP`
- `SGV2_POSITION_LOOP_KI`
- `SGV2_POSITION_LOOP_KD`
- `SGV2_POSITION_LOOP_INTEGRATOR_LIMIT`

`position_command_6064` 是对应的观测信号；真正能在 `Parameters` 里直接改的是 `SGV2_POSITION_COMMAND_6064`。
如果你只看到旧的速度参数、看不到这个 `SGV2_POSITION_*`，说明 `slrtExplorer` 还在加载旧包；请先运行 `build_speedgoat_v2_minimal_app`，再重新载入最新生成的 `D:\Temporary_file\speedgoat_v2.0.0\matlab\speedgoat_v2_minimal.mldatx`。这个构建入口会自动补齐项目内 MATLAB path，不需要额外手动 `savepath`。

`SGV2_POSITION_LOOP_ENABLED` 用整型 `0/1` 表示关闭/打开。`SGV2_POSITION_LOOP_KP/KI/KD` 在 `slrtExplorer` 里也用整型输入，模型内部按 `value * 0.001` 转成实际 PID 增益；例如 `SGV2_POSITION_LOOP_KP = 10` 表示实际 `Kp = 0.010`。

## 默认起点

先保持这些默认值：

- `PositionLoopEnabled = 0`
- `PositionLoopKp = 0`
- `PositionLoopKi = 0`
- `PositionLoopKd = 0`
- `PositionLoopIntegratorLimit = 0`
- `PositionLoopSampleTime = 0.002`
- `MaxTrackingSpeed = 6000`
- `PositionUnitMillimetersPerCount6064 = 1`

## 低速小位移流程

1. 先让系统空载稳定，确认 `ready_to_run == 1`。
2. 先把 `SGV2_POSITION_COMMAND_6064` 设成当前位置附近的小目标。
3. 先保持 `PositionLoopEnabled = 1`，但 `Kp/Ki/Kd = 0`，确认 `position_loop_speed_command_60ff`、`speed_command_60ff` 和 `position_ff_velocity_60ff` 都为 `0`。
4. 把 `PositionLoopKp` 设成很小的整数值，重新跑同样的小位移；例如先试 `1`，表示实际 `Kp = 0.001`。
5. 观察 `position_pid_velocity_60ff` 和 `position_loop_speed_command_60ff` 的方向是否正确，并确认 `speed_command_60ff` 只是比 `position_loop_speed_command_60ff` 晚一拍。
6. 如果仍然平稳，再按需要一点点加 `Ki` 或 `Kd`，每次只改一个量。
7. `SGV2_MAX_TRACKING_SPEED = 6000` 只是速度限幅，不是轨迹规划速度；实际速度由 PID 增益和位置误差共同决定。

## 什么时候停

立刻停在零速并停止应用，如果出现任一情况：

- `ready_to_run` 掉回 `0`
- `actual_network_state != 8`
- `statusword_6041` 异常
- `error_code_603f != 0`
- 位置方向反了
- 位置误差持续增大
- 小位移时出现明显抖动、冲顶或来回震荡

## 结果怎么记

每次试验都保存同名的：

- `.mat`
- `.csv`
- `.md`

推荐文件名：

```text
YYYYMMDD_axis1_pt8_<mode>_v<speed>_tr<travel>
```

## 复现要求

每次记录都要能回答：

- 本次改了什么参数
- 本次给了什么轨迹
- 实际位置和给定位置差多少
- 为什么这次可以继续，或者为什么必须停
