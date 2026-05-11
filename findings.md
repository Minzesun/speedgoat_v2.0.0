# Findings & Decisions

## Requirements
- 新建一个完全独立的目录：`D:\Temporary_file\speedgoat_v2.0.0`
- 新目录中不包含 TwinCAT 相关内容
- 新目录中不包含 `demo_stable` 版内容
- 目标不是继续修补旧 demo，而是直接搭建“循环控制的框架”
- Simulink 模型必须严格参照 `熠速实时仿真_EtherCAT通讯.pdf`
- 设备控制必须严格参照 `SV660N系列伺服通讯手册-CN-C00.PDF`
- 实时模型配置与运行必须严格参照 `熠速实时仿真_实时模型.pdf`
- 目标机运行和调试要使用 `slrtExplorer` 界面
- 允许直接下发可能操作真机的指令，但这些指令必须是安全指令
- 本轮首先要用 `planning-with-files` 做规划，并把过程落到 `task_plan.md`、`findings.md`、`progress.md`
- 工作流程要遵循 Superpowers workflow
- 新框架应足够干净，便于后续扩展
- PDO 基线跟 `v1.0.0` 一样，并且要包含速度相关对象
- 第一版先只搭模型和 `slrtExplorer` 运行链，不先实现 MATLAB helper
- PDO 细节进一步锁定为：`1702h Outputs`、`1B04h Inputs`、`SyncMan 3`
- 不允许修改 ENI 文件

## Research Findings
- `D:\Temporary_file\Speedgoat` 仍保留明显的 demo / `demo_stable` 痕迹：
  - `create_sv660n_ethercat_demo.m`
  - `create_sv660n_ethercat_demo_stable.m`
  - `sv660n_ethercat_sequence_demo_stable*.mldatx/.slxc`
  - `+sv660n/+internal/applyStableOverrides.m`
  - 多个 `*_demo_stable_slrealtime_rtw` 与 `slprj` 生成目录
- `D:\Temporary_file\speedgoat_v1.0.0` 已经收敛成相对干净的四层结构：
  - `matlab/config`
  - `matlab/model`
  - `matlab/host`
  - `matlab/tests`
- `speedgoat_v1.0.0` 的 clean-room 结构说明，“干净框架”是可行的；但它已经叠加了手册对齐和 fault-reset 演进，不能不加甄别地整包复制到 `v2.0.0`
- `熠速实时仿真_实时模型.pdf` 直接给出的模型配置约束：
  - 第 5 页：求解器使用 `Fixed-step`
  - 第 5 页：代码生成目标在当前版本基线下应为 `slrealtime.tlc`
  - 第 5 页：`Fixed-step size` 建议 `>= 20e-6`
  - 第 7-13 页：`slrtExplorer` 用于实时设备管理、程序管理、连接配置和日志/运行观察
  - 第 10 页：可通过 REAL-TIME 的 step-by-step commands 执行 build / download / run / stop / disconnect
- `熠速实时仿真_EtherCAT通讯.pdf` 直接给出的通讯模型约束：
  - 第 6 页：EtherCAT 状态机必须按 `Init -> Pre-Op -> Safe-Op -> OP` 进入，不能跳跃
  - 第 23 页：`EtherCAT Init` 的 `Initialization End State` 可选 `Pre OP / Safe OP / OP`
  - 第 23 页：`DC Tuning` 是 EtherCAT Init 的显式配置项
  - 第 25 页：`EtherCAT Get State` 正常运行时 `State = 8`
  - 第 36 页：官方 demo 的主站结构分为 `Interface Setup`、`Send/Receive-MainDevice`、`ActualValues`、`CommandValues`、`Status`
  - 上述 demo 结构可作为“结构参考”，但不应把 demo 文件本身带入 `v2.0.0`
- `SV660N系列伺服通讯手册-CN-C00.PDF` 直接给出的驱动侧约束：
  - 第 15 页：SV660N EtherCAT 同步方式为 `DC-分布式时钟`
  - 第 16 页：通讯规范采用 `IEC 61800-7 CiA402 Drive Profile`
  - 第 23 页：必须按 CiA402 状态机流程引导伺服，驱动才可运行在指定状态
  - 第 24-25 页：EtherCAT 设备状态转移仍需按 `I -> P -> S -> O` 顺序，且 SV660N “仅支持 DC 同步模式”
  - 第 27 页：模式 `9` 对应 `CSV`（周期同步速度模式）
  - 第 30-31 页：固定 PDO `1702h Outputs + 1B04h Inputs` 覆盖：
    - 下行：`6040h / 607Ah / 60FFh / 6071h / 6060h / 60B8h / 607Fh`
    - 上行：`603Fh / 6041h / 6064h / 6077h / 6061h / 60B9h / 60BAh / 60BCh / 60FDh`
  - 第 32 页：`1B04h` 还提供 `606Ch` 实际速度，可作为后续观测扩展参考
  - 第 33 页：PDO 配置只能在 EtherCAT `Pre-Operational` 阶段修改；上电后若不重新配置会恢复默认映射
  - 第 168-169 页：存在故障复位延迟时间 `H0A.56`，默认 `10000 ms`，某些故障发生后必须等待该延迟结束才能复位
  - 第 189 页：`H0d.01` 故障复位仅对可复位故障有效，且要求在非运行状态、故障原因解除后使用；不可复位故障无效
- 用户进一步确认了 `v2.0.0` 的 PDO 选择边界：
  - 沿用 `v1.0.0` 的 PDO 基线
  - 必须保留速度相关对象
  - 具体锁定为 `1702h Outputs + 1B04h Inputs`
  - `SyncMan 3` 已由现有 ENI 设定
  - ENI 文件是既有输入，不允许修改
- 用户进一步确认了第一版功能边界：
  - 先把 Simulink 模型和 `slrtExplorer` 的运行链搭起来
  - 不先实现 `prepare/build/download/status/start/set_speed/stop/clear_fault` 这套 MATLAB helper 面
  - 因此第一版的设计重点应转向模型结构、实时机配置、参数观测、安全默认值和 `slrtExplorer` 操作 runbook
- 用户最终选择了路线 C：
  - 先手工搭一个最小 `.slx` 模型
  - 先把 `slrtExplorer` 的加载、运行、观察、停止链路跑通
  - 代码层骨架、配置层和测试层先后置
