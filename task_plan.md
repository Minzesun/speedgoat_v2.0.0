# Task Plan

## Active Task: 2026-05-09 `Rx Position actual 6064` 位置跟踪逆模型与位置环控制规划

## Goal
在现有 `speedgoat_v2.0.0` CSV 速度控制框架上，先通过现场数据辨识 `speed_command_60ff` / `velocity_actual_606c` 与 `position_actual_6064` 的实际动态关系，再建立位置轨迹到速度给定的逆模型，并在 Simulink 模型中增加外层位置 PID，使 `Rx Position actual 6064` 尽可能跟踪给定的位置值。

## Current Phase
Position Tracking PT-5 is wired into Simulink with conservative defaults. Baseline model already exposes `position_actual_6064`, `velocity_actual_606c`, and `speed_command_60ff`; the next work is field tuning.

## Phases

### Phase 1: Requirements & Discovery
- [x] 确认用户目标是“新建独立的 `speedgoat_v2.0.0`”，而不是在 `Speedgoat` 或 `speedgoat_v1.0.0` 上继续追加
- [x] 定位并抽取三份核心手册中的硬约束
- [x] 识别旧目录中的 `demo_stable` / TwinCAT 痕迹与可复用的 clean-room 结构
- [x] 将关键发现写入 `findings.md`
- **Status:** complete

### Phase 2: Design & Isolation Strategy
- [x] 明确 `v2.0.0` 的目录边界、排除项和最小初始骨架
- [x] 给出 2-3 条实现路线并收敛推荐方案
- [x] 明确真机安全指令边界与 `slrtExplorer` 调试职责
- [x] 形成待用户确认的设计包
- **Status:** complete

### Phase 3: Spec & Implementation Planning
- [x] 在设计获批后写出 `docs/superpowers/specs/` 设计文档
- [x] 进行 spec self-review
- [x] 在设计获批后写出 `docs/superpowers/plans/` 实施计划
- **Status:** complete

### Phase 4: Clean-Room Scaffold
- [x] 创建 `config / model / tests / docs` 干净骨架
- [x] 只引入手册要求和运行所需的最小文件
- [x] 禁止带入 `demo_stable`、TwinCAT 工程脚本和旧 build 产物
- **Status:** complete

#### Task 1: Create the Clean-Room Config Contract
- [x] `matlab/tests/test_targetConfig.m`
- [x] `matlab/config/project_defaults.m`
- [x] `matlab/config/axes/sv660n_axis1.m`
- [x] `matlab/config/ethercat/sv660n_eni_contract.m`
- [x] `matlab/config/ethercat/sv660n_pdo_map.m`
- [x] `matlab/config/target_minimal_slrtexplorer.m`
- [x] MATLAB config-contract test passes

### Phase 5: Simulink Real-Time Model Bring-Up
- [x] 按 `熠速实时仿真_实时模型.pdf` 配置固定步长与 `slrealtime.tlc`
- [x] 按 `熠速实时仿真_EtherCAT通讯.pdf` 搭建 EtherCAT 主站 / PDO / 状态观测
- [x] 按 `SV660N系列伺服通讯手册-CN-C00.PDF` 搭建 SV660N 的 CiA402 / CSV 控制链
- [x] 优先打通 `slrtExplorer` 的加载、运行、观察和调试链路
- **Status:** complete

#### Task 2: Generate the Minimal Real-Time Model Shell
- [x] `matlab/tests/test_modelGeneration.m`
- [x] `matlab/model/build_speedgoat_v2_minimal.m`
- [x] `matlab/model/+sgv2/+internal/buildMinimalModel.m`
- [x] `matlab/model/+sgv2/+internal/addEthercatIo.m`
- [x] `matlab/model/+sgv2/+internal/addManualCommandInterface.m`
- [x] `matlab/model/+sgv2/+internal/addSequenceController.m`
- [x] `matlab/model/+sgv2/+internal/addObservabilityPorts.m`
- [x] Model shell generation test passes

