# Speedgoat v2 Minimal slrtExplorer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a clean-room `speedgoat_v2.0.0` MATLAB/Simulink project that generates one minimal Simulink Real-Time single-axis CSV model, exposes the approved `slrtExplorer` signal/parameter surface, and ships the field runbook/reference docs without bringing in `demo_stable`, TwinCAT assets, or MATLAB host helpers.

**Architecture:** Keep the project lean and generator-driven: a small `matlab/config` contract owns ENI/PDO/runtime defaults, `matlab/model` programmatically builds the `.slx` around `EtherCAT Init -> EtherCAT Get State -> PDO Receive -> Sequence Controller -> PDO Transmit`, and `docs/` carries the operator-facing runbook/reference set. The sequence controller is built as a programmatic Stateflow chart inside a generated subsystem so the real-time model stays codegen-safe on `slrealtime.tlc`, while focused MATLAB tests lock the config, generated model surface, controller diagnostics, and docs contracts.

**Tech Stack:** MATLAB R2021a, Simulink, Stateflow, Simulink Real-Time (`slrealtime.tlc`), Speedgoat EtherCAT blocks, MATLAB `functiontests`.

---

**Repository note:** This workspace is not git-backed. Replace the usual “commit” checkpoints with planning-file updates in `task_plan.md`, `findings.md`, and `progress.md`.

**MATLAB note:** Every MATLAB command block below assumes:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
addpath(genpath(pwd));
```

## File Structure

### Create

- `matlab/config/project_defaults.m`
  Project-local directory, naming, and sample-time defaults for `speedgoat_v2.0.0`.
- `matlab/config/axes/sv660n_axis1.m`
  Single-axis commissioning defaults, including safe startup tunables.
- `matlab/config/ethercat/sv660n_eni_contract.m`
  Read-only ENI contract and EtherCAT runtime expectations for the existing `1702h + 1B04h` mapping.
- `matlab/config/ethercat/sv660n_pdo_map.m`
  Minimal PDO map exposing only the first-version objects the spec approved.
- `matlab/config/target_minimal_slrtexplorer.m`
  Aggregated target contract used by builders and tests.
- `matlab/model/build_speedgoat_v2_minimal.m`
  Entry point that generates the minimal `.slx`.
- `matlab/model/+sgv2/controlword.m`
  CiA402 controlword constants used by the controller chart.
- `matlab/model/+sgv2/statusState.m`
  `6041h` decoder for controller logic and tests.
- `matlab/model/+sgv2/+internal/buildMinimalModel.m`
  Top-level generator for solver/codegen settings and block wiring.
- `matlab/model/+sgv2/+internal/addEthercatIo.m`
  EtherCAT Init/Get State/PDO block creation.
- `matlab/model/+sgv2/+internal/addManualCommandInterface.m`
  Tunable `speed_command_60ff`, `speed_limit_607f`, and `expected_network_state` sources.
- `matlab/model/+sgv2/+internal/addSequenceController.m`
  Programmatic sequence-controller subsystem wrapper.
- `matlab/model/+sgv2/+internal/buildStartupChart.m`
  Programmatic Stateflow chart for bus gating, auto power-on, auto enable, and diagnostics.
- `matlab/model/+sgv2/+internal/addObservabilityPorts.m`
  Root Outport surface for raw values, diagnostics, and manual command echo.
- `matlab/model/+sgv2/+internal/buildFrameworkHarness.m`
  Small harness model for deterministic controller tests.
- `matlab/model/+sgv2/+internal/diagCodes.m`
  Shared runtime diagnostic codes.
- `matlab/model/+sgv2/+internal/diagMessageIds.m`
  Shared diagnostic message identifiers.
- `matlab/model/+sgv2/+internal/diagLookupGroups.m`
  Shared lookup-group identifiers.
- `matlab/model/+sgv2/+internal/autoStartStepIds.m`
  Shared `WAIT_BUS_OP -> READY_TO_RUN` step identifiers.
- `matlab/tests/test_targetConfig.m`
  Config-contract tests.
- `matlab/tests/test_modelGeneration.m`
  Generated-model surface and block-parameter tests.
- `matlab/tests/test_sequenceHarness.m`
  Controller harness tests for the approved startup/diagnostic cases.
- `matlab/tests/test_documentContracts.m`
  Lightweight docs-contract tests.
- `docs/field_validation/speedgoat_v2_minimal.md`
  `slrtExplorer` runbook.
- `docs/reference/speedgoat_v2_signal_parameter_reference.md`
  Signal/parameter reference table.
- `docs/reference/speedgoat_v2_boundary_statement.md`
  First-version boundary statement.

## Task 1: Create the Clean-Room Config Contract

**Files:**
- Create: `matlab/config/project_defaults.m`
- Create: `matlab/config/axes/sv660n_axis1.m`
- Create: `matlab/config/ethercat/sv660n_eni_contract.m`
- Create: `matlab/config/ethercat/sv660n_pdo_map.m`
- Create: `matlab/config/target_minimal_slrtexplorer.m`
- Create: `matlab/tests/test_targetConfig.m`

- [ ] **Step 1: Write the failing config-contract test**

Create `matlab/tests/test_targetConfig.m` with:

```matlab
function tests = test_targetConfig
tests = functiontests(localfunctions);
end

function testTargetContractMatchesApprovedSpec(testCase)
target = target_minimal_slrtexplorer();

verifyEqual(testCase, target.ModelName, "speedgoat_v2_minimal");
verifyEqual(testCase, target.ApplicationName, "speedgoat_v2_minimal");
verifyEqual(testCase, target.SampleTime, 0.002);
verifyEqual(testCase, target.Ethercat.InitStateValue, "2");
verifyEqual(testCase, target.Ethercat.ExpectedNetworkState, int32(8));
verifyEqual(testCase, target.Ethercat.ExpectedModeOfOperation, int8(9));
verifyEqual(testCase, target.Tunables.SpeedCommand60FF, "SGV2_SPEED_COMMAND_60FF");
verifyEqual(testCase, target.Tunables.SpeedLimit607F, "SGV2_SPEED_LIMIT_607F");
verifyEqual(testCase, {target.PdoMap.Tx.Key}, ...
    {"controlword6040", "targetVelocity60FF", "modeOfOperation6060", "maxProfileVelocity607F"});