- 用户进一步调整了 `slrtExplorer` 运行策略：
  - 点击 `Start` 后，模型内部可以自动执行上电、上使能
  - 速度指令仍然由人工给定
  - 因此首版并不是“全人工起机”，而是“半自动起机 + 人工给速”
- 用户进一步补充了首版诊断要求：
  - 如果总线未到 `OP`，不能只停在门禁条件里
  - 必须报出“当前真实总线状态是什么”
  - 还要说明去 `slrtExplorer` 的哪里查看
  - 还要给出如何处理/如何恢复的提示
  - 同类要求也适用于驱动状态异常
- 用户进一步补充了诊断资料映射要求：
  - 报错内容里的编号不能只给数值
  - 还要说明应去哪本手册查具体物理含义
  - 至少要覆盖 EtherCAT 状态编号、`6041` 状态字、`603F` 错误码这三类

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| 以 `speedgoat_v1.0.0` 的 clean-room 分层作为结构参考，而不是从 `Speedgoat` 老 demo 复制 | 用户要“最干净”的框架；老 demo 目录存在 `demo_stable`、稳定版补丁和大量生成产物，不适合作为新根 |
| `v2.0.0` 初始范围聚焦“单轴 + CSV + EtherCAT 主站 + Safe host helper + slrtExplorer bring-up” | 这是满足手册约束和后续扩展性的最小闭环 |
| 默认 PDO 基线选择 `1702h Outputs + 1B04h Inputs` | 这是用户明确给出的 ENI 既有配置，并且同时保留了速度给定与速度反馈相关对象 |
| `v2.0.0` 的 PDO 范围不再另起一套，而是直接消费现有 ENI 已配置好的 PDO | 用户已明确要求 PDO 跟 `v1.0.0` 一样，且禁止改 ENI，因此实现侧只能围绕既有 ENI 契约搭模型 |
| 第一版先不引入 MATLAB helper | 这会让 `v2.0.0` 的首版重心落在模型/实时机/slrtExplorer 运行闭环，更符合“先把干净框架立起来”的目标 |
| ENI 文件在本项目中视为只读工件 | 这避免把 EtherCAT 网络配置职责误放到 Simulink 侧，也符合用户的显式边界 |
| 当前设计路线采用路线 C，而不是此前推荐的路线 B | 这是用户的明确选择；后续设计和 spec 需要围绕“最小模型优先”展开，而不是先搭 clean-room 代码框架 |
| 首版允许在 `slrtExplorer` 的 `Start` 动作后自动上电和上使能 | 用户明确允许这样做，这能简化现场操作，同时仍保留人工速度给定这一层安全边界 |
| 门禁失败要做成“可诊断、可定位、可处理”的报错面，而不是静默不推进 | 这是首版可用性的关键，否则现场只能看到系统不动，无法快速判断是总线、驱动还是操作问题 |
| 诊断面要把“编号 -> 手册出处”一起设计进去 | 现场排障不只需要知道值异常，还需要知道去哪里查含义，这能把模型输出和手册知识真正连起来 |
| 不在 `v2.0.0` 内复制 TwinCAT 配置过程、TwinCAT 工程文件或 demo 示例模型 | 用户明确排除 TwinCAT 内容；EtherCAT PDF 中的 TwinCAT 部分只作为外部知识来源 |
| `slrtExplorer` 作为设备/应用/日志调试主入口，MATLAB helper 作为可重复的命令入口 | 这与实时模型手册对 Connected Mode 与 Standalone Mode 的职责划分一致 |
| 安全策略先于功能策略：下载后不自动运行，不自动上电，不自动给速度，不自动清故障 | 用户允许真机控制，但要求“必须安全”，因此默认所有运动相关动作都应显式触发 |
| 故障复位能力建议保留为显式 helper，而不是藏进启动路径 | 手册明确存在故障复位条件和延迟窗口，显式化更安全，也更利于现场诊断 |

## Task 1 Config Contract
- `project_defaults()` 固化了 clean-room 默认值：
  - `ProjectName = "speedgoat_v2.0.0"`
  - `DefaultModelName = "speedgoat_v2_minimal"`
  - `DefaultApplicationName = "speedgoat_v2_minimal"`
  - `CommandPrefix = "SGV2"`
  - `SampleTime = 0.002`
- `sv660n_axis1()` 固化了单轴基线：
  - `AxisKey = "axis1"`
  - `DriveType = "SV660N"`
  - `SlaveName = "Drive 1 (InoSV660N)"`
  - `EthercatDeviceIndex = 0`
  - `EthernetPortNumber = 1`
  - `ExpectedModeOfOperation = int8(9)`
- `sv660n_eni_contract()` 固化了只读 ENI 契约：
  - `EniFile = <configRoot>/ethercat/eni/ENI2.xml`
  - `InitStateValue = "2"`
  - `ExpectedNetworkState = int32(8)`
  - `EnableDC = true`
  - `DCModeValue = "2"`
  - `DCTuningValue = "0"`
- `sv660n_pdo_map()` 锁定了 `1702h Outputs + 1B04h Inputs` 的 clean-room 观测面：
  - `Tx` keys: `controlword6040`, `targetVelocity60FF`, `modeOfOperation6060`, `maxProfileVelocity607F`
  - `Rx` keys: `errorCode603F`, `statusword6041`, `modeDisplay6061`, `velocityActual606C`
  - `Tx` offsets: `568`, `616`, `664`, `688`
  - `Rx` offsets: `568`, `584`, `648`, `768`
- 为了让 contract 在 `v2.0.0` 工作区内自洽，已把只读 ENI 副本放到：
  - `D:\Temporary_file\speedgoat_v2.0.0\matlab\config\ethercat\eni\ENI2.xml`
- `target_minimal_slrtexplorer()` now acts as the canonical Task 1 contract surface for later model-generation work.
- `test_targetConfig.m` 已被加强到可锁定：
  - 顶层字段名
  - `AxisConfig / Ethercat / PdoMap / Tunables / Signals` 的嵌套字段名
  - 代表性 PDO 的 offset / datatype / typesize
  - `TargetName / GeneratedModelFile / EniFile` 等 canonical surface 值
- 代码质量评审确认：
  - 不需要把 `sv660n_pdo_map()` 扩展成完整 ENI 镜像
  - 当前最小 PDO 面与 spec/plan 的“首版最小 contract”边界一致

## Implementation Planning Decisions