#### Task 3: Implement the Startup Sequence and Diagnostics
- [x] `matlab/tests/test_sequenceHarness.m`
- [x] `matlab/model/+sgv2/controlword.m`
- [x] `matlab/model/+sgv2/statusState.m`
- [x] `matlab/model/+sgv2/+internal/diagCodes.m`
- [x] `matlab/model/+sgv2/+internal/diagMessageIds.m`
- [x] `matlab/model/+sgv2/+internal/diagLookupGroups.m`
- [x] `matlab/model/+sgv2/+internal/autoStartStepIds.m`
- [x] `matlab/model/+sgv2/+internal/buildStartupChart.m`
- [x] `matlab/model/+sgv2/+internal/buildFrameworkHarness.m`
- [x] `matlab/model/+sgv2/+internal/addSequenceController.m`
- [x] Harness test passes for bus-not-OP blocking and ready-to-run gating

#### Task 4: Write the slrtExplorer Runbook and Reference Docs
- [x] `matlab/tests/test_documentContracts.m`
- [x] `docs/field_validation/speedgoat_v2_minimal.md`
- [x] `docs/reference/speedgoat_v2_signal_parameter_reference.md`
- [x] `docs/reference/speedgoat_v2_boundary_statement.md`
- [x] Docs-contract test passes for approved slrtExplorer flow and exclusions

### Phase 6: Host Control & Safety Envelope
- [ ] 明确第一版不先实现 MATLAB helper 面，后续如需要再补
- [ ] 锁定“安全可下发”与“禁止自动下发”的命令边界
- [ ] 为真实设备调试加入安全默认值、门禁和可观测性
- **Status:** pending

### Phase 7: slrtExplorer Bring-Up & Hardware Validation
- [ ] 规划 `slrtExplorer` 中的设备配置、应用加载、运行、日志与调试步骤
- [ ] 规划安全的真机 bring-up 顺序
- [ ] 记录只能在现场确认的项目
- **Status:** pending

### Phase 8: Delivery
- [ ] 汇总设计与实施边界
- [ ] 更新 planning files 为可续接状态
- [ ] 向用户交付推荐方案与下一步执行入口
- **Status:** pending

## Position Tracking Phases

### PT-1: Requirements & Baseline Discovery
- [x] 确认用户目标：让 `Rx Position actual 6064` 跟踪给定位置值
- [x] 确认当前可观测信号：`position_actual_6064`、`velocity_actual_606c`
- [x] 确认当前可控入口：`speed_command_60ff` -> `velocity_command_60ff` -> `Tx Target velocity 60FF`
- [x] 确认当前控制模式仍为 CSV，`6060/6061 = 9`
- [x] 记录现有工程还没有位置给定、位置 PID、逆模型或数据辨识脚本
- **Status:** complete for planning context

### PT-2: Safe Identification Data Acquisition
- [x] 定义现场采集信号：`time`、`ready_to_run`、`speed_command_60ff`、`velocity_command_60ff`、`velocity_actual_606c`、`position_actual_6064`、`statusword_6041`、`error_code_603f`
- [x] 定义安全运动包络：最大速度、最大位移窗口、正反向测试范围、停止条件、急停/停机步骤
- [x] 把最大速度和最大单次位移都做成可调参数，并给出保守默认值，默认值先以原始 6064 / 60FF 单位表达
- [x] 将安全包络字段落成明确命名：`IdentificationMaxSpeed60FF`、`IdentificationMaxTravel6064`、`IdentificationStep6064`、`IdentificationStopBand6064`
- [x] 约定采集文件元数据：日期、轴名、测试序列、速度档位、正反向、最大位移包络、是否发生故障
- [x] 设计低风险输入序列：零速保持、正向阶跃、反向阶跃、分段速度阶梯、低速三角/梯形位置变化
- [x] 使用 `slrtExplorer` 或后续 MATLAB target logging 采集数据，不修改 ENI
- [x] 把原始采集数据保存到 `data/field_validation/`，文件名包含日期、轴、速度命令和方向
- [x] 写出操作员文档：`docs/field_validation/speedgoat_v2_position_identification.md`
- [x] 写出数据目录说明：`data/field_validation/README.md`
- **Status:** protocol complete; pending hardware data