verifyEqual(testCase, {target.PdoMap.Rx.Key}, ...
    {"errorCode603F", "statusword6041", "modeDisplay6061", "velocityActual606C"});
end
```

- [ ] **Step 2: Run the config test to confirm it fails**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = runtests('tests/test_targetConfig.m');
disp(results([results.Passed] == 0));
```

Expected: failure because `target_minimal_slrtexplorer` and the config files do not exist yet.

- [ ] **Step 3: Implement the v2 config files**

Create `matlab/config/project_defaults.m`:

```matlab
function defaults = project_defaults()
configDir = fileparts(mfilename('fullpath'));
matlabRoot = fileparts(configDir);
projectRoot = fileparts(matlabRoot);

defaults = struct( ...
    'ProjectName', "speedgoat_v2.0.0", ...
    'ProjectRoot', string(projectRoot), ...
    'MatlabRoot', string(matlabRoot), ...
    'ConfigRoot', string(configDir), ...
    'ModelRoot', string(fullfile(matlabRoot, 'model')), ...
    'ModelDir', string(fullfile(matlabRoot, 'model', 'models')), ...
    'DocsRoot', string(fullfile(projectRoot, 'docs')), ...
    'CommandPrefix', "SGV2", ...
    'DefaultModelName', "speedgoat_v2_minimal", ...
    'DefaultApplicationName', "speedgoat_v2_minimal", ...
    'HarnessModelName', "speedgoat_v2_sequence_harness", ...
    'SampleTime', 0.002);
end
```

Create `matlab/config/axes/sv660n_axis1.m`:

```matlab
function axisCfg = sv660n_axis1()
axisCfg = struct( ...
    'AxisKey', "axis1", ...
    'DriveType', "SV660N", ...
    'SlaveName', "Drive 1 (InoSV660N)", ...
    'EthercatDeviceIndex', 0, ...
    'EthernetPortNumber', 1, ...
    'DefaultSafeVelocity60FF', int32(0), ...
    'DefaultMaxProfileVelocity607F', uint32(1000), ...
    'ExpectedModeOfOperation', int8(9));
end
```

Create `matlab/config/ethercat/sv660n_eni_contract.m`:

```matlab
function ethercatCfg = sv660n_eni_contract(axisCfg, sampleTime, configRoot)
ethercatCfg = struct( ...
    'EniFile', string(fullfile(configRoot, 'ethercat', 'eni', 'ENI2.xml')), ...
    'DeviceIndex', axisCfg.EthercatDeviceIndex, ...
    'PortNumber', axisCfg.EthernetPortNumber, ...
    'InitStateValue', "2", ...
    'ExpectedNetworkState', int32(8), ...
    'EnableDC', true, ...
    'DCModeValue', "2", ...
    'DCTuningValue', "0", ...
    'ExpectedModeOfOperation', axisCfg.ExpectedModeOfOperation, ...
    'SampleTime', sampleTime);
end
```

Create `matlab/config/ethercat/sv660n_pdo_map.m`:

```matlab
function pdoMap = sv660n_pdo_map()
slave = "Drive 1 (InoSV660N)";
pdoMap = struct( ...
    'Rx', [ ...
        localPdo("errorCode603F", "Rx Error code 603F", slave + ".Inputs.Error code", 568, "uint16", 16) ...
        localPdo("statusword6041", "Rx Statusword 6041", slave + ".Inputs.Statusword", 584, "uint16", 16) ...
        localPdo("modeDisplay6061", "Rx Mode display 6061", slave + ".Inputs.Modes of operation display", 648, "int8", 8) ...
        localPdo("velocityActual606C", "Rx Velocity actual 606C", slave + ".Inputs.Velocity actual value", 768, "int32", 32)], ...
    'Tx', [ ...
        localPdo("controlword6040", "Tx Controlword 6040", slave + ".Outputs.Controlword", 568, "uint16", 16) ...
        localPdo("targetVelocity60FF", "Tx Target velocity 60FF", slave + ".Outputs.Target velocity", 616, "int32", 32) ...
        localPdo("modeOfOperation6060", "Tx Modes of operation 6060", slave + ".Outputs.Modes of operation", 664, "int8", 8) ...
        localPdo("maxProfileVelocity607F", "Tx Max profile velocity 607F", slave + ".Outputs.Max profile velocity", 688, "uint32", 32)]);
end

function sig = localPdo(key, blockName, signalName, offset, dataType, typeSize)
sig = struct( ...
    'Key', string(key), ...
    'BlockName', string(blockName), ...
    'SignalName', string(signalName), ...
    'Offset', offset, ...
    'DataType', string(dataType), ...
    'TypeSize', typeSize);
end
```

Create `matlab/config/target_minimal_slrtexplorer.m`:

```matlab
function target = target_minimal_slrtexplorer()
defaults = project_defaults();
axisCfg = sv660n_axis1();
ethercatCfg = sv660n_eni_contract(axisCfg, defaults.SampleTime, defaults.ConfigRoot);
pdoMap = sv660n_pdo_map();

target = struct( ...
    'TargetName', "Minimal slrtExplorer", ...
    'ModelName', defaults.DefaultModelName, ...
    'ApplicationName', defaults.DefaultApplicationName, ...
    'GeneratedModelFile', fullfile(defaults.ModelDir, defaults.DefaultModelName + ".slx"), ...
    'EniFile', ethercatCfg.EniFile, ...
    'SampleTime', defaults.SampleTime, ...
    'AxisConfig', axisCfg, ...
    'Ethercat', ethercatCfg, ...
    'PdoMap', pdoMap, ...
    'Tunables', struct( ...
        'SpeedCommand60FF', "SGV2_SPEED_COMMAND_60FF", ...
        'SpeedLimit607F', "SGV2_SPEED_LIMIT_607F"), ...
    'Signals', struct( ...
        'ActualNetworkState', "actual_network_state", ...
        'ExpectedNetworkState', "expected_network_state", ...
        'Statusword6041', "statusword_6041", ...
        'ErrorCode603F', "error_code_603f", ...
        'ModeDisplay6061', "mode_display_6061", ...
        'VelocityActual606C', "velocity_actual_606c", ...
        'DiagCode', "diag_code", ...
        'DiagMessageId', "diag_message_id", ...
        'DiagLookupGroup', "diag_lookup_group", ...
        'DiagLookupHint', "diag_lookup_hint", ...
        'ReadyToRun', "ready_to_run", ...
        'AutoStartStep', "auto_start_step", ...
        'SpeedCommand60FF', "speed_command_60ff"));
end
```