- `v2.0.0` 的 implementation plan 已落到：
  - `D:\Temporary_file\speedgoat_v2.0.0\docs\superpowers\plans\2026-04-19-speedgoat-v2-minimal-slrtExplorer.md`
- 计划继续采用 `v1` 的“配置驱动 + 程序化建模”方法，但只保留 `config / model / tests / docs` 最小子集，不引入 host helper。
- `1702h + 1B04h` 在首版模型中只暴露 8 个核心对象：
  - 下行：`6040h`、`60FFh`、`6060h`、`607Fh`
  - 上行：`603Fh`、`6041h`、`6061h`、`606Ch`
- `slrealtimeethercatlib/EtherCAT Init` 的运行参数继续与 `v1` 一致：
  - `initstate = "2"` 对应初始化终态到 `OP`
  - 运行期的目标网络态仍然通过 `expected_network_state = 8` 暴露和门禁
- 为了保持 `slrealtime.tlc` 的代码生成可控性，实施计划将序列控制逻辑落在程序化生成的 Stateflow chart 中，而不是 Interpreted MATLAB Function 或 host-side helper。
- `diag_lookup_hint` 在计划里按固定宽度 `uint8` 文本信号实现，避免在 R2021a + SLRT 环境中引入不确定的字符串代码生成路径。
- 首版验证策略保持轻量：
  - 配置合同测试
  - 模型生成测试
  - 控制器 harness 测试
  - 文档合同测试
  - 本地 `slbuild`
  - 真机验证仍保留到后续硬件 bring-up 阶段

## Task 2 Boundaries
- 只生成最小实时模型壳体，不实现 Task 3 的启动逻辑
- 顶层必须包含：
  - `EtherCAT Init`
  - `EtherCAT Get State`
  - `SV660N Sequence Controller`
  - `speed_command_60ff`
  - `speed_limit_607f`
  - `diag_lookup_hint`
- 生成器通过 `target_minimal_slrtexplorer()` 读取 Task 1 的既有 contract，不再单独拼装配置
- 模型输出路径由 `GeneratedModelFile` 决定，实际生成到：
  - `D:\Temporary_file\speedgoat_v2.0.0\matlab\model\models\speedgoat_v2_minimal.slx`

## Task 2 Verification
- Red test first:
  - `matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_modelGeneration.m'); disp(results([results.Passed] == 0));"`
  - Expected failure: `MATLAB:UndefinedFunction` for `build_speedgoat_v2_minimal`
- Green test:
  - `matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_modelGeneration.m'); assert(all([results.Passed]), 'Expected model-generation tests to pass.');"`
  - Result: passed, with non-fatal MATLAB shutdown warnings about loaded libraries

## Task 2 Contract Adjustment
- `target_minimal_slrtexplorer().Signals` now includes `SpeedLimit607F` so the approved top-level `speed_limit_607f` outport can exist without renaming the external contract.
- The internal collision workaround stays internal by prefixing the constant blocks:
  - `command_expected_network_state`
  - `command_speed_command_60ff`
  - `command_speed_limit_607f`
- `test_targetConfig.m` was updated to lock the expanded signal surface.

## Task 2 Cleanup Hardening
- `buildMinimalModel()` now uses a Task-2-scoped backup/restore cleanup wrapper so a failed build closes the model, removes partial artifacts, and restores any prior generated model.
- `test_modelGeneration.m` now also exercises a controlled mid-build failure and verifies the model file is not left behind and the model is not left loaded.

## Task 2 Test Contract Lock
- `test_modelGeneration.m` now explicitly asserts the approved top-level `expected_network_state` block exists.
- The success-path test also closes the loaded model with a cheap `onCleanup` guard after verification.

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| 根目录 `D:\Temporary_file` 已有旧 planning files，容易与本轮新项目混淆 | 新建 `D:\Temporary_file\speedgoat_v2.0.0`，把本轮 planning files 独立落到新根目录 |
| `Speedgoat` 目录里 demo / stable / build 产物非常多，直接搜索内容成本高 | 先做目录名和主干结构排查，再结合 `v1` clean-room 目录缩小复用面 |
| PDF 中文内容首次抽取受 PowerShell 编码影响 | 改为 Python `UTF-8` 输出后重新抽取关键页 |

## Resources
- `D:\Temporary_file\speedgoat_v1.0.0\实时机文件\熠速实时仿真_实时模型.pdf`
- `D:\Temporary_file\speedgoat_v1.0.0\实时机文件\熠速实时仿真_EtherCAT通讯.pdf`
- `D:\Temporary_file\speedgoat_v1.0.0\实时机文件\SV660N系列伺服通讯手册-CN-C00.PDF`
- `D:\Temporary_file\speedgoat_v1.0.0\matlab\config\target_baseline.m`
- `D:\Temporary_file\speedgoat_v1.0.0\matlab\model\build_speedgoat_v1_baseline.m`
- `D:\Temporary_file\speedgoat_v1.0.0\matlab\host\sg_prepare.m`
- `D:\Temporary_file\speedgoat_v1.0.0\docs\superpowers\specs\2026-04-18-speedgoat-v1-manual-alignment-design.md`
- `D:\Temporary_file\speedgoat_v1.0.0\docs\superpowers\plans\2026-04-18-speedgoat-v1-manual-alignment.md`
- `D:\Temporary_file\Speedgoat\matlab`
- `D:\Temporary_file\speedgoat_v2.0.0\docs\superpowers\specs\2026-04-19-speedgoat-v2-minimal-slrtExplorer-design.md`

## Visual/Browser Findings
- `熠速实时仿真_实时模型.pdf` 中与本次最相关的可视结构是：
  - 模型配置页明确把 `Solver -> Fixed-step` 和 `Code Generation -> slrealtime.tlc` 放在同一配置流程中
  - `slrtExplorer` 页面明确承担设备配置、连接、应用加载、应用运行和日志查看功能
- `熠速实时仿真_EtherCAT通讯.pdf` 中与本次最相关的可视结构是：
  - EtherCAT 状态图强调 `Init -> Pre-Op -> Safe-Op -> OP`
  - `EtherCAT Init`、`PDO Receive/Transmit`、`EtherCAT Get State` 是主站模型的核心块
  - demo 页面把主站结构分成 `Communication` 和 `Controller`，其中 `ActualValues / CommandValues / Status` 是很适合 clean-room 抽象的边界