### PT-3: Speed-to-Position Relationship Identification
- [x] 建立离线辨识摘要入口：`sgv2.analysis.summarizeIdentificationCapture(capture)`
- [x] 定义 capture 输入合同：`Time`、`SpeedCommand60FF`、`VelocityCommand60FF`、`VelocityActual606C`、`PositionActual6064`、`ReadyToRun`、`Statusword6041`、`ErrorCode603F`、`Metadata`
- [x] 从 `position_actual_6064` 计算每采样周期的 `delta_position` 和位置导数（已用 mock capture 锁定）
- [x] 生成 `VelocityError606C`，用于后续对比 `velocity_actual_606c` 与 `diff(position_actual_6064)/Ts`
- [x] 建立线性拟合入口：`sgv2.analysis.fitIdentificationRelationship(capture)`
- [x] 定义拟合输出：`K_cmd`、`B_cmd`、`RSquared`、`UsedSampleIndex`
- [x] 在离线拟合入口中实现预处理：剔除未 ready、故障、零速度、换向瞬态和超出包络的样本
- [x] 暴露样本选择诊断：`Selection.TransientMask`、`Selection.ValidMask`
- [ ] 用现场采集数据确认预处理规则是否需要再加入人工饱和标记或更长换向保护
- [x] 采用用户指定工作假设：`speed_command_60ff` 视为 `mm/s`，`velocity_actual_606c` 视为同单位反馈，因此 PT-3 收缩为单位/比例确认而不是完整系统辨识
- [ ] 对比现场 `velocity_actual_606c` 与 `diff(position_actual_6064)/Ts`，确认两者量纲、符号和延迟关系
- [ ] 拟合线性模型：`d(position)/dt = K_cmd * speed_command_60ff + B_cmd`
- [ ] 如果实际速度响应存在明显滞后，补充一阶/纯延迟模型：`velocity_actual -> d(position)/dt`
- [ ] 记录线性有效范围、死区、饱和、反向不对称和估计误差
- **Status:** offline summary, preprocessing, and fit helper complete; pending hardware data for actual fit

### PT-4: Inverse Model Design
- [x] 基于 PT-3 的辨识结果定义初版逆模型：`speed_ff = (position_rate_ref - B_cmd) / K_cmd`
- [x] 建立离线/可测试入口：`sgv2.control.computeInverseFeedforward(position_rate_ref, params)`
- [x] 增加方向符号、死区补偿、速度限幅和无效模型回退
- [x] 将线速度饱和值设为 `6000`
- [x] 采用用户指定工作假设：`PositionVelocityGain = 1`、`PositionVelocityBias = 0`、`PositionUnitMillimetersPerCount6064 = 1`
- [x] 明确逆模型只产生速度前馈，不直接绕过现有 CiA402/CSV 起机门禁
- [x] 将辨识参数放入配置层：`PositionVelocityGain`、`PositionVelocityBias`、`CommandDeadband`、`CommandDelaySamples`、`MaxTrackingSpeed`、`PositionUnitMillimetersPerCount6064`
- [x] 将 PT-4 操作说明同步到 `SPEEDGOAT_V2_MINIMAL_LOGIC.md` 和 signal/reference 文档
- **Status:** static inverse feedforward helper, mm/s unit assumption, and 6000 speed saturation contract complete; model wiring pending

### PT-5: Position Loop Controller Design
- [x] 第一版位置给定采用外部轨迹输入：`position_command` / `position_rate_command`
- [x] 建立纯 MATLAB 位置环 helper：`sgv2.control.computePositionLoopCommand(position_command_6064, position_rate_command_6064, position_actual_6064, params, state)`
- [x] 在现有速度环外增加位置环：外部轨迹输入 `position_command` / `position_rate_command` - `position_actual_6064` -> PID + 前馈 -> speed correction
- [x] 最终速度命令采用 `speed_command = speed_ff + speed_pid_correction`
- [x] 增加积分限幅、输出速度限幅和 `ready_to_run` 零输出门禁
- [x] 只在 `ready_to_run == 1`、无故障、模式正确时允许位置环输出非零速度
- [x] 暴露调试信号：`position_command`、`position_error`、`position_pid_velocity`、`position_ff_velocity`、`position_loop_speed_command`、`position_loop_enabled`
- [x] 将 `PT-5 Position Loop` 的运行信号和现场调参参数分开：4 个运行信号保持可读，调参参数用顶层 Constant 暴露给 `slrtExplorer` Parameters 页
- **Status:** implemented in Simulink with conservative defaults; field tuning pending