- [ ] **Step 4: Re-run the config test**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = runtests('tests/test_targetConfig.m');
assert(all([results.Passed]), 'Expected config-contract tests to pass.');
```

Expected: `tests/test_targetConfig.m` passes and locks the clean-room config surface.

- [ ] **Step 5: Checkpoint the planning files**

Update:

- `task_plan.md` with Task 1 completed
- `findings.md` with the final `1702h + 1B04h` offsets and config defaults
- `progress.md` with the exact test command and result

## Task 2: Generate the Minimal Real-Time Model Shell

**Files:**
- Create: `matlab/model/build_speedgoat_v2_minimal.m`
- Create: `matlab/model/+sgv2/+internal/buildMinimalModel.m`
- Create: `matlab/model/+sgv2/+internal/addEthercatIo.m`
- Create: `matlab/model/+sgv2/+internal/addManualCommandInterface.m`
- Create: `matlab/model/+sgv2/+internal/addSequenceController.m`
- Create: `matlab/model/+sgv2/+internal/addObservabilityPorts.m`
- Create: `matlab/tests/test_modelGeneration.m`

- [ ] **Step 1: Write the failing model-generation test**

Create `matlab/tests/test_modelGeneration.m` with:

```matlab
function tests = test_modelGeneration
tests = functiontests(localfunctions);
end

function testGeneratedModelContainsApprovedShell(testCase)
modelPath = build_speedgoat_v2_minimal();
target = target_minimal_slrtexplorer();

load_system(modelPath);
modelName = char(target.ModelName);

verifyEqual(testCase, get_param(modelName, 'SystemTargetFile'), 'slrealtime.tlc');
verifyEqual(testCase, get_param(modelName, 'FixedStep'), num2str(target.SampleTime));
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/EtherCAT Init']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/EtherCAT Get State']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/SV660N Sequence Controller']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/speed_command_60ff']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/speed_limit_607f']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/diag_lookup_hint']) > 0);
end
```

- [ ] **Step 2: Run the test to confirm it fails**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = runtests('tests/test_modelGeneration.m');
disp(results([results.Passed] == 0));
```

Expected: failure because the build entry point and model builder do not exist yet.

- [ ] **Step 3: Implement the generator and model shell**

Create `matlab/model/build_speedgoat_v2_minimal.m`:

```matlab
function modelPath = build_speedgoat_v2_minimal()
modelPath = sgv2.internal.buildMinimalModel(target_minimal_slrtexplorer());
end
```

Create `matlab/model/+sgv2/+internal/buildMinimalModel.m`:

```matlab
function modelPath = buildMinimalModel(target)
outputDir = fileparts(target.GeneratedModelFile);
finalModelPath = char(target.GeneratedModelFile);

if ~isfolder(outputDir)
    mkdir(outputDir);
end

if bdIsLoaded(target.ModelName)
    set_param(target.ModelName, 'Dirty', 'off');
    close_system(target.ModelName, 0);
end

load_system('simulink');
load_system('sflib');
load_system('slrealtimeethercatlib');

new_system(target.ModelName);
set_param(target.ModelName, ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', num2str(target.SampleTime), ...
    'StopTime', 'inf', ...
    'SimulationMode', 'external', ...
    'DefaultParameterBehavior', 'Tunable', ...
    'SystemTargetFile', 'slrealtime.tlc');

[controllerBlock, getStateBlock, rxBlocks, txBlocks] = sgv2.internal.addEthercatIo(target);
commandBlocks = sgv2.internal.addManualCommandInterface(target, controllerBlock);
sgv2.internal.addObservabilityPorts(target, controllerBlock, getStateBlock, rxBlocks, txBlocks, commandBlocks);

save_system(target.ModelName, finalModelPath);
set_param(target.ModelName, 'Dirty', 'off');
close_system(target.ModelName, 0);
modelPath = string(finalModelPath);
end
```

Create `matlab/model/+sgv2/+internal/addEthercatIo.m`:

```matlab
function [controllerBlock, getStateBlock, rxBlocks, txBlocks] = addEthercatIo(target)
modelName = char(target.ModelName);
ethercatCfg = target.Ethercat;

initBlock = [modelName '/EtherCAT Init'];
add_block('slrealtimeethercatlib/EtherCAT Init', initBlock, 'Position', [40 40 260 95]);
set_param(initBlock, ...
    'config_file', char(target.EniFile), ...
    'device_id', num2str(ethercatCfg.DeviceIndex), ...
    'portnum', num2str(ethercatCfg.PortNumber), ...
    'initstate', char(ethercatCfg.InitStateValue), ...
    'dctuning', char(ethercatCfg.DCTuningValue), ...
    'enaDC', 'on', ...
    'DCMode', char(ethercatCfg.DCModeValue), ...
    'sample_time', num2str(ethercatCfg.SampleTime));

getStateBlock = [modelName '/EtherCAT Get State'];
add_block('slrealtimeethercatlib/EtherCAT Get State', getStateBlock, 'Position', [40 140 260 185]);
set_param(getStateBlock, ...
    'device_id', num2str(ethercatCfg.DeviceIndex), ...
    'sample_time', num2str(ethercatCfg.SampleTime));

rxBlocks = struct();
for k = 1:numel(target.PdoMap.Rx)
    sig = target.PdoMap.Rx(k);
    block = [modelName '/' char(sig.BlockName)];
    add_block('slrealtimeethercatlib/EtherCAT PDO Receive', block, ...
        'Position', [40 230 + (k - 1) * 55 330 265 + (k - 1) * 55]);
    set_param(block, ...
        'sig_name', char(sig.SignalName), ...
        'sig_offset', num2str(sig.Offset), ...
        'sig_type', char(sig.DataType), ...
        'type_size', num2str(sig.TypeSize), ...
        'sig_dim', '1', ...
        'device_id', num2str(ethercatCfg.DeviceIndex), ...
        'sample_time', num2str(ethercatCfg.SampleTime));
    rxBlocks.(char(sig.Key)) = block;
end

controllerBlock = sgv2.internal.addSequenceController(target);

add_line(modelName, [get_param(getStateBlock, 'Name') '/1'], [get_param(controllerBlock, 'Name') '/1'], 'autorouting', 'on');
add_line(modelName, [get_param(rxBlocks.statusword6041, 'Name') '/1'], [get_param(controllerBlock, 'Name') '/3'], 'autorouting', 'on');
add_line(modelName, [get_param(rxBlocks.errorCode603F, 'Name') '/1'], [get_param(controllerBlock, 'Name') '/4'], 'autorouting', 'on');
add_line(modelName, [get_param(rxBlocks.modeDisplay6061, 'Name') '/1'], [get_param(controllerBlock, 'Name') '/5'], 'autorouting', 'on');
add_line(modelName, [get_param(rxBlocks.velocityActual606C, 'Name') '/1'], [get_param(controllerBlock, 'Name') '/6'], 'autorouting', 'on');

txBlocks = struct();
for k = 1:numel(target.PdoMap.Tx)
    sig = target.PdoMap.Tx(k);
    block = [modelName '/' char(sig.BlockName)];
    add_block('slrealtimeethercatlib/EtherCAT PDO Transmit', block, ...
        'Position', [960 180 + (k - 1) * 55 1250 215 + (k - 1) * 55]);
    set_param(block, ...
        'sig_name', char(sig.SignalName), ...
        'sig_offset', num2str(sig.Offset), ...
        'sig_type', char(sig.DataType), ...
        'type_size', num2str(sig.TypeSize), ...
        'sig_dim', '1', ...
        'device_id', num2str(ethercatCfg.DeviceIndex), ...
        'sample_time', num2str(ethercatCfg.SampleTime));
    txBlocks.(char(sig.Key)) = block;
end

add_line(modelName, [get_param(controllerBlock, 'Name') '/1'], [get_param(txBlocks.controlword6040, 'Name') '/1'], 'autorouting', 'on');
add_line(modelName, [get_param(controllerBlock, 'Name') '/2'], [get_param(txBlocks.targetVelocity60FF, 'Name') '/1'], 'autorouting', 'on');
add_line(modelName, [get_param(controllerBlock, 'Name') '/3'], [get_param(txBlocks.modeOfOperation6060, 'Name') '/1'], 'autorouting', 'on');
add_line(modelName, [get_param(controllerBlock, 'Name') '/4'], [get_param(txBlocks.maxProfileVelocity607F, 'Name') '/1'], 'autorouting', 'on');
end
```

Create `matlab/model/+sgv2/+internal/addManualCommandInterface.m`:

```matlab
function commandBlocks = addManualCommandInterface(target, controllerBlock)
modelName = char(target.ModelName);

items = { ...
    'expected_network_state', sprintf('int32(%d)', target.Ethercat.ExpectedNetworkState), [360 45 520 75], 2; ...
    'speed_command_60ff', target.Tunables.SpeedCommand60FF, [360 90 520 120], 7; ...
    'speed_limit_607f', target.Tunables.SpeedLimit607F, [360 135 520 165], 8};

for k = 1:size(items, 1)
    blockPath = [modelName '/' items{k, 1}];
    add_block('simulink/Sources/Constant', blockPath, ...
        'Position', items{k, 3}, ...
        'Value', char(items{k, 2}));
    add_line(modelName, [items{k, 1} '/1'], [get_param(controllerBlock, 'Name') '/' num2str(items{k, 4})], 'autorouting', 'on');
    commandBlocks.(matlab.lang.makeValidName(items{k, 1})) = blockPath;
end
end
```

Create `matlab/model/+sgv2/+internal/addSequenceController.m`:

```matlab
function controllerBlock = addSequenceController(target)
modelName = char(target.ModelName);
controllerBlock = [modelName '/SV660N Sequence Controller'];
add_block('simulink/Ports & Subsystems/Subsystem', controllerBlock, ...
    'Position', [560 170 900 520]);

inNames = { ...
    'actual_network_state', ...
    'expected_network_state', ...
    'statusword_6041', ...
    'error_code_603f', ...
    'mode_display_6061', ...
    'velocity_actual_606c', ...
    'speed_command_60ff', ...
    'speed_limit_607f'};

outNames = { ...
    'controlword_6040', ...
    'velocity_command_60ff', ...
    'mode_command_6060', ...
    'speed_limit_out_607f', ...
    'ready_to_run', ...
    'auto_start_step', ...
    'diag_code', ...
    'diag_message_id', ...
    'diag_lookup_group', ...
    'diag_lookup_hint'};

for k = 1:numel(inNames)
    add_block('simulink/Sources/In1', [controllerBlock '/' inNames{k}], ...
        'Position', [30 25 + (k - 1) * 40 60 39 + (k - 1) * 40]);
end

for k = 1:numel(outNames)
    add_block('simulink/Sinks/Out1', [controllerBlock '/' outNames{k}], ...
        'Position', [260 25 + (k - 1) * 35 290 39 + (k - 1) * 35]);
    add_block('simulink/Sources/Constant', [controllerBlock '/seed_' outNames{k}], ...
        'Position', [120 20 + (k - 1) * 35 170 40 + (k - 1) * 35], ...
        'Value', '0');
    add_line(controllerBlock, ['seed_' outNames{k} '/1'], [outNames{k} '/1']);
end
end
```

Create `matlab/model/+sgv2/+internal/addObservabilityPorts.m`:

```matlab
function addObservabilityPorts(target, controllerBlock, getStateBlock, rxBlocks, txBlocks, commandBlocks)
modelName = char(target.ModelName);
signals = { ...
    target.Signals.ActualNetworkState, getStateBlock, 1; ...
    target.Signals.ExpectedNetworkState, commandBlocks.expected_network_state, 1; ...
    target.Signals.Statusword6041, rxBlocks.statusword6041, 1; ...
    target.Signals.ErrorCode603F, rxBlocks.errorCode603F, 1; ...
    target.Signals.ModeDisplay6061, rxBlocks.modeDisplay6061, 1; ...
    target.Signals.VelocityActual606C, rxBlocks.velocityActual606C, 1; ...
    target.Signals.DiagCode, controllerBlock, 7; ...
    target.Signals.DiagMessageId, controllerBlock, 8; ...
    target.Signals.DiagLookupGroup, controllerBlock, 9; ...
    target.Signals.DiagLookupHint, controllerBlock, 10; ...
    target.Signals.ReadyToRun, controllerBlock, 5; ...
    target.Signals.AutoStartStep, controllerBlock, 6; ...
    target.Signals.SpeedCommand60FF, commandBlocks.speed_command_60ff, 1};

for k = 1:size(signals, 1)
    add_block('simulink/Sinks/Out1', [modelName '/' char(signals{k, 1})], ...
        'Position', [1320 40 + (k - 1) * 35 1350 54 + (k - 1) * 35]);
    add_line(modelName, [get_param(signals{k, 2}, 'Name') '/' num2str(signals{k, 3})], ...
        [char(signals{k, 1}) '/1'], 'autorouting', 'on');
end
end
```

