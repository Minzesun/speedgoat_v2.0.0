# speedgoat_v2_position_tuning

这是 PT-8 的现场调参 runbook。它只用于低速、小位移、保守默认值下的位置环确认，不用于大行程跑图。

## 目的

确认 `position_actual_6064` 能跟随 `position_command_6064`，并把外部轨迹、前馈和位置 PID 的最小闭环调到可用状态。

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
- `position_reference_6064`
- `position_rate_reference_6064`
- `position_command_6064`
- `position_rate_command_6064`
- `position_actual_6064`
- `velocity_actual_606c`
- `position_error_6064`
- `position_ff_velocity_60ff`
- `position_pid_velocity_60ff`
- `position_loop_speed_command_60ff`
- `speed_command_60ff`
- `position_loop_enabled`
- `diag_lookup_hint`

## 位置 reference 文件

构建前编辑：

```text
data/reference/position_reference_6064.txt
```

文件每行一个相对位置点，单位按 `mm` 写，不写时间列。模型会用内部 `target.SampleTime` 解释每一行的时间间隔。点击 Start 后，`ready_to_run = 1` 只表示系统已经允许运动，不会自动播放 reference；只有把 `SGV2_REFERENCE_PLAY_REQUEST` 从 `0` 改成 `1` 时，模型才锁存当前 `position_actual_6064` 作为基准位置，并从第 1 行开始播放。播放到最后一行后，相对参考回到 `0`，也就是命令回到锁存的基准位置附近。

如果要关闭自动速度前馈，在 `Parameters` 页签里把：

```text
SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED = 0
```

默认值是 `1`，表示使用相邻位置点差分出来的速度前馈。
整条 reference 数组不作为 `slrtExplorer` 参数暴露；修改 txt 轨迹后必须重新运行 `build_speedgoat_v2_minimal_app` 并重新加载生成的 `.mldatx`。

运行请求在 `Parameters` 页签里控制：

- `SGV2_REFERENCE_PLAY_REQUEST = 0`：不播放 txt，reference 跟随当前实际位置。
- `SGV2_REFERENCE_PLAY_REQUEST = 1`：从第 1 行开始播放 txt reference。
- `SGV2_HOME_TO_ZERO_REQUEST = 1`：优先于 txt，以 `SGV2_HOME_TO_ZERO_SPEED` 斜坡回绝对零位。
- `SGV2_HOME_TO_ZERO_SPEED = 10`：默认回零速度，按当前单位假设为 `10 mm/s`。

在 `Parameters` 页签里仍可调：

- `SGV2_POSITION_LOOP_KP`
- `SGV2_POSITION_LOOP_KI`
- `SGV2_POSITION_LOOP_KD`
- `SGV2_POSITION_LOOP_INTEGRATOR_LIMIT`

`position_command_6064` 和 `position_rate_command_6064` 是进入 PT-5 的实际命令观测信号；它们现在来自 `Position Reference Source`，不是现场手动修改的位置参数。
如果你看不到 `position_reference_6064`、`position_rate_reference_6064` 或 `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED`，说明 `slrtExplorer` 还在加载旧包；请先运行 `build_speedgoat_v2_minimal_app`，再重新载入最新生成的 `D:\Temporary_file\speedgoat_v2.0.0\matlab\speedgoat_v2_minimal.mldatx`。这个构建入口会自动补齐项目内 MATLAB path，不需要额外手动 `savepath`。

`SGV2_POSITION_LOOP_ENABLED` 不再作为现场可调参数暴露。位置环请求在模型内部固定为开启，实际运动仍由 `ready_to_run`、PT-5 限幅和启动控制器门禁保护。`SGV2_POSITION_LOOP_KP/KI/KD` 在 `slrtExplorer` 里也用整型输入，模型内部按 `value * 0.001` 转成实际 PID 增益；例如 `SGV2_POSITION_LOOP_KP = 10` 表示实际 `Kp = 0.010`。

## 默认起点

先保持这些默认值：

- `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED = 1`
- `SGV2_REFERENCE_PLAY_REQUEST = 0`
- `SGV2_HOME_TO_ZERO_REQUEST = 0`
- `SGV2_HOME_TO_ZERO_SPEED = 10`
- `PositionLoopKp = 0`
- `PositionLoopKi = 0`
- `PositionLoopKd = 0`
- `PositionLoopIntegratorLimit = 0`
- `PositionLoopSampleTime = 0.002`
- `PositionVelocityGain = 1000`
- `PositionVelocityBias = 0`
- `CommandDeadband = 0`
- `MaxTrackingSpeed = 6000`
- `PositionUnitMillimetersPerCount6064 = 0.001`

## 低速小位移流程

1. 先把 `data/reference/position_reference_6064.txt` 写成当前位置附近的小位移相对 reference，每行一个 mm 位置点。默认 `0.001 mm/count` 会把 `1 mm` 转成 `1000` 个 6064 counts。
2. 构建并加载最新应用包，保持 `SGV2_REFERENCE_PLAY_REQUEST = 0`、`SGV2_HOME_TO_ZERO_REQUEST = 0`、`Kp/Ki/Kd = 0`。
3. 点击 Start，让系统空载稳定，确认 `ready_to_run = 1`。此时 reference 应跟随当前实际位置，机器不应因为 ready 自动开跑。
4. 确认或调整 `SGV2_POSITION_LOOP_KP/KI/KD`、`SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED` 和 `SGV2_HOME_TO_ZERO_SPEED`。
5. 要跑 txt 时，把 `SGV2_REFERENCE_PLAY_REQUEST` 改成 `1`，然后在 Data Inspector 里观察 `position_reference_6064`、`position_actual_6064`、`position_loop_speed_command_60ff` 和 `position_ff_velocity_60ff`，确认方向是否正确。
6. 要斜坡回绝对零位时，把 `SGV2_HOME_TO_ZERO_REQUEST` 改成 `1`；如果 txt 和回零请求同时为 `1`，回零优先。
7. 观察 `speed_command_60ff` 是否只是比 `position_loop_speed_command_60ff` 晚一拍，并确认方向、单位和零速都对。
8. 如果方向、单位和零速都对，再把 `PositionLoopKp` 设成很小的整数值，重新跑同样的小位移；例如先试 `1`，表示实际 `Kp = 0.001`。
9. 如果仍然平稳，再按需要一点点加 `Ki` 或 `Kd`，每次只改一个量。

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