- `SV660N系列伺服通讯手册-CN-C00.PDF` 中与本次最相关的可视结构是：
  - CiA402 状态机图是后续 Stateflow / 序列控制图的直接约束来源
  - 固定 PDO 映射页已经给出了 CSV 场景最接近当前需求的对象组合
  - 故障复位相关页同时给出了“复位只对可复位故障有效”和“某些故障需要等待延迟时间”的双重限制，这决定了 `clear_fault` 不能被设计成无条件动作

## Task 3 Diagnostic Mapping
- `diagCodes.NONE = 0` means the startup sequence is healthy and no diagnostic banner is needed.
- `diagCodes.BUS_NOT_OP = 1` maps to `diagMessageIds.CHECK_ETHERCAT_STATE = 10`, `diagLookupGroups.ETHERCAT = 1`, and the hint `Check EtherCAT manual: Get State / state machine`.
- `diagCodes.DRIVE_ERROR = 2` maps to `diagMessageIds.CHECK_603F = 20`, `diagLookupGroups.ERROR_CODE_603F = 2`, and the hint `Check SV660N manual: 603Fh error code`.
- `diagCodes.DRIVE_FAULT = 3` maps to `diagMessageIds.CHECK_6041 = 30`, `diagLookupGroups.STATUSWORD_6041 = 3`, and the hint `Check SV660N manual: 6041h statusword / CiA402`.
- `diagCodes.MODE_MISMATCH = 4` maps to `diagMessageIds.CHECK_6061 = 40`, `diagLookupGroups.MODE_DISPLAY_6061 = 4`, and the hint `Check SV660N manual: 6061h mode`.
- `diagCodes.WAITING_ENABLE = 5` reuses `diagMessageIds.CHECK_6041 = 30` and `diagLookupGroups.STATUSWORD_6041 = 3` for the generic wait-for-enable path.
- `autoStartStepIds` now define the chart progression:
  - `WAIT_BUS_OP = 1`
  - `WAIT_DRIVE_CLEAR = 2`
  - `AUTO_POWER_ON = 3`
  - `AUTO_ENABLE = 4`
  - `READY_TO_RUN = 5`
- Task 3 code review 的唯一残留 minor note：
  - `diagLookupHint` 的映射表当前在 `buildStartupChart.m` 和 `diagLookupHint.m` 各保留一份，功能正确但后续可再统一单一真源。

## Task 4 Documentation Outputs
- `docs/field_validation/speedgoat_v2_minimal.md`
- `docs/reference/speedgoat_v2_signal_parameter_reference.md`
- `docs/reference/speedgoat_v2_boundary_statement.md`
- `matlab/tests/test_documentContracts.m`
- Docs-contract test coverage:
  - approved `slrtExplorer` flow keywords
  - approved boundary exclusions

## Task 5 Regression and Artifact Checkpoint
- The initial Task 5 blockers were real and were fixed in source rather than worked around:
  - The four focused regression files now return column-shaped suites (`tests = tests(:);`), so the literal `results = [runtests(...); ...]` command is shape-safe again.
  - `matlab/tests/test_task5CommandCompatibility.m` now locks both Task 5 compatibility contracts:
    - focused regression aggregation remains vertcat-compatible
    - raw `load_system + slbuild` works without manual base-workspace tunables
  - `matlab/model/+sgv2/+internal/buildMinimalModel.m` now seeds the generated model workspace with:
    - `SGV2_SPEED_COMMAND_60FF = int32(0)`
    - `SGV2_SPEED_LIMIT_607F = uint32(1000)`
- The exact planned Task 5 commands now succeed as written:
  - focused regression stack: `4x1 TestResult`, `4 Passed, 0 Failed`
  - source rebuild: `D:\Temporary_file\speedgoat_v2.0.0\matlab\model\models\speedgoat_v2_minimal.slx`
  - raw `slbuild`: successful local `.mldatx` generation with no manual `assignin(...)`