- [ ] **Step 4: Re-run model-generation tests**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = runtests('tests/test_modelGeneration.m');
assert(all([results.Passed]), 'Expected model-generation tests to pass.');
```

Expected: the generated model shell exists, uses `slrealtime.tlc`, and already exposes the approved top-level block surface.

- [ ] **Step 5: Checkpoint the planning files**

Update:

- `task_plan.md` with Task 2 completed
- `findings.md` with the generated-shell boundaries
- `progress.md` with the test command and generated model path

## Task 3: Implement the Startup Sequence and Diagnostics

**Files:**
- Create: `matlab/model/+sgv2/controlword.m`
- Create: `matlab/model/+sgv2/statusState.m`
- Create: `matlab/model/+sgv2/+internal/diagCodes.m`
- Create: `matlab/model/+sgv2/+internal/diagMessageIds.m`
- Create: `matlab/model/+sgv2/+internal/diagLookupGroups.m`
- Create: `matlab/model/+sgv2/+internal/autoStartStepIds.m`
- Create: `matlab/model/+sgv2/+internal/buildStartupChart.m`
- Create: `matlab/model/+sgv2/+internal/buildFrameworkHarness.m`
- Modify: `matlab/model/+sgv2/+internal/addSequenceController.m`
- Create: `matlab/tests/test_sequenceHarness.m`

- [ ] **Step 1: Write the failing harness tests**

Create `matlab/tests/test_sequenceHarness.m` with:

```matlab
function tests = test_sequenceHarness
tests = functiontests(localfunctions);
end

function testBusNotOperationalBlocksStartup(testCase)
modelName = sgv2.internal.buildFrameworkHarness();
in = Simulink.SimulationInput(modelName);
in = in.setVariable('network_state_ts', timeseries(int32([1 1]), [0 0.05]));
in = in.setVariable('statusword_ts', timeseries(uint16([hex2dec('0040') hex2dec('0040')]), [0 0.05]));
in = in.setVariable('error_code_ts', timeseries(uint16([0 0]), [0 0.05]));
in = in.setVariable('mode_display_ts', timeseries(int8([9 9]), [0 0.05]));
in = in.setVariable('velocity_actual_ts', timeseries(int32([0 0]), [0 0.05]));
in = in.setVariable('speed_command_ts', timeseries(int32([120 120]), [0 0.05]));
in = in.setVariable('speed_limit_ts', timeseries(uint32([1000 1000]), [0 0.05]));
out = sim(in);

verifyEqual(testCase, out.logsout.get('ready_to_run').Values.Data(end), uint8(0));
verifyEqual(testCase, out.logsout.get('auto_start_step').Values.Data(end), ...
    sgv2.internal.autoStartStepIds().WAIT_BUS_OP);
verifyEqual(testCase, out.logsout.get('diag_code').Values.Data(end), ...
    sgv2.internal.diagCodes().BUS_NOT_OP);
end

function testReadyStateAllowsManualSpeed(testCase)
modelName = sgv2.internal.buildFrameworkHarness();
in = Simulink.SimulationInput(modelName);
in = in.setVariable('network_state_ts', timeseries(int32([8 8]), [0 0.05]));
in = in.setVariable('statusword_ts', timeseries(uint16([hex2dec('0027') hex2dec('0027')]), [0 0.05]));
in = in.setVariable('error_code_ts', timeseries(uint16([0 0]), [0 0.05]));
in = in.setVariable('mode_display_ts', timeseries(int8([9 9]), [0 0.05]));
in = in.setVariable('velocity_actual_ts', timeseries(int32([0 0]), [0 0.05]));
in = in.setVariable('speed_command_ts', timeseries(int32([120 120]), [0 0.05]));
in = in.setVariable('speed_limit_ts', timeseries(uint32([1000 1000]), [0 0.05]));
out = sim(in);

verifyEqual(testCase, out.logsout.get('ready_to_run').Values.Data(end), uint8(1));
verifyEqual(testCase, out.logsout.get('velocity_command_60ff').Values.Data(end), int32(120));
verifyEqual(testCase, out.logsout.get('diag_code').Values.Data(end), sgv2.internal.diagCodes().NONE);
end
```

- [ ] **Step 2: Run the harness tests to confirm they fail**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = runtests('tests/test_sequenceHarness.m');
disp(results([results.Passed] == 0));
```

Expected: failure because the harness and controller logic do not exist yet.

- [ ] **Step 3: Implement the shared helpers and controller chart**

Create `matlab/model/+sgv2/controlword.m`:

```matlab
function value = controlword(action)
switch char(action)
    case 'disable_voltage'
        value = uint16(hex2dec('0000'));
    case 'shutdown'
        value = uint16(hex2dec('0006'));
    case 'switch_on'
        value = uint16(hex2dec('0007'));
    case 'enable_operation'
        value = uint16(hex2dec('000F'));
    otherwise
        error('sgv2:UnknownControlwordAction', 'Unknown action: %s', char(action));
end
end
```

Create `matlab/model/+sgv2/statusState.m`:

```matlab
function state = statusState(statusword)
sw = uint16(statusword);

if bitand(sw, uint16(hex2dec('004F'))) == uint16(hex2dec('0008'))
    state = uint8(10);
elseif bitand(sw, uint16(hex2dec('006F'))) == uint16(hex2dec('0027'))
    state = uint8(4);
elseif bitand(sw, uint16(hex2dec('006F'))) == uint16(hex2dec('0023'))
    state = uint8(3);
elseif bitand(sw, uint16(hex2dec('006F'))) == uint16(hex2dec('0021'))
    state = uint8(2);
elseif bitand(sw, uint16(hex2dec('004F'))) == uint16(hex2dec('0040'))
    state = uint8(1);
else
    state = uint8(0);
end
end
```

