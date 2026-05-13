# speedgoat_v2_minimal slrtExplorer Runbook

本 runbook 描述当前已实现的最小 CSV 速度控制模型。PT-5 位置环已接进模型，位置 reference 由 `data/reference/position_reference_6064.txt` 提供；相关操作流程同步在项目根目录的 `SPEEDGOAT_V2_MINIMAL_LOGIC.md` 第 15 节。
如果你要做位置跟踪辨识，请先看 `docs/field_validation/speedgoat_v2_position_identification.md`，那份文档专门写了在 `slrtExplorer` 里实时记录并同步导出原始信号的格式和流程。
如果你要做 PT-8 位置环现场调参，请先看 `docs/field_validation/speedgoat_v2_position_tuning.md`。

建议从这个目录启动 MATLAB：

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
build_speedgoat_v2_minimal_app;
```

`build_speedgoat_v2_minimal_app` 会自动补齐项目内的 MATLAB path，不需要操作员手动 `addpath(genpath(...))` 或 `savepath`。

1. 连接目标机。
2. 先编辑 `data/reference/position_reference_6064.txt`，每行一个位置点，不写时间列。再在 MATLAB 里跑 `build_speedgoat_v2_minimal_app`，并在 `slrtExplorer` 中加载 `speedgoat_v2_minimal`。如果你刚改过 reference 文件，请确保加载的是最新生成的 `D:\Temporary_file\speedgoat_v2.0.0\matlab\speedgoat_v2_minimal.mldatx`，不是旧包。
3. 打开以下信号观察：
   `actual_network_state`、`expected_network_state`、`statusword_6041`、`error_code_603f`、
   `position_reference_6064`、`position_rate_reference_6064`、`position_actual_6064`、`mode_display_6061`、`velocity_actual_606c`、`diag_code`、`diag_message_id`、
   `diag_lookup_group`、`diag_lookup_hint`、`ready_to_run`、`auto_start_step`、`speed_command_60ff`。
4. 点击 `Start`。
5. 确认 `ready_to_run == 1` 后，在 Data Inspector 里叠加 `position_reference_6064` 和 `position_actual_6064`，确认实际位置按 reference 运行。
   若 `ready_to_run` 一直不起，在 `slrtExplorer` 的 `Diagnostics` 里先看 `auto_start_step` 和 `diag_lookup_hint`。
   如果 `auto_start_step` 卡在 `WAIT_BUS_OP`，去 `Signals` 看 `actual_network_state`；如果卡在 `WAIT_DRIVE_CLEAR`，先看 `error_code_603f`、`statusword_6041` 和 `position_actual_6064`。
6. 若 `actual_network_state != 8`，先查看 `diag_lookup_hint`，然后去 EtherCAT 手册查状态机。
7. 若 `error_code_603f != 0` 或 `statusword_6041` 异常，先停在零速并去 SV660N 手册查 `603Fh/6041h`。
8. 人工把速度降回 `0`。
9. 点击 `Stop` 停止应用。
10. 如果要开始位置辨识，改读 `speedgoat_v2_position_identification.md`，按那份文档在 `slrtExplorer` 里实时记录并同步导出原始数据和元数据。
11. 如果要开始位置环调参，改读 `speedgoat_v2_position_tuning.md`，先做低速小位移，不要直接上大轨迹。

PT-5 的位置 reference 来自 txt 文件，而不是现场直接改位置参数：

- `data/reference/position_reference_6064.txt`
- `position_reference_6064`
- `position_rate_reference_6064`

位置环会把 reference 位置、自动差分速度前馈和 `position_actual_6064` 合成最终速度命令，再回写到现有 `60FFh` 通道。
