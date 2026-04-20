# Speedgoat v2.0.0 Minimal slrtExplorer Design

## Goal

在 `D:\Temporary_file\speedgoat_v2.0.0` 中建立一个完全独立的、最小化的 Simulink Real-Time 单轴循环控制模型工程。该工程只聚焦：

- 基于现有只读 ENI 的 EtherCAT 主站接入
- SV660N 单轴 CSV 循环速度控制
- `slrtExplorer` 中的加载、启动、观测、人工给速、人工停机
- 自动上电和自动上使能
- 清晰的门禁诊断、手册映射和现场处理指引

本设计不覆盖 MATLAB helper、TwinCAT 工作流、`demo_stable` 迁移、多轴扩展或 ENI 修改。

## Scope

本设计覆盖：

- `MATLAB / Simulink R2021a`
- `slrealtime.tlc`
- 固定步长实时模型
- `slrtExplorer` 为主的目标机运行链
- 现有 ENI 中已经配置好的：
  - `1702h Outputs`
  - `1B04h Inputs`
  - `SyncMan 3`
- SV660N 的 CSV 模式起机与运行前门禁
- 首版运行信号、诊断信号与人工参数面
- 面向现场的 `slrtExplorer` runbook

本设计不覆盖：

- 修改、重导或重建 ENI
- TwinCAT 工程或 TwinCAT 导出流程
- `demo_stable` 任何内容迁入
- MATLAB helper：
  - `prepare`
  - `build`
  - `download`
  - `status`
  - `start`
  - `set_speed`
  - `stop`
  - `clear_fault`
- 多轴控制
- 自动给非零速度
- 自动故障恢复
- 完整代码化配置骨架与测试骨架

## Hard Constraints

### 1. ENI Is Read-Only

ENI 文件是现场既有配置的只读输入。`speedgoat_v2.0.0` 只能消费现有 ENI，不允许通过 Simulink、脚本或人工修改 ENI 来调整：

- PDO 选择
- Sync Manager
- 拓扑配置
- 从站映射

模型必须围绕现有 ENI 的既定事实搭建，而不是反向要求 ENI 配合模型修改。

### 2. PDO Contract Is Fixed

首版 PDO 契约固定为：

- `1702h Outputs`
- `1B04h Inputs`

并且必须保留速度相关对象。

因此首版模型至少围绕以下对象组织：

- 输出侧：
  - `6040h`
  - `60FFh`
  - `6060h`
  - `607Fh`
- 输入侧：
  - `603Fh`
  - `6041h`
  - `6061h`
  - `606Ch`

其他对象是否一并暴露，取决于 ENI 当前映射是否已经包含，但首版不围绕新增对象扩展模型复杂度。

### 3. Real-Time Model Must Follow the Manuals

根据 `熠速实时仿真_实时模型.pdf`，首版实时模型必须满足：

- Solver 使用 `Fixed-step`
- Code Generation 使用 `slrealtime.tlc`
- 固定步长建议满足 `Fixed-step size >= 20e-6`

根据 `熠速实时仿真_EtherCAT通讯.pdf`，首版 EtherCAT 模型必须满足：

- EtherCAT 状态推进遵循 `Init -> Pre-Op -> Safe-Op -> OP`
- 运行态通过 `EtherCAT Get State` 确认 `State = 8`
- `EtherCAT Init` 加载现有 ENI

根据 `SV660N系列伺服通讯手册-CN-C00.PDF`，首版驱动控制必须满足：

- 使用 `CiA402` 状态机语义
- 使用 CSV 模式
- 使用 DC 同步模式

## Architecture

首版模型采用最小 5 区块结构：

1. `EtherCAT Init`
2. `EtherCAT Get State`
3. `PDO Receive`
4. `Sequence Controller`
5. `PDO Transmit`

该结构只为“带诊断的自动起机到 ready-to-run + 人工给速度”服务。

### EtherCAT Init

职责：

- 加载现有 ENI
- 启动 EtherCAT 主站
- 使用与当前版本基线一致的实时模型配置

边界：

- 不修改 ENI
- 不在模型内重配 PDO
- 不引入 TwinCAT 或外部配置依赖

### EtherCAT Get State

职责：

- 输出当前真实 EtherCAT 网络状态
- 为门禁和诊断提供原始网络状态值

关键要求：

- 必须暴露真实状态，而不只输出“是否 OK”
- 必须能区分未到 `OP(8)` 时的真实值

### PDO Receive

职责：

- 从 `1B04h Inputs` 读取驱动反馈与观测量

首版至少消费：

- `603Fh` 错误码
- `6041h` 状态字
- `6061h` 模式显示
- `606Ch` 实际速度

### Sequence Controller

职责：

- 在 `slrtExplorer` 点击 `Start` 后自动推进安全起机链
- 在任意门禁失败时停止推进并输出诊断