Create `matlab/model/+sgv2/+internal/diagCodes.m`:

```matlab
function codes = diagCodes()
codes = struct( ...
    'NONE', uint8(0), ...
    'BUS_NOT_OP', uint8(1), ...
    'DRIVE_ERROR', uint8(2), ...
    'DRIVE_FAULT', uint8(3), ...
    'MODE_MISMATCH', uint8(4), ...
    'WAITING_ENABLE', uint8(5));
end
```

Create `matlab/model/+sgv2/+internal/diagMessageIds.m`:

```matlab
function ids = diagMessageIds()
ids = struct( ...
    'NONE', uint8(0), ...
    'CHECK_ETHERCAT_STATE', uint8(10), ...
    'CHECK_603F', uint8(20), ...
    'CHECK_6041', uint8(30), ...
    'CHECK_6061', uint8(40));
end
```

Create `matlab/model/+sgv2/+internal/diagLookupGroups.m`:

```matlab
function groups = diagLookupGroups()
groups = struct( ...
    'NONE', uint8(0), ...
    'ETHERCAT', uint8(1), ...
    'ERROR_CODE_603F', uint8(2), ...
    'STATUSWORD_6041', uint8(3), ...
    'MODE_DISPLAY_6061', uint8(4));
end
```

Create `matlab/model/+sgv2/+internal/autoStartStepIds.m`:

```matlab
function ids = autoStartStepIds()
ids = struct( ...
    'WAIT_BUS_OP', uint8(1), ...
    'WAIT_DRIVE_CLEAR', uint8(2), ...
    'AUTO_POWER_ON', uint8(3), ...
    'AUTO_ENABLE', uint8(4), ...
    'READY_TO_RUN', uint8(5));
end
```

Create `matlab/model/+sgv2/+internal/buildStartupChart.m` so the chart uses these ports:

```matlab
% Inputs
'actual_network_state', 'int32', 1
'expected_network_state', 'int32', 2
'statusword_6041', 'uint16', 3
'error_code_603f', 'uint16', 4
'mode_display_6061', 'int8', 5
'velocity_actual_606c', 'int32', 6
'speed_command_60ff', 'int32', 7
'speed_limit_607f', 'uint32', 8

% Outputs
'controlword_6040', 'uint16', 1
'velocity_command_60ff', 'int32', 2
'mode_command_6060', 'int8', 3
'speed_limit_out_607f', 'uint32', 4
'ready_to_run', 'uint8', 5
'auto_start_step', 'uint8', 6
'diag_code', 'uint8', 7
'diag_message_id', 'uint8', 8
'diag_lookup_group', 'uint8', 9
'diag_lookup_hint', 'uint8', 10
```

Use this chart behavior:

```matlab
controlword_6040 = sgv2.controlword('disable_voltage');
velocity_command_60ff = int32(0);
mode_command_6060 = int8(9);
speed_limit_out_607f = speed_limit_607f;
ready_to_run = uint8(0);
auto_start_step = sgv2.internal.autoStartStepIds().WAIT_BUS_OP;
diag_code = sgv2.internal.diagCodes().NONE;
diag_message_id = sgv2.internal.diagMessageIds().NONE;
diag_lookup_group = sgv2.internal.diagLookupGroups().NONE;
diag_lookup_hint = uint8(zeros(1, 48));

if int32(actual_network_state) ~= int32(expected_network_state)
    auto_start_step = sgv2.internal.autoStartStepIds().WAIT_BUS_OP;
    diag_code = sgv2.internal.diagCodes().BUS_NOT_OP;
    diag_message_id = sgv2.internal.diagMessageIds().CHECK_ETHERCAT_STATE;
    diag_lookup_group = sgv2.internal.diagLookupGroups().ETHERCAT;
    diag_lookup_hint(1:44) = uint8('Check EtherCAT manual: Get State / state');
elseif uint16(error_code_603f) ~= uint16(0)
    auto_start_step = sgv2.internal.autoStartStepIds().WAIT_DRIVE_CLEAR;
    diag_code = sgv2.internal.diagCodes().DRIVE_ERROR;
    diag_message_id = sgv2.internal.diagMessageIds().CHECK_603F;
    diag_lookup_group = sgv2.internal.diagLookupGroups().ERROR_CODE_603F;
    diag_lookup_hint(1:34) = uint8('Check SV660N manual: 603Fh error');
elseif sgv2.statusState(statusword_6041) >= uint8(10)
    auto_start_step = sgv2.internal.autoStartStepIds().WAIT_DRIVE_CLEAR;
    diag_code = sgv2.internal.diagCodes().DRIVE_FAULT;
    diag_message_id = sgv2.internal.diagMessageIds().CHECK_6041;
    diag_lookup_group = sgv2.internal.diagLookupGroups().STATUSWORD_6041;
    diag_lookup_hint(1:39) = uint8('Check SV660N manual: 6041h / CiA402');
elseif sgv2.statusState(statusword_6041) == uint8(1)
    auto_start_step = sgv2.internal.autoStartStepIds().AUTO_POWER_ON;
    controlword_6040 = sgv2.controlword('shutdown');
elseif sgv2.statusState(statusword_6041) == uint8(2)
    auto_start_step = sgv2.internal.autoStartStepIds().AUTO_ENABLE;
    controlword_6040 = sgv2.controlword('switch_on');
elseif sgv2.statusState(statusword_6041) == uint8(3)
    auto_start_step = sgv2.internal.autoStartStepIds().AUTO_ENABLE;
    controlword_6040 = sgv2.controlword('enable_operation');
elseif sgv2.statusState(statusword_6041) == uint8(4) && int8(mode_display_6061) ~= int8(9)
    auto_start_step = sgv2.internal.autoStartStepIds().AUTO_ENABLE;
    controlword_6040 = sgv2.controlword('enable_operation');
    diag_code = sgv2.internal.diagCodes().MODE_MISMATCH;
    diag_message_id = sgv2.internal.diagMessageIds().CHECK_6061;
    diag_lookup_group = sgv2.internal.diagLookupGroups().MODE_DISPLAY_6061;
    diag_lookup_hint(1:33) = uint8('Check SV660N manual: 6061h mode');
elseif sgv2.statusState(statusword_6041) == uint8(4)
    auto_start_step = sgv2.internal.autoStartStepIds().READY_TO_RUN;
    controlword_6040 = sgv2.controlword('enable_operation');
    velocity_command_60ff = speed_command_60ff;
    ready_to_run = uint8(1);
else
    auto_start_step = sgv2.internal.autoStartStepIds().WAIT_DRIVE_CLEAR;
    diag_code = sgv2.internal.diagCodes().WAITING_ENABLE;
    diag_message_id = sgv2.internal.diagMessageIds().CHECK_6041;
    diag_lookup_group = sgv2.internal.diagLookupGroups().STATUSWORD_6041;
    diag_lookup_hint(1:39) = uint8('Check SV660N manual: 6041h / CiA402');
end
```

