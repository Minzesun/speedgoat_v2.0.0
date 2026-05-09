# speedgoat_v2_minimal Signal And Parameter Reference

| Name | Meaning | Source | slrtExplorer 里怎么看 | 出问题查 |
|---|---|---|---|---|
| `actual_network_state` | EtherCAT 实际网络状态 | `EtherCAT Get State` | 在 `Signals` / `Status` 里看它是否等于 `expected_network_state = 8` | EtherCAT 手册的 `Get State` 与状态机章节 |
| `expected_network_state` | 期望网络状态，固定为 `8` | Constant command source | 同屏对照 `actual_network_state` 和 `diag_lookup_hint` | EtherCAT 手册的状态机章节 |
| `statusword_6041` | 驱动状态字 | `1B04h Inputs` | 在 `Signals` 里看是否随 `ready_to_run` 变化到位 | SV660N 手册的 `6041h` / CiA402 状态机章节 |
| `error_code_603f` | 驱动错误码 | `1B04h Inputs` | 在 `Signals` 里先看是否非零，再看 `diag_lookup_hint` | SV660N 手册的 `603Fh` 错误码章节 |
| `position_actual_6064` | 实际位置 | `1B04h Inputs` | 在 `Signals` 里看位置反馈是否随运动变化 | SV660N 手册的 `6064h` 位置反馈对象章节 |
| `mode_display_6061` | 模式显示 | `1B04h Inputs` | 在 `Signals` 里确认是否为 CSV 对应模式 | SV660N 手册的 `6061h` 模式章节 |
| `velocity_actual_606c` | 实际速度 | `1B04h Inputs` | 在 `Signals` 里确认起机前接近 `0`、运行中变化合理 | SV660N 手册的 `606Ch` 速度反馈对象章节 |
| `diag_code` | 运行诊断代码 | Sequence Controller | 在 `Diagnostics` 里先看它是否为 `0` | Sequence Controller 对应的诊断码定义 |
| `diag_message_id` | 诊断消息编号 | Sequence Controller | 在 `Diagnostics` 里和 `diag_lookup_hint` 一起看 | Sequence Controller 的消息映射与手册提示 |
| `diag_lookup_group` | 手册查阅分组 | Sequence Controller | 在 `Diagnostics` 里看它把问题导向哪类对象 | `EtherCAT` / `SV660N` 手册对应章节 |
| `diag_lookup_hint` | 查阅提示 | Sequence Controller | 在 `Diagnostics` 里优先读这个，再回到信号面排查 | `EtherCAT` 或 `SV660N` 手册的对应对象章节 |
| `ready_to_run` | 是否允许人工给速度 | Sequence Controller | 在 `Signals` / `Diagnostics` 里看是否变成 `1` | Sequence Controller 的起机门禁逻辑 |
| `auto_start_step` | 自动起机当前步骤 | Sequence Controller | 在 `Diagnostics` 里看它卡在哪一步 | Sequence Controller 的状态推进定义 |
| `speed_command_60ff` | 人工速度给定 | `1702h Outputs` | 在 `Commands` 里确认人工给值已下发 | SV660N 手册的 `60FFh` 目标速度对象章节 |
| `speed_limit_607f` | 保守速度上限 | `1702h Outputs` | 在 `Commands` 里确认它限制了人工给定范围 | SV660N 手册的 `607Fh` 最大速度对象章节 |
