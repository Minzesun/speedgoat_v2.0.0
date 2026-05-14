# speedgoat_v2_minimal Signal And Parameter Reference

| Name | Meaning | Source | slrtExplorer 里怎么看 | 出问题查 |
|---|---|---|---|---|
| `actual_network_state` | EtherCAT 实际网络状态 | `EtherCAT Get State` | 在 `Signals` / `Status` 里看它是否等于 `expected_network_state = 8` | EtherCAT 手册的 `Get State` 与状态机章节 |
| `expected_network_state` | 期望网络状态，固定为 `8` | Constant command source | 同屏对照 `actual_network_state` 和 `diag_lookup_hint` | EtherCAT 手册的状态机章节 |
| `statusword_6041` | 驱动状态字 | `1B04h Inputs` | 在 `Signals` 里看是否随 `ready_to_run` 变化到位 | SV660N 手册的 `6041h` / CiA402 状态机章节 |
| `error_code_603f` | 驱动错误码 | `1B04h Inputs` | 在 `Signals` 里先看是否非零，再看 `diag_lookup_hint` | SV660N 手册的 `603Fh` 错误码章节 |
| `position_actual_6064` | 实际位置；当前只观察，规划中的位置环会使用它 | `1B04h Inputs` | 在 `Signals` 里看位置反馈是否随运动变化 | SV660N 手册的 `6064h` 位置反馈对象章节 |
| `mode_display_6061` | 模式显示 | `1B04h Inputs` | 在 `Signals` 里确认是否为 CSV 对应模式 | SV660N 手册的 `6061h` 模式章节 |
| `velocity_actual_606c` | 实际速度 | `1B04h Inputs` | 在 `Signals` 里确认起机前接近 `0`、运行中变化合理 | SV660N 手册的 `606Ch` 速度反馈对象章节 |
| `diag_code` | 运行诊断代码 | Sequence Controller | 在 `Diagnostics` 里先看它是否为 `0` | Sequence Controller 对应的诊断码定义 |
| `diag_message_id` | 诊断消息编号 | Sequence Controller | 在 `Diagnostics` 里和 `diag_lookup_hint` 一起看 | Sequence Controller 的消息映射与手册提示 |
| `diag_lookup_group` | 手册查阅分组 | Sequence Controller | 在 `Diagnostics` 里看它把问题导向哪类对象 | `EtherCAT` / `SV660N` 手册对应章节 |
| `diag_lookup_hint` | 查阅提示 | Sequence Controller | 在 `Diagnostics` 里优先读这个，再回到信号面排查 | `EtherCAT` 或 `SV660N` 手册的对应对象章节 |
| `ready_to_run` | 是否允许人工给速度 | Sequence Controller | 在 `Signals` / `Diagnostics` 里看是否变成 `1` | Sequence Controller 的起机门禁逻辑 |
| `auto_start_step` | 自动起机当前步骤 | Sequence Controller | 在 `Diagnostics` 里看它卡在哪一步 | Sequence Controller 的状态推进定义 |
| `speed_command_60ff` | 实际送入启动控制器的速度给定；位置环路径下比 `position_loop_speed_command_60ff` 晚一拍 | `PT-5` command delay / `1702h Outputs` | 在 `Signals` 里确认最终速度命令已进入控制器 | SV660N 手册的 `60FFh` 目标速度对象章节 |
| `speed_limit_607f` | 保守速度上限 | `1702h Outputs` | 在 `Commands` 里确认它限制了人工给定范围 | SV660N 手册的 `607Fh` 最大速度对象章节 |
| `IdentificationMaxSpeed60FF` | 辨识阶段保守速度上限，默认 `200` | AxisConfig / Tunables | 后续位置辨识时作为最大速度包络 | 项目逻辑文档与 AxisConfig 默认值 |
| `IdentificationMaxTravel6064` | 辨识阶段单次最大位移，默认 `1000` | AxisConfig / Tunables | 后续位置辨识时作为位移窗口 | 项目逻辑文档与 AxisConfig 默认值 |
| `IdentificationStep6064` | 辨识阶段小步长，默认 `100` | AxisConfig / Tunables | 后续做阶跃/阶梯试验时使用 | 项目逻辑文档与 AxisConfig 默认值 |
| `IdentificationStopBand6064` | 辨识阶段停止带，默认 `20` | AxisConfig / Tunables | 后续判定停止或接近目标时使用 | 项目逻辑文档与 AxisConfig 默认值 |
| `data/reference/position_reference_6064.txt` | 一列相对位置 reference 文件；每行一个控制周期的 mm 位置点 | Operator txt file | 构建前编辑，构建时按 `PositionUnitMillimetersPerCount6064` 转成 6064 counts | PT-8 调参 runbook |
| `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED` | 自动差分速度前馈开关，默认 `1` | AxisConfig / Tunables | `1` 使用差分速度前馈，`0` 速度前馈强制为 `0` | 位置参考源 |
| `SGV2_REFERENCE_PLAY_REQUEST` | txt reference 播放请求，默认 `0` | AxisConfig / Tunables | `ready_to_run = 1` 后改成 `1` 才从第 1 行开始播放 txt | PT-8 调参 runbook |
| `SGV2_HOME_TO_ZERO_REQUEST` | 斜坡回绝对零位请求，默认 `0` | AxisConfig / Tunables | 改成 `1` 后优先于 txt reference，命令斜坡回 `position_reference_6064 = 0` | PT-8 调参 runbook |
| `SGV2_HOME_TO_ZERO_SPEED` | 回零斜坡速度，默认 `10` | AxisConfig / Tunables | 默认按 `10 mm/s` 使用，先保守确认方向和零位 | PT-8 调参 runbook |
| `PositionVelocityGain` | 逆模型斜率，默认 `1000` | AxisConfig / Tunables | 默认把 6064 counts/s 除以 `1000` 转成约 `mm/s`；为 `0` 时前馈输出安全回零 | 项目逻辑文档与单位假设 |
| `PositionVelocityBias` | 逆模型偏置，默认 `0` | AxisConfig / Tunables | 当前不加常数偏置；后续如有现场偏差再更新 | 项目逻辑文档与单位假设 |
| `CommandDeadband` | 逆模型速度命令死区，默认 `0` | AxisConfig / Tunables | 规划中的逆模型参数，小命令可被压到 `0` | 项目逻辑文档与调试记录 |
| `CommandDelaySamples` | 速度命令延迟样本数，默认 `0` | AxisConfig / Tunables | 规划中的延迟补偿参数，首版静态前馈暂不使用 | PT-3 现场延迟判断 |
| `MaxTrackingSpeed` | 位置跟踪输出速度上限，默认 `6000` | AxisConfig / Tunables | 现在作为线速度饱和值；默认按 `mm/s` 直通假设使用 | 项目逻辑文档与 AxisConfig 默认值 |
| `PositionUnitMillimetersPerCount6064` | `6064` 位置单位到毫米的换算系数，默认 `0.001` | AxisConfig / Tunables | 默认 `1 count = 0.001 mm`，构建时把 txt 里的 mm 小数转成高分辨率 6064 counts | 项目逻辑文档与单位假设 |
| `SGV2_POSITION_LOOP_ENABLED` | 已废弃；不再作为现场可调参数暴露 | 内部固定请求开启 | 实际是否输出运动命令仍看 `ready_to_run`、PT-5 限幅和启动控制器门禁 | 项目逻辑文档与安全默认值 |
| `PositionLoopKp` | 位置环比例增益的千分之一整数刻度，默认 `0` | AxisConfig / Tunables | `10` 表示实际 `Kp = 0.010` | 项目逻辑文档与位置环约束 |
| `PositionLoopKi` | 位置环积分增益的千分之一整数刻度，默认 `0` | AxisConfig / Tunables | `10` 表示实际 `Ki = 0.010` | 项目逻辑文档与位置环约束 |
| `PositionLoopKd` | 位置环微分增益的千分之一整数刻度，默认 `0` | AxisConfig / Tunables | `10` 表示实际 `Kd = 0.010` | 项目逻辑文档与位置环约束 |
| `PositionLoopSampleTime` | 位置环离散采样时间，默认 `0.002` | AxisConfig / Tunables | 与当前模型固定步长一致 | 项目逻辑文档与固定步长约束 |
| `PositionLoopIntegratorLimit` | 位置环积分限幅，默认 `0` | AxisConfig / Tunables | 首版积分保持关闭状态 | 项目逻辑文档与位置环约束 |
| `position_reference_6064` | txt 文件或回零模式输出的绝对位置 reference；txt 只在 `SGV2_REFERENCE_PLAY_REQUEST` 上升沿锁存当前位置后播放 | Position Reference Source | 在 Data Inspector 里和 `position_actual_6064` 叠加看 | txt reference 文件、运行请求和 ready 门禁 |
| `position_rate_reference_6064` | 自动差分出来的速度前馈 reference，受 feedforward 开关控制 | Position Reference Source | 在 Data Inspector 里确认前馈是否符合轨迹斜率 | `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED` |
| `position_command_6064` | 进入 PT-5 的实际位置命令，等同 `position_reference_6064` | Position Reference Source / PT-5 外部轨迹输入 | 在 `Signals` 里看 reference 是否已经进入位置环 | PT-8 调参 runbook |
| `position_rate_command_6064` | 进入 PT-5 的实际速度前馈命令，等同选通后的 `position_rate_reference_6064` | Position Reference Source / PT-5 外部轨迹输入 | 在 `Signals` 里看速度前馈是否进入位置环 | PT-8 调参 runbook |
| `position_error_6064` | 位置误差 | PT-5 位置环内部 | 看位置环误差是否收敛 | 位置环控制逻辑 |
| `position_ff_velocity_60ff` | 轨迹前馈速度 | PT-5 位置环内部 | 看前馈是否和轨迹斜率一致 | `computePositionLoopCommand` / `computeInverseFeedforward` |
| `position_pid_velocity_60ff` | 位置 PID 速度修正 | PT-5 位置环内部 | 看 PID 是否在修正误差 | 位置环控制逻辑 |
| `position_loop_speed_command_60ff` | 位置环直接输出的速度命令，随后经过一拍延迟进入启动控制器 | PT-5 位置环内部 | 看它与 `speed_command_60ff` 的方向和幅值是否一致 | 位置环控制逻辑 |
| `position_loop_enabled` | 位置环实际使能状态 | PT-5 位置环内部 | 看闭环是否真的打开 | 位置环控制逻辑 |
| `computePositionLoopGate` | 位置环门禁合同函数 | MATLAB helper | 用它确认 ready_to_run 和位置环使能请求是否同时允许闭环 | `matlab/control/+sgv2/+control/computePositionLoopGate.m` |
| `computePositionLoopCommand` | 位置环合同函数 | MATLAB helper | 用它复现外部轨迹输入到速度输出的计算 | `matlab/control/+sgv2/+control/computePositionLoopCommand.m` |

位置跟踪、逆模型和位置 PID 已经进入 PT-5 模型。位置环请求在模型内部固定开启；Start 只让系统进入 `ready_to_run = 1`，不会自动播放 reference。实际运动仍由 `SGV2_REFERENCE_PLAY_REQUEST`、`SGV2_HOME_TO_ZERO_REQUEST`、`ready_to_run`、PT-5 限幅和启动控制器门禁共同约束。操作流程同步记录在项目根目录的 `SPEEDGOAT_V2_MINIMAL_LOGIC.md` 第 15 节；后续如果加新的 tunable 或观测信号，这里要同步补表。