Create `matlab/model/+sgv2/+internal/buildFrameworkHarness.m`:

```matlab
function modelName = buildFrameworkHarness()
defaults = project_defaults();
modelName = char(defaults.HarnessModelName);

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

load_system('simulink');
load_system('sflib');

new_system(modelName);
set_param(modelName, ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', num2str(defaults.SampleTime), ...
    'StopTime', '0.05', ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout');

controllerBlock = [modelName '/SV660N Sequence Controller'];
add_block('simulink/Ports & Subsystems/Subsystem', controllerBlock, ...
    'Position', [320 80 700 420]);
sgv2.internal.buildStartupChart(controllerBlock);

items = { ...
    'actual_network_state', 'network_state_ts', [30 60 140 80], 1; ...
    'expected_network_state', 'timeseries(int32([8 8]), [0 0.05])', [30 100 140 120], 2; ...
    'statusword_6041', 'statusword_ts', [30 140 140 160], 3; ...
    'error_code_603f', 'error_code_ts', [30 180 140 200], 4; ...
    'mode_display_6061', 'mode_display_ts', [30 220 140 240], 5; ...
    'velocity_actual_606c', 'velocity_actual_ts', [30 260 140 280], 6; ...
    'speed_command_60ff', 'speed_command_ts', [30 300 140 320], 7; ...
    'speed_limit_607f', 'speed_limit_ts', [30 340 140 360], 8};

for k = 1:size(items, 1)
    add_block('simulink/Sources/From Workspace', [modelName '/' items{k, 1}], ...
        'Position', items{k, 3}, ...
        'VariableName', items{k, 2});
    add_line(modelName, [items{k, 1} '/1'], ['SV660N Sequence Controller/' num2str(items{k, 4})], 'autorouting', 'on');
end

loggedOutputs = { ...
    'velocity_command_60ff', 2; ...
    'ready_to_run', 5; ...
    'auto_start_step', 6; ...
    'diag_code', 7};
for k = 1:size(loggedOutputs, 1)
    add_block('simulink/Sinks/Out1', [modelName '/' loggedOutputs{k, 1}], ...
        'Position', [770 100 + (k - 1) * 45 800 114 + (k - 1) * 45]);
    add_line(modelName, ['SV660N Sequence Controller/' num2str(loggedOutputs{k, 2})], [loggedOutputs{k, 1} '/1'], 'autorouting', 'on');
end
end
```

Replace `matlab/model/+sgv2/+internal/addSequenceController.m` with:

```matlab
function controllerBlock = addSequenceController(target)
modelName = char(target.ModelName);
controllerBlock = [modelName '/SV660N Sequence Controller'];
add_block('simulink/Ports & Subsystems/Subsystem', controllerBlock, ...
    'Position', [560 170 900 520]);
sgv2.internal.buildStartupChart(controllerBlock);
end
```

- [ ] **Step 4: Re-run the harness tests**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = runtests('tests/test_sequenceHarness.m');
assert(all([results.Passed]), 'Expected sequence harness tests to pass.');
```

Expected: bus-not-OP and ready-to-run cases both pass with the approved diagnostics and manual-speed gating.

- [ ] **Step 5: Checkpoint the planning files**

Update:

- `task_plan.md` with Task 3 completed
- `findings.md` with the final diag-code/message/group mapping
- `progress.md` with the harness test command and result

## Task 4: Write the slrtExplorer Runbook and Reference Docs

**Files:**
- Create: `docs/field_validation/speedgoat_v2_minimal.md`
- Create: `docs/reference/speedgoat_v2_signal_parameter_reference.md`
- Create: `docs/reference/speedgoat_v2_boundary_statement.md`
- Create: `matlab/tests/test_documentContracts.m`

- [ ] **Step 1: Write the failing docs-contract test**

Create `matlab/tests/test_documentContracts.m` with:

```matlab
function tests = test_documentContracts
tests = functiontests(localfunctions);
end