### PT-6: Superpowers Spec & Implementation Plan
- [x] 按 `brainstorming` workflow 将 PT-2 到 PT-5 设计整理成可审阅 spec
- [x] 用户确认 spec 后，按 `writing-plans` workflow 生成逐步实施计划
- [x] 实施计划必须采用 TDD：先写配置合同测试、辨识算法测试、位置环 harness 测试，再改模型生成器
- [x] 计划中必须明确每一步验证命令和期望结果
- [x] 把新增操作流程同步到 `SPEEDGOAT_V2_MINIMAL_LOGIC.md`、runbook 和 signal/reference 文档，保证操作员能按文档复现
- [x] 新增文件/函数的文档要求固定为：目的、输入输出、默认值、看哪里、怎么复现、何时停
- **Status:** complete

### PT-7: Simulink Implementation
- [x] 扩展配置层，增加位置给定、逆模型参数和 PID 参数
- [ ] 增加离线辨识脚本和测试数据 fixture
- [x] 增加位置环控制子系统或 Stateflow/Simulink 组合实现
- [x] 更新模型生成器连线，使位置环输出接入现有 `targetVelocity60FF`
- [x] 更新 `slrtExplorer` runbook 和信号参考文档
- **Status:** wiring complete; fixture-backed field tuning pending

### PT-8: Field Tuning & Acceptance Validation
- [x] 写出 PT-8 低速小位移位置环调参 runbook
- [x] 将 `position_command_6064` / `position_rate_command_6064` 的源改为 `slrtExplorer` 可调参数
- [ ] 用低速小位移验证方向、单位和零速保持
- [ ] 先只启用逆模型前馈，观察位置跟踪斜率是否正确
- [ ] 再启用小增益 P 控制，逐步加入 I/D 或滤波
- [ ] 验证阶跃、斜坡、三角波或实际目标位移曲线的跟踪误差
- [ ] 验收标准：`position_actual_6064` 与给定位置在允许误差内收敛，故障/未 ready 时输出速度归零
- **Status:** pending hardware validation