自动推进只到：

- 总线到 `OP`
- 驱动无故障
- 自动上电
- 自动上使能
- 进入 `READY_TO_RUN`

自动推进明确不包含：

- 自动给非零速度
- 自动 fault reset
- 自动恢复

### PDO Transmit

职责：

- 向 `1702h Outputs` 写控制链对象

首版至少输出：

- `6040h`
- `60FFh`
- `6060h`
- `607Fh`

## Runtime Behavior

### Start Behavior

`slrtExplorer` 中点击 `Start` 后，模型自动进入以下状态链：

1. `WAIT_BUS_OP`
2. `WAIT_DRIVE_CLEAR`
3. `AUTO_POWER_ON`
4. `AUTO_ENABLE`
5. `READY_TO_RUN`

### WAIT_BUS_OP

条件：

- `actual_network_state == 8`

不满足时：

- 不推进到后续步骤
- 输出总线状态诊断
- `ready_to_run = 0`

### WAIT_DRIVE_CLEAR

条件：

- `603F == 0`
- `6041` 不在 fault / fault-reaction 相关状态

不满足时：

- 不推进到后续步骤
- 输出驱动状态诊断
- `ready_to_run = 0`

### AUTO_POWER_ON

职责：

- 自动执行符合 CiA402 语义的上电控制字推进

### AUTO_ENABLE

职责：

- 自动执行使能推进
- 目标是进入允许人工给速度的待运行状态

### READY_TO_RUN

标志：

- `ready_to_run = 1`

含义：

- 总线状态、驱动状态和自动起机链都已满足运行前提
- 此时允许人工写入速度指令

限制：

- 模型仍不自动给非零速度

## Safety Envelope

首版安全边界如下：

- 默认目标速度为 `0`
- `Start` 后只自动起机，不自动运动
- 只有在 `ready_to_run == 1` 时，人工速度给定才应生效
- 若出现以下任一情况，模型必须退出运行许可：
  - 总线掉出 `OP`
  - `603F != 0`
  - `6041` 进入故障相关状态
  - `6061` 不等于预期模式

在上述情况下：

- `ready_to_run` 必须回落为 `0`
- 继续运动推进必须被禁止
- 诊断输出必须立即更新

### Stop Strategy

首版停机策略保持简单明确：

- 人工把速度给定改回 `0`
- 人工点击 `Stop` 停止应用

首版不强求实现应用运行中自动 disable / automatic power-off 收尾，以保持最小模型复杂度和最清晰的现场可控性。

## Diagnostics

首版诊断不是“条件不满足就卡住”，而是必须形成三层可观测输出：

### Layer 1: Raw Values

- `actual_network_state`
- `expected_network_state`
- `statusword_6041`
- `error_code_603f`
- `mode_display_6061`
- `velocity_actual_606c`

### Layer 2: Runtime Diagnostics

- `diag_code`
- `diag_message_id`
- `ready_to_run`
- `auto_start_step`

### Layer 3: Manual Lookup Guidance

- `diag_lookup_group`
- `diag_lookup_hint`

### Diagnostic Intent

当总线未到 `OP` 时，诊断必须告诉操作者：

- 当前真实总线状态值
- 期望值是 `8`
- 去哪里查看
- 去哪本手册查状态机含义
- 先做什么处理

当驱动状态异常时，诊断必须告诉操作者：

- `6041` 当前值
- `603F` 当前值
- 去哪里查看
- 去哪本手册查
- 当前不允许给速度

## Manual Lookup Mapping

首版必须把“编号”与“资料出处”一起设计进去。

### EtherCAT State Lookup

对象：

- `actual_network_state`

资料指向：

- `熠速实时仿真_EtherCAT通讯.pdf`

查找主题：

- EtherCAT 状态机
- `EtherCAT Get State`
- `Init / Pre-Op / Safe-Op / OP`

### 6041h Lookup

对象：

- `statusword_6041`

资料指向：

- `SV660N系列伺服通讯手册-CN-C00.PDF`

查找主题：

- `6041h 状态字`
- CiA402 状态机
- 伺服状态说明

### 603Fh Lookup

对象：

- `error_code_603f`

资料指向：

- `SV660N系列伺服通讯手册-CN-C00.PDF`

查找主题：

- `603Fh 错误码`
- 故障/报警说明

### 6061h / 606Ch Lookup

对象：

- `mode_display_6061`
- `velocity_actual_606c`

资料指向：

- `SV660N系列伺服通讯手册-CN-C00.PDF`

查找主题：

- 对象字典章节
- 模式显示与实际速度章节

### Lookup Hint Form

`diag_lookup_hint` 使用短文本提示，直接给出人工查阅方向，例如：

- `Check EtherCAT manual: Get State / state machine`
- `Check SV660N manual: 6041h statusword / CiA402`
- `Check SV660N manual: 603Fh error code`

