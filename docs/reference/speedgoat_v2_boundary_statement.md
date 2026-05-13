# speedgoat_v2_minimal Boundary Statement

- 不改 ENI。
- 不做 MATLAB helper。
- 不做 TwinCAT。
- 不带入 `demo_stable`。
- 只支持单轴 CSV。
- 只消费 `1702h Outputs + 1B04h Inputs`。
- 自动起机只推进到 `ready_to_run`。
- 位置运行由 txt reference 驱动，`ready_to_run` 仍是实际运动门禁。
