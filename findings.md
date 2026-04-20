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