## Key Questions
1. `v2.0.0` 是否保留 `v1` 的 `config / model / host / tests` 分层与 helper 命名，还是进一步收敛成更小的“模型优先”框架？
2. CSV 循环控制基线应当以哪组 PDO 作为默认真源？已从用户处确认：`1702h Outputs + 1B04h Inputs`，且必须包含速度相关对象。
3. 如何做到“严格参照手册”，同时又不把 TwinCAT 配置脚本、旧 demo 模型和生成产物带进新目录？
4. 真机安全边界应如何落地到 host helper 和 runbook：哪些动作可自动执行，哪些动作必须显式人工触发？
5. `slrtExplorer` 与 MATLAB host helper 的职责边界应如何划分，才能既方便调试又避免重复控制链路？
6. 第一版 `slrtExplorer` 运行链的完成标准是什么：仅完成“加载并安全起机”，还是要直接支持速度给定变化与停机闭环？
7. 当总线未到 `OP` 或驱动状态异常时，模型应如何把“当前真实状态、查看位置、建议处理动作”反馈给操作者？
8. 模型暴露出来的报错编号、状态编号和对象值，应该指向哪本手册的哪一类章节去查物理含义？
9. 已确认：位置给定值继续按 6064 原始计数理解，当前单位合同按 `mm` 处理，后续如需工程单位再单独加转换层。
10. 现场允许的最大单次位移、最大速度、正负方向软限位分别是多少？
11. 已确认：`speed_command_60ff` 先按 `mm/s` 假设，`position_actual_6064` 先按 `mm` 处理，当前不再做额外单位辨识。
12. 逆模型应先按静态线性斜率实现，还是必须在首版就包含延迟/一阶速度响应补偿？
13. 已确认：位置 PID 的给定值采用外部轨迹输入，优先支持 `position_command` 和 `position_rate_command` 双输入。
14. 位置环启用方式应继续通过 `slrtExplorer` tunable 手工打开，还是默认在 ready 后自动闭环？
15. 是否需要加入软件位置限位，防止给定位置超出现场安全行程？

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| `speedgoat_v2.0.0` 作为新的项目根目录独立存在 | 用户明确要求新建完全独立文件夹，后续规划与实现都不再复用旧目录作为工作根 |
| 新目录初期只落 planning files，不先复制整套旧工程 | 当前仍处于 `brainstorming` / 设计关卡，先把约束、分解和风险写清楚，避免把旧包袱直接带进新目录 |
| `Speedgoat` 老目录只作为“排除项样本”，`speedgoat_v1.0.0` 只作为 clean-room 结构参考 | 老目录含 `demo_stable` 与 demo 生成产物；`v1` 已具备更干净的四层结构，适合作为结构参考但不是直接复制源 |
| 新目录中不引入 TwinCAT 相关内容和 `demo_stable` 内容 | 这是用户的明确边界，且有助于保持框架最干净、最利于扩展 |
| 手册是唯一需求源，手册蒸馏结果写入 planning/spec，而不是把整套含 TwinCAT 内容的资料复制进新目录 | 用户要求严格按照手册，但又要求新目录不带 TwinCAT 内容，因此应保留“手册驱动的结论”，不复制 TwinCAT 过程资产 |
| 版本基线锁定为 `MATLAB / Simulink R2021a` + `slrealtime.tlc` | `熠速实时仿真_实时模型.pdf` 明确在较早版本使用 `slrealtime.tlc`，且现有本地工程与 blockset 均围绕 R2021a |
| 固定步长必须显式锁定，且建议 `Fixed-step size >= 20e-6` | `熠速实时仿真_实时模型.pdf` 给出的直接约束，属于模型生成和实时执行的硬前提 |
| EtherCAT 初始化终态默认收敛到 `OP`，运行时期望网络态为 `8` | `熠速实时仿真_EtherCAT通讯.pdf` 明确 EtherCAT 状态必须按 `Init -> Pre-Op -> Safe-Op -> OP` 进入，`Get State` 正常运行值为 `8` |
| SV660N 基线控制模式收敛为 CSV，`6060/6061 = 9`，且只按 DC 同步模式设计 | `SV660N系列伺服通讯手册-CN-C00.PDF` 明确支持 CiA402，支持 CSV/CSP/CST 等模式；同时明确“仅支持 DC 同步模式”，面板模式 `9` 对应周期同步速度模式 |
| 基线 PDO 方案优先采用固定映射 `1702h Outputs + 1B04h Inputs` | 这组固定 PDO 同时覆盖循环速度控制和故障/状态观测所需的核心对象，最适合做单轴循环控制起步框架 |
| `slrtExplorer` 用于设备配置、应用加载、运行观察和日志调试；MATLAB helper 用于可脚本化、安全可复现的控制序列 | 这与 `熠速实时仿真_实时模型.pdf` 中对 Connected / Standalone / External 使用方式的划分一致 |
| 真机安全策略默认采用“零速起步、显式启动、显式清故障、不自动重试、不隐式运动” | 用户允许我下发真机指令，但要求“必须下发安全的指令”；因此计划阶段先把安全 envelope 作为一级约束锁定 |
| `v2.0.0` 的 PDO 基线采用 `1702h Outputs + 1B04h Inputs`，并且必须包含速度相关对象 | 用户已明确确认 PDO 由现有 ENI 固化为该组合，且不能退回到其他不含速度反馈的旧 PDO 变体 |
| 第一版 `v2.0.0` 先只搭模型和 `slrtExplorer` 运行链，不先铺 MATLAB helper | 用户刚刚明确确认这一版先聚焦模型和运行链，helper 延后能显著降低首版范围和复杂度 |
| ENI 文件视为只读输入，不允许在本次工作中修改 | 用户明确禁止修改 ENI；因此模型与框架只能消费已有 ENI 契约，不能通过改 ENI 来修正 PDO/SyncMan |
| Sync Manager 配置以现有 ENI 为准，其中当前关心的 PDO 通道是 `SyncMan 3` | 这是用户给出的现场事实，应作为模型连线与验证的既定前提，而不是实现时再改配置 |
| 路线选择收敛为路线 C | 用户明确要求按路线 C 推进，因此后续设计将先聚焦“手工搭最小 `.slx` 模型 + `slrtExplorer` 运行说明”，而不是先铺代码骨架或 helper |
| `slrtExplorer` 点击 `Start` 后允许模型自动完成上电和上使能，但速度指令仍由人工给定 | 这是用户刚确认的首版操作方式，说明自动化边界应止于安全起机，不延伸到自动运动 |
| 起机门禁必须带可操作的报错机制 | 用户明确要求：若总线未到 `OP` 或驱动状态不对，模型不仅要停止推进，还要返回真实状态、指出 `slrtExplorer` 查看位置并给出处理建议 |
| 诊断输出必须附带“去哪个手册查物理含义”的映射规则 | 用户明确要求报错编号不能只显示数字，还要能指导操作者去对应手册定位具体物理意义 |
| 位置跟踪首版继续沿用 CSV，不切换到 CSP | 用户描述的目标是“位置环输出给速度环”，且当前模型已经稳定打通 `60FFh` 速度给定与 `6064h` 位置反馈；切 CSP 会扩大范围并涉及 PDO/模式策略 |
| “速度和位置关系”按动态斜率关系辨识，而不是按静态位置-速度表处理 | 速度对应的是位置随时间变化率，核心关系应是 `d(position)/dt` 与速度命令/实际速度之间的比例、符号、偏置、延迟和饱和 |
| 先采集现场数据再实现逆模型 | 不能假设 `60FFh` 单位、机械传动比例、符号方向、死区和延迟已经正确；必须用 `position_actual_6064` 数据验证 |
| 初版逆模型作为速度前馈，位置 PID 作为误差修正 | 这样能保留可解释的线性模型，又让 PID 负责实际误差、摩擦、延迟和扰动补偿 |
| 所有位置环输出都必须经过现有 `ready_to_run` / 故障 / 模式门禁 | 位置环不能绕过已经完成的安全起机和诊断边界 |
| 最大速度和最大单次位移都要做成可调参数 | 用户明确要求“可调 + 保守默认值”，因此首版不把安全包络写死在逻辑里，而是写进配置层 |
| 保守默认值先用原始 6064 / 60FF 单位 | 当前工程还没确认位置工程单位与机械比例，先用原始对象单位最稳妥，后续再补单位换算层 |
| 新增功能必须同步操作流程到 `SPEEDGOAT_V2_MINIMAL_LOGIC.md` | 用户明确要求“操作流程也要同步”，因此文档本身应成为操作员和实现者共同的复现入口 |
| PT-2 先冻结配置字段命名，再做采集实现 | 没有清晰字段名，后续 config / tests / runbook 会各写各的，操作员和实现者都会混乱 |
| PT-2 保守默认值先定为 `200 / 1000 / 100 / 20` | 这组原始对象单位默认值足够保守，且已写入 AxisConfig / Tunables / 逻辑文档和参考表，方便现场按需调整 |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `session-catchup.py` 在 `D:\Temporary_file` 根目录未输出恢复摘要 | 1 | 改为手动扫描 `Speedgoat`、`speedgoat_v1.0.0`、本地 planning files 和三份 PDF，重建上下文 |
| 大范围全文搜索 `TwinCAT / demo_stable` 时 PowerShell 超时 | 1 | 改为先搜目录名，再聚焦 `Speedgoat\\matlab` 做结构化排查 |
| 首次 PDF 关键字抽取因 PowerShell 默认编码报 `UnicodeEncodeError` | 1 | 改为在 Python 中切到 UTF-8 输出，再重新抽取关键页内容 |
| `rg -n "... " matlab docs *.md` 在 PowerShell 下对 `*.md` 报路径语法错误 | 1 | 已从有效输出中提取本次需要的 MATLAB/docs 发现；后续搜索使用明确目录或 `rg --glob "*.md"` |
| `slrtExplorer` 仍看不到 position 参数 | 1 | 根因是加载的 `.mldatx` 仍是旧包；已重新 `slbuild` 并确认新 `matlab\speedgoat_v2_minimal.mldatx` 的 `paramInfo.json` 含 `SGV2_POSITION_COMMAND_6064` / `SGV2_POSITION_RATE_COMMAND_6064` |
| `slbuild` 首次恢复时报 PT-5 / StartupChart 代数环 | 1 | 在 `position_loop_speed_command_60ff` 到启动控制器输入之间加入一拍 `Unit Delay`，打断直接反馈环 |
| 聚合回归中 `slbuild` 走增量链接时报 `rtIsNaN` / `rt_InitInfAndNaN` 未定义 | 1 | 测试中先清理旧 `speedgoat_v2_minimal_slrealtime_rtw` 和 `.slxc`，强制走干净构建路径 |
| `build_speedgoat_v2_minimal` 在 `buildPositionLoopChart` 第 80 行报 chart codegen 失败 | 1 | 根因是 PT-5 子系统尚未完整接线时提前执行 `SimulationCommand update`；已把 update 挪到 `buildMinimalModel` 完成所有连线之后 |
| `slrtExplorer` 仍可能加载旧的 model-folder 应用包 | 1 | 新增 `build_speedgoat_v2_minimal_app`，同步生成 root 和 legacy 两份 `.mldatx`，并在打包后解包检查 position tunables |
| 交互式 MATLAB 中 `build_speedgoat_v2_minimal_app` 仍报 PT-5 chart codegen 失败 | 1 | 根因是现场 MATLAB path 不完整；已新增 `bootstrap_speedgoat_v2_path` 并让构建入口自动补齐 `config/control/model` 等源码目录 |