function testRunbookContainsApprovedExplorerFlow(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
runbook = fileread(fullfile(projectRoot, 'docs', 'field_validation', 'speedgoat_v2_minimal.md'));

verifyTrue(testCase, contains(runbook, '连接目标机'));
verifyTrue(testCase, contains(runbook, '点击 `Start`'));
verifyTrue(testCase, contains(runbook, '确认 `ready_to_run == 1`'));
verifyTrue(testCase, contains(runbook, '人工把速度降回 `0`'));
end

function testBoundaryStatementKeepsTheSpecExclusions(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
boundary = fileread(fullfile(projectRoot, 'docs', 'reference', 'speedgoat_v2_boundary_statement.md'));

verifyTrue(testCase, contains(boundary, '不改 ENI'));
verifyTrue(testCase, contains(boundary, '不做 MATLAB helper'));
verifyTrue(testCase, contains(boundary, '不做 TwinCAT'));
verifyTrue(testCase, contains(boundary, '只支持单轴 CSV'));
end
```

- [ ] **Step 2: Run the docs test to confirm it fails**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = runtests('tests/test_documentContracts.m');
disp(results([results.Passed] == 0));
```

Expected: failure because the runbook and reference docs do not exist yet.

- [ ] **Step 3: Write the operator-facing docs**

Create `docs/field_validation/speedgoat_v2_minimal.md` with:

```md
# speedgoat_v2_minimal slrtExplorer Runbook

1. 连接目标机。
2. 在 `slrtExplorer` 中加载 `speedgoat_v2_minimal`。
3. 打开以下信号观察：
   `actual_network_state`、`expected_network_state`、`statusword_6041`、`error_code_603f`、
   `mode_display_6061`、`velocity_actual_606c`、`diag_code`、`diag_message_id`、
   `diag_lookup_group`、`diag_lookup_hint`、`ready_to_run`、`auto_start_step`、`speed_command_60ff`。
4. 点击 `Start`。
5. 确认 `ready_to_run == 1` 后再人工修改 `speed_command_60ff`。
6. 若 `actual_network_state != 8`，先查看 `diag_lookup_hint`，然后去 EtherCAT 手册查状态机。
7. 若 `error_code_603f != 0` 或 `statusword_6041` 异常，先停在零速并去 SV660N 手册查 `603Fh/6041h`。
8. 人工把速度降回 `0`。
9. 点击 `Stop` 停止应用。
```

Create `docs/reference/speedgoat_v2_signal_parameter_reference.md` with:

```md
# speedgoat_v2_minimal Signal And Parameter Reference

| Name | Meaning | Source |
|---|---|---|
| `actual_network_state` | EtherCAT 实际网络状态 | `EtherCAT Get State` |
| `expected_network_state` | 期望网络状态，固定为 `8` | Constant command source |
| `statusword_6041` | 驱动状态字 | `1B04h Inputs` |
| `error_code_603f` | 驱动错误码 | `1B04h Inputs` |
| `mode_display_6061` | 模式显示 | `1B04h Inputs` |
| `velocity_actual_606c` | 实际速度 | `1B04h Inputs` |
| `diag_code` | 运行诊断代码 | Sequence Controller |
| `diag_message_id` | 诊断消息编号 | Sequence Controller |
| `diag_lookup_group` | 手册查阅分组 | Sequence Controller |
| `diag_lookup_hint` | 查阅提示 | Sequence Controller |
| `ready_to_run` | 是否允许人工给速度 | Sequence Controller |
| `auto_start_step` | 自动起机当前步骤 | Sequence Controller |
| `speed_command_60ff` | 人工速度给定 | `1702h Outputs` |
| `speed_limit_607f` | 保守速度上限 | `1702h Outputs` |
```

Create `docs/reference/speedgoat_v2_boundary_statement.md` with:

```md
# speedgoat_v2_minimal Boundary Statement

- 不改 ENI。
- 不做 MATLAB helper。
- 不做 TwinCAT。
- 不带入 `demo_stable`。
- 只支持单轴 CSV。
- 只消费 `1702h Outputs + 1B04h Inputs`。
- 自动起机只推进到 `ready_to_run`。
- 非零速度仍由人工给定。
```

- [ ] **Step 4: Re-run the docs-contract tests**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = runtests('tests/test_documentContracts.m');
assert(all([results.Passed]), 'Expected docs-contract tests to pass.');
```

Expected: the runbook and boundary statement now preserve the user-approved operating flow and exclusions.

- [ ] **Step 5: Checkpoint the planning files**

Update:

- `task_plan.md` with Task 4 completed
- `findings.md` with the final doc locations
- `progress.md` with the docs-contract test command and result

## Task 5: Run the Focused Regression Stack and Generate the First Artifact

**Files:**
- Test: `matlab/tests/test_targetConfig.m`
- Test: `matlab/tests/test_modelGeneration.m`
- Test: `matlab/tests/test_sequenceHarness.m`
- Test: `matlab/tests/test_documentContracts.m`

- [ ] **Step 1: Run the focused regression stack**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
results = [ ...
    runtests('tests/test_targetConfig.m'); ...
    runtests('tests/test_modelGeneration.m'); ...
    runtests('tests/test_sequenceHarness.m'); ...
    runtests('tests/test_documentContracts.m')];
assert(all([results.Passed]), 'Expected the focused v2 regression stack to pass.');
```

Expected: all focused tests pass.

- [ ] **Step 2: Regenerate the `.slx` from source**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
modelPath = build_speedgoat_v2_minimal();
disp(modelPath);
```

Expected: `matlab/model/models/speedgoat_v2_minimal.slx` is regenerated from the clean-room builder.

- [ ] **Step 3: Build the Simulink Real-Time application**

Run in MATLAB:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
load_system(char(target_minimal_slrtexplorer().ModelName));
slbuild(char(target_minimal_slrtexplorer().ModelName));
```

Expected: a new `.mldatx` for `speedgoat_v2_minimal` is produced locally.

- [ ] **Step 4: Perform the operator pre-flight review**

Use this checklist before any hardware session:

```md
- `actual_network_state` and `expected_network_state` are both visible in the generated app.
- `ready_to_run` remains `0` until bus, drive, and mode conditions are satisfied.
- `speed_command_60ff` defaults to `0`.
- `speed_limit_607f` defaults to the conservative commissioning value.
- The runbook and boundary statement are present under `docs/`.
```

Expected: the artifact is ready for `slrtExplorer` bring-up, with no hidden auto-motion path.

- [ ] **Step 5: Final checkpoint and delivery prep**

Update:

- `task_plan.md` with Phases 3-5 completed and Phase 7 left as hardware validation
- `findings.md` with the generated artifact paths and any build caveats
- `progress.md` with the focused regression output and `slbuild` result

## Plan Self-Review

### Spec Coverage

- Clean-room project separation, read-only ENI ownership, and `1702h + 1B04h` mapping are covered by Task 1.
- Minimal real-time model structure and `slrealtime.tlc` generation are covered by Task 2.
- Auto power-on / auto enable / `READY_TO_RUN` gating and diagnostic outputs are covered by Task 3.
- `slrtExplorer` runbook, signal reference, and boundary statement are covered by Task 4.
- Local verification and artifact generation are covered by Task 5.

### Placeholder Scan

- No `TODO`, `TBD`, “implement later”, or “similar to Task N” placeholders remain.
- Each task names exact files and concrete commands.

### Type Consistency

- `actual_network_state` and `expected_network_state` stay `int32`.
- `mode_display_6061` and `mode_command_6060` stay `int8`.
- `diag_code`, `diag_message_id`, `diag_lookup_group`, and `auto_start_step` stay `uint8`.
- `speed_command_60ff` stays `int32`, while `speed_limit_607f` stays `uint32`.