- Generated local build artifacts:
  - `D:\Temporary_file\speedgoat_v2.0.0\matlab\speedgoat_v2_minimal.mldatx`
  - `D:\Temporary_file\speedgoat_v2.0.0\matlab\speedgoat_v2_minimal_slrealtime_rtw\`
  - `D:\Temporary_file\speedgoat_v2.0.0\matlab\speedgoat_v2_minimal.slxc`
- Operator pre-flight evidence remains intact after the fix:
  - `actual_network_state` and `expected_network_state` both exist as generated top-level outports.
  - `ready_to_run` gating remains covered by `tests/test_sequenceHarness.m` for bus-not-OP blocking and ready-state release.
  - `speed_command_60ff` defaults to `0` through the seeded model-workspace tunable.
  - `speed_limit_607f` defaults to `AxisConfig.DefaultMaxProfileVelocity607F = uint32(1000)`.
  - The runbook and boundary statement are present under `docs/`.
- Review checkpoint:
  - spec compliance review: `PASS`
  - code quality review: `approved`

## 2026-05-09 Position Tracking Requirements
- 用户已经确认现在能正常观测到 `position_actual_6064` / `Rx Position actual 6064`。
- 新目标是让实际位置 `Rx Position actual 6064` 跟踪给定位置值。
- 用户预期电机速度与位置之间存在可建模关系，但当前比例、符号、死区、延迟和有效线性范围未知。
- 用户要求下一步先获得速度/位置关系，再创建逆模型。
- 控制结构目标是外层位置环：位置给定值与 `position_actual_6064` 比较得到误差，经 PID 生成速度设定值，输出给现有速度环。
- 速度环仍接收位置环输出作为速度设定值，并通过 `60FFh` 驱动电机运动。
- 运行目标是让 `Rx Position actual 6064` 与给定位置值一致，实现位移跟踪。
- 本轮用户明确要求：
  - 使用 `planning-with-files`
  - 过程落到 `task_plan.md`、`findings.md`、`progress.md`
  - 按 Superpowers workflow 继续推进

## 2026-05-09 Baseline Code Findings
- 当前 `target_minimal_slrtexplorer()` 暴露的关键 tunable 仍是：
  - `SGV2_SPEED_COMMAND_60FF`
  - `SGV2_SPEED_LIMIT_607F`
- 当前 `target_minimal_slrtexplorer()` 暴露的关键观测信号已经包括：
  - `position_actual_6064`
  - `velocity_actual_606c`
  - `speed_command_60ff`
  - `ready_to_run`
  - `auto_start_step`
  - `diag_code`
- 当前 PDO map 已包含本任务需要的基础对象：
  - Rx `positionActual6064` -> `Drive 1 (InoSV660N).Inputs.Position actual value`，offset `600`，`int32`
  - Rx `velocityActual606C` -> `Drive 1 (InoSV660N).Inputs.Velocity actual value`，offset `768`，`int32`
  - Tx `targetVelocity60FF` -> `Drive 1 (InoSV660N).Outputs.Target velocity`，offset `616`，`int32`
- 当前模型生成链中，`addEthercatIo()` 已把 `velocityActual606C` 接入 startup controller，但还没有把 `positionActual6064` 接入控制器。
- 当前 startup chart 在 `ready_to_run == 1` 时直接把人工 `speed_command_60ff` 透传到 `velocity_command_60ff`。
- 当前 `test_sequenceHarness.m` 只验证速度命令透传和起机诊断，不验证位置误差、位置 PID、逆模型或位置跟踪。
- 当前文档已经把 `position_actual_6064` 作为可观察信号写入 runbook/reference，但还没有描述如何采集辨识数据、如何换算位置单位、如何调整位置 PID。

## 2026-05-09 Modeling Findings
- 对于 CSV 模式，速度命令与位置的关系不是静态的 `position = a * speed + b`，而是动态关系：
  - `position_actual_6064(k+1) - position_actual_6064(k)` 与速度命令/实际速度成比例
  - 更自然的辨识形式是 `d(position)/dt = K_cmd * speed_command_60ff + B_cmd`
- `velocity_actual_606c` 可作为中间观测量，用来区分两类问题：
  - `speed_command_60ff -> velocity_actual_606c` 的速度响应问题
  - `velocity_actual_606c -> position_actual_6064` 的机械/编码器比例问题
- 逆模型不应先假设手册单位完全等于现场单位；需要用真实 `position_actual_6064` 数据确认：
  - 正方向符号
  - 单位比例
  - 零速偏置
  - 低速死区
  - 加减速延迟
  - 饱和区间
  - 正反向是否对称
- 初版可采用线性逆模型：
  - `speed_ff = (position_rate_ref - B_cmd) / K_cmd`
  - 若延迟明显，再增加 `CommandDelaySamples` 或一阶速度响应补偿
- 位置 PID 的输出单位应设计为速度命令单位，与 `speed_command_60ff` / `targetVelocity60FF` 一致。
- 更稳妥的闭环命令组合是：
  - `speed_command = inverse_feedforward + pid_velocity_correction`
  - 再经过速度限幅、斜率限幅、ready/fault/mode 门禁后进入现有 `60FFh` 通道。
- 位置环的给定不再采用手工常量，而是外部轨迹输入：
  - `position_command_6064`
  - `position_rate_command_6064`
- 这样位置环可以同时拿到轨迹位置和轨迹速度，既能做误差闭环，也能直接复用逆模型前馈。

## 2026-05-09 Technical Decisions
| Decision | Rationale |
|----------|-----------|
| 继续使用 CSV 速度模式作为首版位置跟踪基础 | 用户目标明确是“位置环输出给速度环”；当前模型已在 CSV 模式下完成速度给定和位置观测 |
| 先做数据辨识，再写逆模型和 PID 实现 | 速度命令单位、编码器计数、机械传动比例、方向和延迟不能靠理论猜测 |
| 逆模型先作为速度前馈，不替代位置 PID | 前馈负责轨迹斜率，PID 负责误差、扰动和模型偏差 |
| 位置 PID 输出速度命令单位 | 这样可以直接接入现有 `targetVelocity60FF` 通道，避免首版切换控制模式 |
| 保留现有 `ready_to_run` 门禁 | 位置环不能在总线未 OP、驱动故障、模式不正确或未使能时输出非零速度 |
| 不修改 ENI 或 PDO 映射 | 本任务所需 `6064`、`606C`、`60FF` 已在现有 `1702h + 1B04h` 契约内 |
| 首版需要软件位置限位和速度/加速度限幅 | 位置闭环会主动运动，必须比人工速度给定多一层安全包络 |

## 2026-05-09 Open Risks
- 现场安全行程、最大速度和允许测试方向尚未写成配置；实现前必须确认。
- `position_actual_6064` 是否会在现场跨越 `int32` 边界或存在回零行为尚未验证。
- 如果机械摩擦或驱动内部速度环导致明显非线性，单一线性逆模型可能只适用于低速小位移范围。
- 如果 `velocity_actual_606c` 与 `diff(position_actual_6064)` 的比例或延迟不一致，需要拆成两级模型而不是一个总增益。
- 如果给定位置是工程单位而不是 6064 原始计数，必须增加单位转换层，并把转换参数作为可审阅配置。

## 2026-05-09 Safety Envelope Discovery
- 现有 runbook 和边界文档只明确了“非零速度仍由人工给定”，没有给出可直接复用的现场最大行程或测试窗口。
- `matlab/config/axes/sv660n_axis1.m` 里目前只有一个保守默认值：
  - `DefaultMaxProfileVelocity607F = uint32(1000)`
- 这说明当前工程已经有一个保守速度上限默认值，但没有足够信息自动推导单次位移上限、正反向测试范围或允许的工程单位换算。
- 用户已确认：最大单次位移和最大速度都要做成可调参数，再配一个保守默认值即可。
- 这意味着安全包络不应被写死在控制逻辑里，而应被放到配置层或 tunable 层，便于现场调小/调大。
- 由于当前仍未确认位置工程单位，保守默认值应先按原始 6064 / 60FF 对象单位表达，后续再考虑工程单位换算。
- 因此，PT-2 可以继续往下推进，但实现时必须把“可调参数 + 保守默认值”作为一等设计目标，而不是临时补丁。

## 2026-05-10 Documentation Sync Requirement
- 用户要求把当前做的东西的操作流程同步到 `SPEEDGOAT_V2_MINIMAL_LOGIC.md`。
- 用户还要求新加的文件和功能都要方便操作人员理解和复现。
- 因此，文档策略需要满足三条：
  - 当前已实现逻辑和规划中流程分开写
  - 新文件/函数必须写明目的、默认值、怎么看、怎么复现、何时停
  - runbook、signal/reference、logic doc、planning files 必须互相指向同一套操作路径
- 这条要求不只是写文档格式，更是后续新增位置环、逆模型、采集脚本时的验收标准。

## 2026-05-10 PT-2 Field Naming Draft
- 为了让 PT-2 可执行，安全包络和采集元数据需要先冻结字段名。
- 建议的最小字段集是：
  - `IdentificationMaxSpeed60FF`
  - `IdentificationMaxTravel6064`
  - `IdentificationStep6064`
  - `IdentificationStopBand6064`
- 这些名字的目的不是炫技，而是让配置、模型、测试和 runbook 使用同一套词汇。
- 当前阶段仍建议沿用原始对象单位作为默认值来源，避免在位置工程单位未确认前把转换问题混进辨识问题里。
- 已在 config contract 中落地：
  - `DefaultIdentificationMaxSpeed60FF = int32(200)`
  - `DefaultIdentificationMaxTravel6064 = int32(1000)`
  - `DefaultIdentificationStep6064 = int32(100)`
  - `DefaultIdentificationStopBand6064 = int32(20)`
- 已在 target tunables 中落地：
  - `SGV2_IDENTIFICATION_MAX_SPEED_60FF`
  - `SGV2_IDENTIFICATION_MAX_TRAVEL_6064`
  - `SGV2_IDENTIFICATION_STEP_6064`
  - `SGV2_IDENTIFICATION_STOP_BAND_6064`

## 2026-05-10 PT-2 Data Recording Protocol
- 已新增操作员辨识文档：
  - `docs/field_validation/speedgoat_v2_position_identification.md`
- 已新增数据目录说明：
  - `data/field_validation/README.md`
- 采集记录协议现在包含：
  - 原始数据文件：`.mat`
  - 快速查看导出：`.csv`
  - 同名操作员元数据记录：`.md`
- 推荐文件名：
  - `YYYYMMDD_axis1_<sequence>_<direction>_v<speed>_tr<travel>`
- 元数据必须至少记录：
  - 日期、轴名、序列、方向
  - `IdentificationMaxSpeed60FF`
  - `IdentificationMaxTravel6064`
  - `IdentificationStep6064`
  - `IdentificationStopBand6064`
  - `ready_to_run_at_start`
  - 结果、故障码和备注
- 停止条件已写入文档：
  - `ready_to_run == 0`
  - `diag_code != 0`
  - `error_code_603f != 0`
  - 超过最大位移或最大速度包络
- docs-contract 已锁定上述文档入口和关键字段，防止后续误删。

## 2026-05-10 PT-3 Offline Analysis Contract
- 已新增离线摘要函数：
  - `matlab/analysis/+sgv2/+analysis/summarizeIdentificationCapture.m`
- 这个函数目前负责把 capture struct 变成一份操作员和实现者都能看的摘要，输出：
  - `SampleTime`
  - `Duration`
  - `PositionDelta6064`
  - `ApproxVelocityFromPosition6064`
  - `VelocityError606C`
  - `MaxAbsTravel6064`
  - `MaxAbsSpeedCommand60FF`
  - `ReadyFraction`
  - `FaultSeen`
  - `Metadata`
- 输入合同已固定为：
  - `Time`
  - `SpeedCommand60FF`
  - `VelocityCommand60FF`
  - `VelocityActual606C`
  - `PositionActual6064`
  - `ReadyToRun`
  - `Statusword6041`
  - `ErrorCode603F`
  - `Metadata`
- 这个摘要层的用途是让后续现场数据先被“看懂”，再进入线性拟合和逆模型设计。
- 当前实现只覆盖离线摘要和结构校验，尚未做真实采集数据的线性拟合。

## 2026-05-10 PT-3 Linear Fit Entry
- 已新增线性拟合入口：
  - `matlab/analysis/+sgv2/+analysis/fitIdentificationRelationship.m`
- 这个入口先过滤：
  - `ready_to_run == 0`
  - `error_code_603f != 0`
  - `statusword_6041` fault 状态
  - `speed_command_60ff == 0`
- 再对 `diff(position_actual_6064)/Ts` 与 `speed_command_60ff` 做最小二乘拟合。
- 当前输出固定为：
  - `K_cmd`
  - `B_cmd`
  - `RSquared`
  - `UsedSampleIndex`
- 这一步先解决“能不能得到稳定线性斜率”的问题，后续如果现场数据表明速度环有明显延迟，再把延迟项单独补进模型。

## 2026-05-10 PT-3 Fit Preprocessing
- `fitIdentificationRelationship(capture)` 已补充样本预处理：
  - 未 ready 的样本不参与拟合
  - 故障样本不参与拟合
  - 零速度命令不参与拟合
  - 超出 `IdentificationMaxSpeed60FF` 或 `IdentificationMaxTravel6064` 包络的样本不参与拟合
  - 若元数据提供 `IdentificationTransientGuardSamples`，速度命令方向变化后的保护窗口不参与拟合
- 输出中新增 `Selection` 诊断，至少包含：
  - `TransientMask`
  - `SpeedEnvelopeMask`
  - `TravelEnvelopeMask`
  - `ValidMask`
- 这让操作员能看清楚哪些样本被用于估计 `K_cmd / B_cmd`，哪些样本被过滤掉。
- 当前“饱和”过滤先按辨识包络处理；真实驱动饱和、机械限位、摩擦死区仍需要用现场数据确认后再扩大规则。

## 2026-05-10 PT-4 Inverse Feedforward Contract
- 已新增逆模型前馈入口：
  - `matlab/control/+sgv2/+control/computeInverseFeedforward.m`
- 这个入口使用最小公式：
  - `speed_ff = (position_rate_ref - PositionVelocityBias) / PositionVelocityGain`
- 它会先做三类安全处理：
  - `PositionVelocityGain == 0` 或参数缺失时回退为零速度
  - `CommandDeadband` 内的小命令压零
  - 超过 `MaxTrackingSpeed` 的命令做限幅
- 当前输出包含：
  - `ModelValid`
  - `RawSpeedFeedforward60FF`
  - `SpeedFeedforward60FF`
  - `DeadbandMask`
  - `LimitedMask`
  - `FallbackReason`
- 配置层已经加入首版参数合同：
  - `PositionVelocityGain`
  - `PositionVelocityBias`
  - `CommandDeadband`
  - `CommandDelaySamples`
  - `MaxTrackingSpeed`
- 目前 `CommandDelaySamples` 只进入合同和文档，还没接入动态延迟模型；这是下一步留给 PT-4/PT-7 的内容。

## 2026-05-10 PT-4 Speed Saturation Contract
- 用户已要求去掉 `MaxTrackingAccelerationG` 斜率限幅，改成单纯的线速度饱和值。
- 当前默认线速度饱和值定为 `MaxTrackingSpeed = 6000`。
- `computeInverseFeedforward` 现在只保留：
  - `PositionVelocityGain`
  - `PositionVelocityBias`
  - `CommandDeadband`
  - `MaxTrackingSpeed`
- `PositionUnitMillimetersPerCount6064` 继续保留为单位注记和后续工程换算字段，但不再参与当前速度限幅逻辑。
- 这让逆模型前馈更像一个“带死区和饱和的直通器”，而不是额外的运动学约束器。

## 2026-05-10 PT-3 Unit Simplification Hypothesis
- 用户现场观察到 `actual position` 近似等于 `time * actual velocity`。
- 这个现象说明 `position_actual_6064` 与 `velocity_actual_606c` 的反馈关系大概率是自洽的，也说明速度反馈积分到位置反馈这条链路没有明显错配。
- 但这个现象本身还不能单独证明 `speed_command_60ff` 的单位就是 `mm/s`，因为它只比较了“实际速度”和“实际位置”，没有比较“速度命令”和“实际速度”。
- 关键验证应改为短流程：
  - 下发几个保守的 `speed_command_60ff`
  - 记录稳态 `velocity_actual_606c`
  - 检查 `velocity_actual_606c / speed_command_60ff` 是否接近 `1`
  - 同时确认正负方向、死区、饱和和延迟
- 如果这个比例确实接近 `1` 且单位已确认是线速度 `mm/s`，则 PT-3 可以从完整系统辨识收缩为单位/比例确认，PT-4 的逆模型也可以简化成近似直通前馈加保护。
- 用户随后明确选择跳过进一步比例验证，直接采用工作假设：
  - `speed_command_60ff` 视为 `mm/s`
  - `velocity_actual_606c` 视为同单位反馈
  - `position_actual_6064` 按 `mm` 处理
- 这意味着后续工作不再把 PT-3 当作完整系统辨识，而是把它收缩为单位/比例假设的工程前提。

## 2026-05-10 PT-4 Unit Assumption Lock
- 用户进一步要求直接按 `PositionVelocityGain = 1` 处理逆模型前馈。
- 同时采用 `PositionVelocityBias = 0`。
- `PositionUnitMillimetersPerCount6064 = 1` 表示 `6064` 直接按 `mm` 理解，用于单位注记和后续工程换算。
- `MaxTrackingSpeed = 6000` 作为默认线速度饱和值。
- 这使得 `computeInverseFeedforward` 在默认配置下近似退化为：
  - `speed_ff = position_rate_ref`
- 对于后续现场调试，只要 `mm/s` 假设成立，逆模型前馈就不必再重新辨识；需要做的是位置 PID 和上限饱和的现场微调。

## 2026-05-10 PT-5 External Trajectory Input Decision
- 用户已确认第一版位置环的给定值来自外部轨迹输入，而不是手工常量。
- 推荐最小输入合同是：
  - `position_command_6064`：轨迹位置
  - `position_rate_command_6064`：轨迹速度前馈
- 这让位置环可以同时保留误差闭环和轨迹前馈，后续接 Simulink 时也更容易直接挂上上位机/轨迹发生器。

## 2026-05-10 PT-5 Position Loop Helper Contract
- 已新增纯 MATLAB 位置环 helper：
  - `sgv2.control.computePositionLoopCommand(position_command_6064, position_rate_command_6064, position_actual_6064, params, state)`
- 这个 helper 把外部轨迹位置、轨迹速度前馈和实际位置合成一个最终速度命令。
- 当前默认行为是：
  - 位置环未使能时安全回零
  - 位置误差由 `position_command_6064 - position_actual_6064` 计算
  - 轨迹前馈沿用 `computeInverseFeedforward`
  - 最终输出仍受 `MaxTrackingSpeed` 限幅
- 这意味着后续模型只要把外部轨迹和实际位置喂给这个 helper，就能直接得到：
  - `position_error_6064`
  - `position_ff_velocity_60ff`
  - `position_pid_velocity_60ff`
  - `position_loop_speed_command_60ff`

## 2026-05-10 Default Value Meaning
- `PositionVelocityGain = 1` 的意义是：默认按 1:1 直通处理期望位置变化率和速度命令，不引入额外比例缩放。
- `PositionVelocityBias = 0` 的意义是：默认不加常数偏置，避免在没有现场偏差证据前把速度命令整体抬高或压低。
- `PositionUnitMillimetersPerCount6064 = 1` 的意义是：默认把 `6064` 按 `mm` 理解，即 1 count 视作 1 mm，便于后续把位置、速度和物理单位统一起来。
- 这三个默认值合在一起，就是一套“先按 `mm` / `mm/s` 直通，再按现场需要微调”的最小单位合同。

## 2026-05-10 PT-5 Simulink Wiring Contract
- `PT-5 Position Loop` 现在已经接入生成模型。现场主要观察 4 个运行信号：
  - `position_command_6064`
  - `position_rate_command_6064`
  - `position_actual_6064`
  - `ready_to_run`
- 为了让 `slrtExplorer` Parameters 页能直接改位置环参数，位置环使能、PID、积分限幅、前馈比例和最大跟踪速度现在由顶层 Constant 块接入 PT-5，而不是藏在 Stateflow 子系统内部。
- 其余位置环参数都留在子系统内部，通过 model workspace tunable 驱动：
  - `PositionLoopEnabled`
  - `PositionLoopKp`
  - `PositionLoopKi`
  - `PositionLoopKd`
  - `PositionLoopSampleTime`
  - `PositionLoopIntegratorLimit`
  - `PositionVelocityGain`
  - `PositionVelocityBias`
  - `CommandDeadband`
  - `MaxTrackingSpeed`
- 这样可以保持顶层模型清爽，操作员只需要看真实轨迹和实际位置，调参时再进子系统看内部常量。
- 当前 PT-5 通过 `ready_to_run` 继承 startup controller 的无故障 / 模式正确门禁，额外门禁规则后续只在现场发现需要时再细化。
- Stateflow chart 里使用的临时量需要显式声明为 local data，不然 `buildMinimalModel` 会在 chart 编译阶段报 unresolved symbols。
- PT-5 的内部参数块用了 `_constant` 后缀，这样 `test_modelGeneration` 可以直接锁定“哪些是外部输入、哪些是子系统内部常量”。

## 2026-05-10 PT-5 Gate Helper Contract
- 已新增门禁合同函数：
  - `matlab/control/+sgv2/+control/computePositionLoopGate.m`
- 它把 `ready_to_run` 和位置环使能请求合成一个显式门禁，只有两者同时满足时，位置环才允许输出非零速度。
- 这一步把“位置环是否允许动”的判断从 chart 条件里抽出来了，后续如果要继续细化 fault / mode 规则，只需要改这个小 helper 和对应文档。
- 当前 `ready_to_run` 仍然由 startup controller 负责，它已经继承了总线、故障和模式检查，所以 PT-5 的门禁链路仍保持安全起步边界。

## 2026-05-11 PT-8 Tuning Runbook
- 已新增 PT-8 低速小位移调参文档：
  - `docs/field_validation/speedgoat_v2_position_tuning.md`
- 这份文档把 PT-8 的默认起点锁定为：
  - `PositionLoopEnabled = false`
  - `PositionLoopKp = 0`
  - `PositionLoopKi = 0`
  - `PositionLoopKd = 0`
  - `PositionLoopIntegratorLimit = 0`
  - `PositionLoopSampleTime = 0.002`
  - `PositionVelocityGain = 1`
  - `PositionVelocityBias = 0`
  - `CommandDeadband = 0`
  - `MaxTrackingSpeed = 6000`
  - `PositionUnitMillimetersPerCount6064 = 1`
- 调参顺序明确为：先看轨迹前馈，再加小 `P`，最后才考虑很小的 `I/D`。
- PT-8 的停止条件也被写死：方向错误、误差扩大、抖动、冲顶、或 `ready_to_run` / `statusword_6041` / `error_code_603f` 异常时立刻停。

## 2026-05-11 Tunable Trajectory Inputs
- 现场在 `slrtExplorer` 里看不到 `position_rate_command_6064` 的原因是：它原来是模型根层 `Inport`，不是 tunable parameter。
- 已改成两个 `Constant` block 引用 model workspace tunable：
  - `SGV2_POSITION_COMMAND_6064`
  - `SGV2_POSITION_RATE_COMMAND_6064`
- 默认值均为 `int32(0)`，已经写入 axis config 和 model workspace seed。
- 这两个 `SGV2_*` 名称会出现在 `Parameters` 页签；对应的 `position_command_6064` / `position_rate_command_6064` 仍作为 `Signals` 里的观测量使用。
- 修改后已重新生成：
  - `matlab/model/models/speedgoat_v2_minimal.slx`

## 2026-05-11 SlrtExplorer Package Refresh
- 用户在 `slrtExplorer` 里仍看不到 position 相关参数的根因，是现场还在加载旧的 `matlab\speedgoat_v2_minimal.mldatx`，而不是最新重建的包。
- 已通过 `slbuild('speedgoat_v2_minimal')` 重新生成新的 `matlab\speedgoat_v2_minimal.mldatx`，其中 `paramSet/paramInfo.json` 已包含：
  - `SGV2_POSITION_COMMAND_6064`
  - `SGV2_POSITION_RATE_COMMAND_6064`
  - `position_loop_speed_command_60ff_delay`
- 为了打掉 PT-5 与启动控制器之间的代数环，`position_loop_speed_command_60ff` 到控制器输入之间加入了一拍 `Unit Delay`。
- 这意味着现场调参时应重点看：
  - `position_loop_speed_command_60ff`
  - `speed_command_60ff`
  - 两者是否只差一拍，而不是缺参数。

## 2026-05-11 PT-5 Chart Update Timing
- `build_speedgoat_v2_minimal` 报 `buildPositionLoopChart` 第 80 行错误的根因，是 `buildPositionLoopChart` 自己在图还没完全接完时就强制执行了 `set_param(..., 'SimulationCommand', 'update')`。
- 这会让 Stateflow 在半成品模型上提前跑代码生成，遇到 PT-5 新增连线时更容易炸。
- 已把这次 `update` 挪到 `buildMinimalModel` 完成全部连线之后再执行。
- 更新后，`build_speedgoat_v2_minimal` 和 `test_task5CommandCompatibility` 都已恢复通过。

## 2026-05-11 Application Package Builder
- `build_speedgoat_v2_minimal` 只负责生成 `.slx`，不等于部署给 `slrtExplorer` 的 `.mldatx` 应用包。
- 已新增 `build_speedgoat_v2_minimal_app`，它会先构建 `.slx`，再 `slbuild` 生成应用包，并同步更新：
  - `matlab\speedgoat_v2_minimal.mldatx`
  - `matlab\model\speedgoat_v2_minimal.mldatx`
- 新 helper 会在打包后解压检查参数表，确保 `SGV2_POSITION_COMMAND_6064`、`SGV2_POSITION_RATE_COMMAND_6064`、`SGV2_POSITION_LOOP_ENABLED`、`SGV2_POSITION_LOOP_KP/KI/KD` 和 `SGV2_MAX_TRACKING_SPEED` 都在包里。
- 这个入口的目的，是避免操作者继续误加载旧的 model-folder package，从而在 `Parameters` 里只看到旧的三项参数。

## 2026-05-11 MATLAB Path Bootstrap
- 用户在交互式 MATLAB 里运行 `build_speedgoat_v2_minimal_app` 仍报 `PT-5 Position Loop/PositionLoopChart` codegen 错误。
- 干净 batch 进程能通过，是因为命令里显式执行了 `addpath(genpath(pwd))`；现场会话不一定包含 `matlab\control` 和 `matlab\config\ethercat`。
- 回归测试用“不完整 path”复现了入口问题：只保留 `config` 和 `model` 时，构建会先找不到 `sv660n_eni_contract`，后续也会让 Stateflow 找不到 `sgv2.control.*` helper。
- 已新增 `bootstrap_speedgoat_v2_path`，并让 `build_speedgoat_v2_minimal` / `build_speedgoat_v2_minimal_app` 在入口处调用它。
- 操作员现在只要能调用构建入口，就不需要手动 `savepath`；入口会自动补齐项目内源码目录。
