# Task Plan

## Active Task: 2026-04-19 `speedgoat_v2.0.0` clean-room 循环控制框架规划

## Goal
在 `D:\Temporary_file\speedgoat_v2.0.0` 内规划一套完全独立于旧 `Speedgoat` demo / `demo_stable` 路径的新工程，严格依据三份手册搭建 `Speedgoat + Simulink Real-Time + EtherCAT + SV660N` 的循环控制基础框架，并把设计、风险、阶段推进与安全策略持续落盘。

## Current Phase
Phase 7 pending hardware validation; Phases 3-5 complete

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

## Key Questions
1. `v2.0.0` 是否保留 `v1` 的 `config / model / host / tests` 分层与 helper 命名，还是进一步收敛成更小的“模型优先”框架？
2. CSV 循环控制基线应当以哪组 PDO 作为默认真源？已从用户处确认：`1702h Outputs + 1B04h Inputs`，且必须包含速度相关对象。
3. 如何做到“严格参照手册”，同时又不把 TwinCAT 配置脚本、旧 demo 模型和生成产物带进新目录？
4. 真机安全边界应如何落地到 host helper 和 runbook：哪些动作可自动执行，哪些动作必须显式人工触发？
5. `slrtExplorer` 与 MATLAB host helper 的职责边界应如何划分，才能既方便调试又避免重复控制链路？
6. 第一版 `slrtExplorer` 运行链的完成标准是什么：仅完成“加载并安全起机”，还是要直接支持速度给定变化与停机闭环？
7. 当总线未到 `OP` 或驱动状态异常时，模型应如何把“当前真实状态、查看位置、建议处理动作”反馈给操作者？
8. 模型暴露出来的报错编号、状态编号和对象值，应该指向哪本手册的哪一类章节去查物理含义？

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

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `session-catchup.py` 在 `D:\Temporary_file` 根目录未输出恢复摘要 | 1 | 改为手动扫描 `Speedgoat`、`speedgoat_v1.0.0`、本地 planning files 和三份 PDF，重建上下文 |
| 大范围全文搜索 `TwinCAT / demo_stable` 时 PowerShell 超时 | 1 | 改为先搜目录名，再聚焦 `Speedgoat\\matlab` 做结构化排查 |
| 首次 PDF 关键字抽取因 PowerShell 默认编码报 `UnicodeEncodeError` | 1 | 改为在 Python 中切到 UTF-8 输出，再重新抽取关键页内容 |

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