## Notes
- 本轮严格遵循 `using-superpowers + planning-with-files + brainstorming + writing-plans`，设计关卡已经结束，当前进入 implementation plan handoff。
- 用户已选定路线 C；实施阶段继续保持“最小模型优先、helper 后置、以 `slrtExplorer` 为主”的边界。
- 设计 1（首版范围）、设计 2（模型结构与诊断映射）、设计 3（`slrtExplorer` 操作链）、设计 4（自动上电/上使能状态机）和设计 5（信号面与参数面）已获得用户认可。
- 已写出设计文档：
  - `D:\Temporary_file\speedgoat_v2.0.0\docs\superpowers\specs\2026-04-19-speedgoat-v2-minimal-slrtExplorer-design.md`
- 已完成 spec self-review，并已按批准的 spec 写出 implementation plan：
  - `D:\Temporary_file\speedgoat_v2.0.0\docs\superpowers\plans\2026-04-19-speedgoat-v2-minimal-slrtExplorer.md`
- 已按 `subagent-driven-development` 完成 Task 1，并通过两级评审：
  - spec compliance: ✅
  - code quality: ✅ `Approved with minor notes`
- 已按 `subagent-driven-development` 完成 Task 2，并通过两级评审：
  - spec compliance: ✅
  - code quality: ✅ `Approved with minor notes`