## slrtExplorer Workflow

首版 `slrtExplorer` 的推荐操作链固定为：

1. 连接目标机
2. 加载应用
3. 打开信号观察
4. 点击 `Start`
5. 确认 `ready_to_run == 1`
6. 人工给速度
7. 人工把速度降回 `0`
8. 人工点击 `Stop`

### Signals To Watch

在 `slrtExplorer` 中至少固定观察以下信号：

- `actual_network_state`
- `expected_network_state`
- `statusword_6041`
- `error_code_603f`
- `mode_display_6061`
- `velocity_actual_606c`
- `diag_code`
- `diag_message_id`
- `diag_lookup_group`
- `diag_lookup_hint`
- `ready_to_run`
- `auto_start_step`
- 人工速度给定量

### Failure Handling

#### Bus Not OP

若 `actual_network_state != 8`：

- 查看 `actual_network_state`
- 查看 `diag_lookup_hint`
- 在 `slrtExplorer` 信号观察区确认总线状态
- 查 `熠速实时仿真_EtherCAT通讯.pdf`
- 检查：
  - 目标机网口连接
  - 从站上电状态
  - ENI 与现场拓扑一致性
- 不允许继续给速度

#### Drive Error

若 `error_code_603f != 0`：

- 查看 `603F`
- 查 `SV660N系列伺服通讯手册-CN-C00.PDF`
- 先确认真实驱动故障原因
- 不允许继续给速度

#### Drive State Not Ready

若 `statusword_6041` 对应状态不满足自动推进：

- 查看 `6041`
- 查 `SV660N系列伺服通讯手册-CN-C00.PDF`
- 对照 CiA402 状态机判断卡住位置
- 不允许继续给速度

#### Start Stuck Without Clear Fault Code

若 `ready_to_run == 0` 但无明显 fault code：

- 查看 `auto_start_step`
- 查看 `diag_code`
- 查看 `diag_message_id`
- 判断是卡在总线检查、上电、使能还是模式确认

## Signals And Parameters

### Runtime Signals

- `actual_network_state`
- `expected_network_state`
- `statusword_6041`
- `mode_display_6061`
- `velocity_actual_606c`
- `ready_to_run`
- `auto_start_step`

### Diagnostic Signals

- `diag_code`
- `diag_message_id`
- `diag_lookup_group`
- `diag_lookup_hint`
- `error_code_603f`

### Manual Parameters

首版人工可调参数尽量压到最少，仅保留：

- `speed_command_60ff`
- 可选保守限幅：`speed_limit_607f`

### Default Values

- `speed_command_60ff = 0`
- `ready_to_run = 0`
- `expected_network_state = 8`
- 预期模式固定为 CSV
- `speed_limit_607f` 使用保守默认值

## Deliverables

首版交付物固定为 4 件：

1. 一个最小 `.slx` 实时模型
2. 一个 `slrtExplorer` 运行 runbook
3. 一个信号/参数对照表
4. 一个首版边界说明

### 1. Minimal `.slx` Model

必须包含：

- `EtherCAT Init`
- `EtherCAT Get State`
- `1702h Outputs`
- `1B04h Inputs`
- 自动上电/上使能控制逻辑
- 诊断输出
- 人工速度给定入口

### 2. slrtExplorer Runbook

必须写清楚：

- 如何连接目标机
- 如何加载应用
- 如何点击 `Start`
- 查看哪些信号
- 何时允许给速度
- 失败时去哪里看
- 去哪本手册查编号含义
- 如何安全停机

### 3. Signal/Parameter Reference

必须列清楚：

- 信号名
- 含义
- 来源对象
- 在 `slrtExplorer` 中怎么看
- 出错时该查哪本手册

### 4. Boundary Statement

必须明确写出：

- 不改 ENI
- 不做 MATLAB helper
- 不做 TwinCAT
- 不带 `demo_stable`
- 只支持单轴 CSV
- 只支持 `1702h + 1B04h`
- 自动起机到 ready
- 人工给速度

## Out Of Scope Follow-Ups

以下能力允许在后续版本扩展，但不进入首版：

- 代码化配置骨架
- MATLAB helper
- 自动 fault reset
- 更完整的测试体系
- 多轴支持
- 更复杂的停机收尾

## Design Summary

本设计将 `speedgoat_v2.0.0` 首版明确限定为：

- 一个完全独立的新目录
- 一个围绕现有 ENI 的最小实时模型
- 一个基于 `slrtExplorer` 的可操作运行链
- 一个安全的“自动起机到 ready + 人工给速度”流程
- 一个把运行值、诊断值和手册映射真正打通的现场可诊断系统

这样可以在不引入旧 demo 包袱、不改 ENI、不铺大规模代码框架的前提下，把最核心的现场闭环先稳定建立起来。
