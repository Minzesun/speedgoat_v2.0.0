# speedgoat_v2_minimal slrtExplorer Runbook

addpath(genpath('D:\Temporary_file\speedgoat_v2.0.0\matlab'));
savepath;

1. 连接目标机。
2. 在 `slrtExplorer` 中加载 `speedgoat_v2_minimal`。
3. 打开以下信号观察：
   `actual_network_state`、`expected_network_state`、`statusword_6041`、`error_code_603f`、
   `mode_display_6061`、`velocity_actual_606c`、`diag_code`、`diag_message_id`、
   `diag_lookup_group`、`diag_lookup_hint`、`ready_to_run`、`auto_start_step`、`speed_command_60ff`。
4. 点击 `Start`。
5. 确认 `ready_to_run == 1` 后再人工修改 `speed_command_60ff`。
   若 `ready_to_run` 一直不起，在 `slrtExplorer` 的 `Diagnostics` 里先看 `auto_start_step` 和 `diag_lookup_hint`。
   如果 `auto_start_step` 卡在 `WAIT_BUS_OP`，去 `Signals` 看 `actual_network_state`；如果卡在 `WAIT_DRIVE_CLEAR`，先看 `error_code_603f` 和 `statusword_6041`。
6. 若 `actual_network_state != 8`，先查看 `diag_lookup_hint`，然后去 EtherCAT 手册查状态机。
7. 若 `error_code_603f != 0` 或 `statusword_6041` 异常，先停在零速并去 SV660N 手册查 `603Fh/6041h`。
8. 人工把速度降回 `0`。
9. 点击 `Stop` 停止应用。