- 已按 `subagent-driven-development` 完成 Task 3，并通过两级评审：
  - spec compliance: ✅
  - code quality: ✅ `Approved with minor notes`
- 已按 `subagent-driven-development` 完成 Task 4，并通过两级评审：
  - spec compliance: ✅
  - code quality: ✅ `Approved with minor notes`
- 已按 `subagent-driven-development` 完成 Task 5 修复与收口，并通过两级评审：
  - spec compliance: ✅ `PASS`
  - code quality: ✅ `approved`
- Task 5 现已完成 focused regression 执行、`.slx` 重建、本地 `slbuild` 产物生成和 pre-flight 证据采集；剩余仅保留 Phase 7 的现场硬件验证。
- `v2.0.0` 后续若进入实现，优先复用的是“结构和接口分层思想”，不是旧目录中的 demo 脚本、稳定版补丁或生成产物。
- 2026-05-09 新任务进入位置跟踪规划：当前只更新 planning files，不修改模型或下发运动命令。
- 后续如果进入实现，应先完成 Superpowers 的设计确认与 implementation plan，再按 TDD 改 MATLAB/Simulink 生成器。
- 2026-05-11：位置参数可见性问题已追到 `.mldatx` 包刷新层，新的 `matlab\speedgoat_v2_minimal.mldatx` 已重新生成并确认包含 `SGV2_POSITION_*`。
- 2026-05-11：PT-5 chart 更新时机已修正，`build_speedgoat_v2_minimal` 不再在半成品模型上提前触发 Stateflow codegen。
- 2026-05-11：应用包生成入口已统一到 `build_speedgoat_v2_minimal_app`，避免 `slrtExplorer` 继续误加载旧的 model-folder package。
- 2026-05-11：构建入口已加入 path bootstrap；操作员不再需要手动 `addpath(genpath(...))` 或 `savepath` 才能生成包含 PT-5 位置环的应用包。
