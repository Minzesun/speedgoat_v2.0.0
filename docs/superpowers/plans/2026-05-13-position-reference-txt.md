# Position Reference Txt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-column `.txt` position-reference workflow that drives the existing PT-5 position loop and exposes reference curves in slrtExplorer/Data Inspector.

**Architecture:** Keep the model generator-driven. A focused MATLAB loader reads `data/reference/position_reference_6064.txt`, validates the one-column numeric trajectory, computes one-sample-per-row position and finite-difference rate vectors from `target.SampleTime`, and seeds model workspace variables. A new top-level `Position Reference Source` subsystem indexes those vectors at runtime, applies the feedforward-enable tunable, returns zero after the final sample, and feeds the existing PT-5 command inputs.

**Tech Stack:** MATLAB functiontests, Simulink programmatic model generation, Simulink Real-Time application packaging, existing `sgv2.internal.*` builders.

---

## File Structure

### Create

- `data/reference/position_reference_6064.txt`
  Default one-column reference file so the current build flow has a valid safe trajectory.
- `matlab/model/+sgv2/+internal/loadPositionReferenceTxt.m`
  Reads and validates the txt file, computes int32 position/rate vectors, and returns workspace variable names and values.
- `matlab/model/+sgv2/+internal/addPositionReferenceSource.m`
  Adds the top-level reference subsystem and exposes the scalar reference outputs.
- `matlab/tests/test_positionReferenceTxt.m`
  Unit tests for file parsing, sample-time interpretation, rate computation, and invalid-input rejection.

### Modify

- `matlab/config/axes/sv660n_axis1.m`
  Add reference file and feedforward-enable defaults; remove `DefaultPositionLoopEnabled`.
- `matlab/config/target_minimal_slrtexplorer.m`
  Add `PositionReferenceFeedforwardEnabled`, add reference signal names, and remove `PositionLoopEnabled` tunable.
- `matlab/model/+sgv2/+internal/buildMinimalModel.m`
  Load reference data and seed model workspace variables before building reference and PT-5 wiring.
- `matlab/model/+sgv2/+internal/addPositionLoopController.m`
  Stop creating tunable position command/rate command Constant blocks; accept reference-source blocks instead; replace the tunable enable request with a fixed root Constant `int32(1)`.
- `matlab/model/+sgv2/+internal/addObservabilityPorts.m`
  Add `position_reference_6064`, `position_rate_reference_6064`, `position_command_6064`, and `position_rate_command_6064` observability outputs from the new source.
- `matlab/model/build_speedgoat_v2_minimal_app.m`
  Assert the package contains `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED` and does not contain `SGV2_POSITION_LOOP_ENABLED`.
- `matlab/tests/test_targetConfig.m`
  Update the configuration contract for reference defaults and tunables.
- `matlab/tests/test_modelGeneration.m`
  Assert the reference subsystem, signals, block values, and PT-5 input wiring.
- `matlab/tests/test_task5CommandCompatibility.m`
  Update package assertions for the new tunable and removed enable tunable.
- `matlab/tests/test_documentContracts.m`
  Lock docs for txt reference and Data Inspector visibility.
- `docs/reference/speedgoat_v2_signal_parameter_reference.md`
  Document the txt reference, new feedforward enable, and removed loop enable tunable.
- `docs/field_validation/speedgoat_v2_position_tuning.md`
  Update the field runbook so the operator edits the txt file and plots reference versus actual.
- `SPEEDGOAT_V2_MINIMAL_LOGIC.md`
  Update the high-level logic section for the new file-based reference path.

## Task 1: Reference Txt Loader

**Files:**
- Create: `data/reference/position_reference_6064.txt`
- Create: `matlab/model/+sgv2/+internal/loadPositionReferenceTxt.m`
- Create: `matlab/tests/test_positionReferenceTxt.m`

- [ ] **Step 1: Write the failing txt-loader test**

Create `matlab/tests/test_positionReferenceTxt.m`:

```matlab
function tests = test_positionReferenceTxt
tests = functiontests(localfunctions);
end

function testOneColumnTxtUsesTargetSampleTimeAndComputesRate(testCase)
tempRoot = tempname;
mkdir(tempRoot);
cleanup = onCleanup(@() rmdir(tempRoot, 's')); %#ok<NASGU>
referencePath = fullfile(tempRoot, 'position_reference_6064.txt');
writematrix(int32([0; 0; 2; 5]), referencePath, 'FileType', 'text');

target = target_minimal_slrtexplorer();
target.AxisConfig.DefaultPositionReferenceFile = string(referencePath);

reference = sgv2.internal.loadPositionReferenceTxt(target);

verifyEqual(testCase, reference.FilePath, string(referencePath));
verifyEqual(testCase, reference.SampleTime, target.SampleTime);
verifyEqual(testCase, reference.PositionValues6064, int32([0; 0; 2; 5; 0]));
verifyEqual(testCase, reference.RateValues6064, int32([0; 0; 1000; 1500; 0]));
verifyEqual(testCase, reference.SampleCount, uint32(5));
verifyEqual(testCase, reference.PositionVariableName, "SGV2_POSITION_REFERENCE_VALUES_6064");
verifyEqual(testCase, reference.RateVariableName, "SGV2_POSITION_RATE_REFERENCE_VALUES_6064");
end

function testDefaultReferencePathResolvesFromProjectRoot(testCase)
target = target_minimal_slrtexplorer();
reference = sgv2.internal.loadPositionReferenceTxt(target);

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
expectedPath = fullfile(projectRoot, "data", "reference", "position_reference_6064.txt");
verifyEqual(testCase, reference.FilePath, expectedPath);
verifyGreaterThanOrEqual(testCase, reference.SampleCount, uint32(2));
verifyEqual(testCase, reference.PositionValues6064(end), int32(0));
verifyEqual(testCase, reference.RateValues6064(end), int32(0));
end

function testRejectsInvalidReferenceFiles(testCase)
target = target_minimal_slrtexplorer();

missingTarget = target;
missingTarget.AxisConfig.DefaultPositionReferenceFile = "missing_reference.txt";
verifyError(testCase, @() sgv2.internal.loadPositionReferenceTxt(missingTarget), ...
    'sgv2:PositionReferenceFileMissing');

emptyPath = localWriteText("");
emptyTarget = target;
emptyTarget.AxisConfig.DefaultPositionReferenceFile = string(emptyPath);
verifyError(testCase, @() sgv2.internal.loadPositionReferenceTxt(emptyTarget), ...
    'sgv2:PositionReferenceFileEmpty');

badTextPath = localWriteText("1" + newline + "abc");
badTextTarget = target;
badTextTarget.AxisConfig.DefaultPositionReferenceFile = string(badTextPath);
verifyError(testCase, @() sgv2.internal.loadPositionReferenceTxt(badTextTarget), ...
    'sgv2:PositionReferenceFileInvalid');

nanPath = localWriteText("1" + newline + "NaN");
nanTarget = target;
nanTarget.AxisConfig.DefaultPositionReferenceFile = string(nanPath);
verifyError(testCase, @() sgv2.internal.loadPositionReferenceTxt(nanTarget), ...
    'sgv2:PositionReferenceFileInvalid');
end

function path = localWriteText(text)
tempRoot = tempname;
mkdir(tempRoot);
path = fullfile(tempRoot, 'position_reference_6064.txt');
fid = fopen(path, 'w');
fprintf(fid, '%s', text);
fclose(fid);
end
```

- [ ] **Step 2: Run the loader test and verify RED**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_positionReferenceTxt.m'); disp(table(results)); assert(any([results.Failed]), 'Expected reference loader tests to fail before implementation.');"
```

Expected: FAIL because `sgv2.internal.loadPositionReferenceTxt` does not exist.

- [ ] **Step 3: Add the default safe txt reference**

Create `data/reference/position_reference_6064.txt`:

```text
0
0
```

- [ ] **Step 4: Implement the minimal txt loader**

Create `matlab/model/+sgv2/+internal/loadPositionReferenceTxt.m`:

```matlab
function reference = loadPositionReferenceTxt(target)
referencePath = localResolveReferencePath(target);

if ~isfile(referencePath)
    error('sgv2:PositionReferenceFileMissing', ...
        'Position reference file does not exist: %s', referencePath);
end

text = strtrim(fileread(referencePath));
if strlength(string(text)) == 0
    error('sgv2:PositionReferenceFileEmpty', ...
        'Position reference file is empty: %s', referencePath);
end

try
    values = readmatrix(referencePath, 'FileType', 'text');
catch ME
    error('sgv2:PositionReferenceFileInvalid', ...
        'Could not parse position reference file %s: %s', referencePath, ME.message);
end

if isempty(values) || ~isnumeric(values) || size(values, 2) ~= 1 || ...
        any(~isfinite(values(:)))
    error('sgv2:PositionReferenceFileInvalid', ...
        'Position reference file must contain exactly one finite numeric column: %s', referencePath);
end

sampleTime = double(target.SampleTime);
if ~isfinite(sampleTime) || sampleTime <= 0
    error('sgv2:PositionReferenceSampleTimeInvalid', ...
        'Target sample time must be positive and finite.');
end

positionValues = int32(round(values(:)));
positionValues = [positionValues; int32(0)];

rateValues = zeros(size(positionValues), 'int32');
if numel(positionValues) > 2
    positionDelta = double(positionValues(2:end-1)) - double(positionValues(1:end-2));
    rateValues(2:end-1) = int32(round(positionDelta ./ sampleTime));
end

reference = struct( ...
    'FilePath', string(referencePath), ...
    'SampleTime', sampleTime, ...
    'PositionValues6064', positionValues, ...
    'RateValues6064', rateValues, ...
    'SampleCount', uint32(numel(positionValues)), ...
    'PositionVariableName', "SGV2_POSITION_REFERENCE_VALUES_6064", ...
    'RateVariableName', "SGV2_POSITION_RATE_REFERENCE_VALUES_6064", ...
    'CountVariableName', "SGV2_POSITION_REFERENCE_SAMPLE_COUNT");
end

function referencePath = localResolveReferencePath(target)
pathValue = string(target.AxisConfig.DefaultPositionReferenceFile);
if isfile(pathValue) || isfolder(fileparts(pathValue))
    referencePath = char(pathValue);
    return;
end

defaults = project_defaults();
referencePath = char(fullfile(defaults.ProjectRoot, pathValue));
end
```

- [ ] **Step 5: Run the loader test and verify GREEN**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_positionReferenceTxt.m'); disp(table(results)); assertSuccess(results);"
```

Expected: PASS for the loader test.

- [ ] **Step 6: Commit Task 1**

Run:

```powershell
git add data/reference/position_reference_6064.txt matlab/model/+sgv2/+internal/loadPositionReferenceTxt.m matlab/tests/test_positionReferenceTxt.m
git commit -m "feat: load txt position reference"
```

## Task 2: Target Config And Tunable Contract

**Files:**
- Modify: `matlab/config/axes/sv660n_axis1.m`
- Modify: `matlab/config/target_minimal_slrtexplorer.m`
- Modify: `matlab/tests/test_targetConfig.m`

- [ ] **Step 1: Update the failing config contract test**

Modify `matlab/tests/test_targetConfig.m` so `fieldnames(target.AxisConfig)` includes:

```matlab
'DefaultPositionReferenceFile'
'DefaultPositionReferenceFeedforwardEnabled'
```

and no longer includes:

```matlab
'DefaultPositionLoopEnabled'
```

Modify `fieldnames(target.Tunables)` so it includes:

```matlab
'PositionReferenceFeedforwardEnabled'
```

and no longer includes:

```matlab
'PositionLoopEnabled'
```

Modify `fieldnames(target.Signals)` so it includes:

```matlab
'PositionReference6064'
'PositionRateReference6064'
```

Add these assertions:

```matlab
verifyEqual(testCase, target.AxisConfig.DefaultPositionReferenceFile, ...
    "data/reference/position_reference_6064.txt");
verifyEqual(testCase, target.AxisConfig.DefaultPositionReferenceFeedforwardEnabled, int32(1));
verifyEqual(testCase, target.Tunables.PositionReferenceFeedforwardEnabled, ...
    "SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED");
verifyEqual(testCase, target.Signals.PositionReference6064, "position_reference_6064");
verifyEqual(testCase, target.Signals.PositionRateReference6064, "position_rate_reference_6064");
verifyFalse(testCase, isfield(target.Tunables, 'PositionLoopEnabled'));
verifyFalse(testCase, isfield(target.AxisConfig, 'DefaultPositionLoopEnabled'));
```

- [ ] **Step 2: Run the config test and verify RED**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_targetConfig.m'); disp(table(results)); assert(any([results.Failed]), 'Expected config contract to fail before target updates.');"
```

Expected: FAIL because the new reference fields are missing and the old position-loop enable fields still exist.

- [ ] **Step 3: Update axis config**

Modify `matlab/config/axes/sv660n_axis1.m`:

```matlab
'DefaultPositionReferenceFile', "data/reference/position_reference_6064.txt", ...
'DefaultPositionReferenceFeedforwardEnabled', int32(1), ...
```

Remove this field:

```matlab
'DefaultPositionLoopEnabled', int32(0), ...
```

- [ ] **Step 4: Update target config**

Modify `matlab/config/target_minimal_slrtexplorer.m`.

Add to `target.Tunables`:

```matlab
'PositionReferenceFeedforwardEnabled', "SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED", ...
```

Remove from `target.Tunables`:

```matlab
'PositionLoopEnabled', "SGV2_POSITION_LOOP_ENABLED", ...
```

Add to `target.Signals`:

```matlab
'PositionReference6064', "position_reference_6064", ...
'PositionRateReference6064', "position_rate_reference_6064", ...
```

- [ ] **Step 5: Run the config test and verify GREEN**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_targetConfig.m'); disp(table(results)); assertSuccess(results);"
```

Expected: PASS for the updated target contract.

- [ ] **Step 6: Commit Task 2**

Run:

```powershell
git add matlab/config/axes/sv660n_axis1.m matlab/config/target_minimal_slrtexplorer.m matlab/tests/test_targetConfig.m
git commit -m "feat: add position reference config"
```

## Task 3: Position Reference Source Model Wiring

**Files:**
- Create: `matlab/model/+sgv2/+internal/addPositionReferenceSource.m`
- Modify: `matlab/model/+sgv2/+internal/buildMinimalModel.m`
- Modify: `matlab/model/+sgv2/+internal/addPositionLoopController.m`
- Modify: `matlab/model/+sgv2/+internal/addObservabilityPorts.m`
- Modify: `matlab/tests/test_modelGeneration.m`

- [ ] **Step 1: Update the failing model-generation test**

Add these assertions to `matlab/tests/test_modelGeneration.m` after `modelName` is set:

```matlab
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/Position Reference Source']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_reference_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_rate_reference_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_reference_values_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_rate_reference_values_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_reference_feedforward_enabled']) > 0);
verifyEqual(testCase, get_param([modelName '/position_reference_feedforward_enabled'], 'Value'), ...
    char(target.Tunables.PositionReferenceFeedforwardEnabled));
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_loop_enabled_request']) > 0);
verifyEqual(testCase, get_param([modelName '/position_loop_enabled_request'], 'Value'), 'int32(1)');
verifyNotEqual(testCase, get_param([modelName '/position_command_6064'], 'BlockType'), 'Constant');
verifyNotEqual(testCase, get_param([modelName '/position_rate_command_6064'], 'BlockType'), 'Constant');
```

Replace any existing assertion that expects:

```matlab
get_param([modelName '/position_loop_enabled_request'], 'Value')
```

to equal `char(target.Tunables.PositionLoopEnabled)` with the fixed-value assertion above.

- [ ] **Step 2: Run the model-generation test and verify RED**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_modelGeneration.m'); disp(table(results)); assert(any([results.Failed]), 'Expected model generation test to fail before reference source exists.');"
```

Expected: FAIL because `Position Reference Source` and reference signals are not generated yet.

- [ ] **Step 3: Seed reference workspace variables during model generation**

Modify `localSeedModelWorkspaceDefaults` in `matlab/model/+sgv2/+internal/buildMinimalModel.m`:

```matlab
reference = sgv2.internal.loadPositionReferenceTxt(target);
assignin(modelWorkspace, char(reference.PositionVariableName), reference.PositionValues6064);
assignin(modelWorkspace, char(reference.RateVariableName), reference.RateValues6064);
assignin(modelWorkspace, char(reference.CountVariableName), reference.SampleCount);
assignin(modelWorkspace, char(target.Tunables.PositionReferenceFeedforwardEnabled), ...
    target.AxisConfig.DefaultPositionReferenceFeedforwardEnabled);
```

Remove this assignment:

```matlab
assignin(modelWorkspace, char(target.Tunables.PositionLoopEnabled), ...
    target.AxisConfig.DefaultPositionLoopEnabled);
```

- [ ] **Step 4: Add the reference source builder**

Create `matlab/model/+sgv2/+internal/addPositionReferenceSource.m`:

```matlab
function referenceBlocks = addPositionReferenceSource(target)
modelName = char(target.ModelName);
sourceBlock = [modelName '/Position Reference Source'];
add_block('simulink/Ports & Subsystems/Subsystem', sourceBlock, ...
    'Position', [300 540 500 700]);

positionValuesBlock = [modelName '/position_reference_values_6064'];
rateValuesBlock = [modelName '/position_rate_reference_values_6064'];
feedforwardEnableBlock = [modelName '/position_reference_feedforward_enabled'];

add_block('simulink/Sources/Constant', positionValuesBlock, ...
    'Value', 'SGV2_POSITION_REFERENCE_VALUES_6064', ...
    'OutDataTypeStr', 'int32', ...
    'Position', [80 545 220 575]);
add_block('simulink/Sources/Constant', rateValuesBlock, ...
    'Value', 'SGV2_POSITION_RATE_REFERENCE_VALUES_6064', ...
    'OutDataTypeStr', 'int32', ...
    'Position', [80 595 220 625]);
add_block('simulink/Sources/Constant', feedforwardEnableBlock, ...
    'Value', char(target.Tunables.PositionReferenceFeedforwardEnabled), ...
    'OutDataTypeStr', 'int32', ...
    'Position', [80 645 220 675]);

localBuildReferenceSubsystem(sourceBlock);

sourceHandles = get_param(sourceBlock, 'PortHandles');
positionHandles = get_param(positionValuesBlock, 'PortHandles');
rateHandles = get_param(rateValuesBlock, 'PortHandles');
feedforwardEnableHandles = get_param(feedforwardEnableBlock, 'PortHandles');

add_line(modelName, positionHandles.Outport, sourceHandles.Inport(1), 'autorouting', 'on');
add_line(modelName, rateHandles.Outport, sourceHandles.Inport(2), 'autorouting', 'on');
add_line(modelName, feedforwardEnableHandles.Outport, sourceHandles.Inport(3), 'autorouting', 'on');

referenceBlocks = struct( ...
    'SourceBlock', sourceBlock, ...
    'PositionReferenceBlock', sourceBlock, ...
    'RateReferenceBlock', sourceBlock, ...
    'PositionCommandBlock', sourceBlock, ...
    'RateCommandBlock', sourceBlock, ...
    'PositionReferencePort', 1, ...
    'RateReferencePort', 2, ...
    'PositionCommandPort', 1, ...
    'RateCommandPort', 2);
end

function localBuildReferenceSubsystem(sourceBlock)
lineHandles = find_system(sourceBlock, 'FindAll', 'on', 'Type', 'line');
if ~isempty(lineHandles)
    delete_line(lineHandles);
end
blocks = find_system(sourceBlock, 'SearchDepth', 1, 'Type', 'Block');
for k = 2:numel(blocks)
    delete_block(blocks{k});
end

add_block('simulink/Sources/In1', [sourceBlock '/position_values_6064'], 'Position', [30 45 60 59]);
add_block('simulink/Sources/In1', [sourceBlock '/rate_values_6064'], 'Position', [30 95 60 109]);
add_block('simulink/Sources/In1', [sourceBlock '/feedforward_enabled'], 'Position', [30 145 60 159]);
add_block('simulink/Discrete/Unit Delay', [sourceBlock '/sample_index_delay'], ...
    'InitialCondition', 'uint32(1)', ...
    'SampleTime', '-1', ...
    'Position', [110 205 160 235]);
add_block('simulink/User-Defined Functions/MATLAB Function', [sourceBlock '/reference_step'], ...
    'Position', [220 65 440 205]);
add_block('simulink/Sinks/Out1', [sourceBlock '/position_reference_6064'], 'Position', [520 70 550 84]);
add_block('simulink/Sinks/Out1', [sourceBlock '/position_rate_reference_6064'], 'Position', [520 120 550 134]);
add_block('simulink/Sinks/Out1', [sourceBlock '/sample_index_next'], 'Position', [520 205 550 219]);

block = [sourceBlock '/reference_step'];
rt = sfroot;
chart = rt.find('-isa', 'Stateflow.EMChart', 'Path', block);
chart.Script = sprintf([ ...
    'function [position_ref, rate_ref, next_index] = reference_step(position_values, rate_values, feedforward_enabled, sample_index)\n' ...
    '%%#codegen\n' ...
    'count = uint32(numel(position_values));\n' ...
    'idx = sample_index;\n' ...
    'if idx < uint32(1)\n' ...
    '    idx = uint32(1);\n' ...
    'end\n' ...
    'if idx > count\n' ...
    '    position_ref = int32(0);\n' ...
    '    raw_rate = int32(0);\n' ...
    'else\n' ...
    '    position_ref = int32(position_values(idx));\n' ...
    '    raw_rate = int32(rate_values(idx));\n' ...
    'end\n' ...
    'if int32(feedforward_enabled) ~= int32(0)\n' ...
    '    rate_ref = raw_rate;\n' ...
    'else\n' ...
    '    rate_ref = int32(0);\n' ...
    'end\n' ...
    'if idx < count\n' ...
    '    next_index = idx + uint32(1);\n' ...
    'else\n' ...
    '    next_index = count + uint32(1);\n' ...
    'end\n' ...
    'end\n']);

add_line(sourceBlock, 'position_values_6064/1', 'reference_step/1', 'autorouting', 'on');
add_line(sourceBlock, 'rate_values_6064/1', 'reference_step/2', 'autorouting', 'on');
add_line(sourceBlock, 'feedforward_enabled/1', 'reference_step/3', 'autorouting', 'on');
add_line(sourceBlock, 'sample_index_delay/1', 'reference_step/4', 'autorouting', 'on');
add_line(sourceBlock, 'reference_step/1', 'position_reference_6064/1', 'autorouting', 'on');
add_line(sourceBlock, 'reference_step/2', 'position_rate_reference_6064/1', 'autorouting', 'on');
add_line(sourceBlock, 'reference_step/3', 'sample_index_next/1', 'autorouting', 'on');
add_line(sourceBlock, 'reference_step/3', 'sample_index_delay/1', 'autorouting', 'on');
end
```

- [ ] **Step 5: Wire reference source before PT-5**

Modify `matlab/model/+sgv2/+internal/buildMinimalModel.m`:

```matlab
[controllerBlock, getStateBlock, rxBlocks, txBlocks] = sgv2.internal.addEthercatIo(target);
referenceBlocks = sgv2.internal.addPositionReferenceSource(target);
[positionLoopBlock, positionLoopCommandDelayBlock] = sgv2.internal.addPositionLoopController( ...
    target, controllerBlock, rxBlocks.positionActual6064, referenceBlocks);
commandBlocks = sgv2.internal.addManualCommandInterface(target, controllerBlock);
sgv2.internal.addObservabilityPorts(target, controllerBlock, positionLoopBlock, ...
    positionLoopCommandDelayBlock, getStateBlock, rxBlocks, txBlocks, commandBlocks, referenceBlocks);
```

- [ ] **Step 6: Update PT-5 input wiring**

Modify `matlab/model/+sgv2/+internal/addPositionLoopController.m` signature:

```matlab
function [positionLoopBlock, positionLoopCommandDelayBlock] = addPositionLoopController(target, controllerBlock, positionActualSourceBlock, referenceBlocks)
```

Remove creation of root `position_command_6064` and root `position_rate_command_6064` Constant blocks.

Connect reference outputs:

```matlab
referenceHandles = get_param(referenceBlocks.SourceBlock, 'PortHandles');
add_line(modelName, referenceHandles.Outport(referenceBlocks.PositionCommandPort), positionLoopHandles.Inport(1), 'autorouting', 'on');
add_line(modelName, referenceHandles.Outport(referenceBlocks.RateCommandPort), positionLoopHandles.Inport(2), 'autorouting', 'on');
```

Create a fixed root PT-5 enable Constant:

```matlab
positionLoopEnableBlock = [modelName '/position_loop_enabled_request'];
add_block('simulink/Sources/Constant', positionLoopEnableBlock, ...
    'Value', 'int32(1)', ...
    'OutDataTypeStr', 'int32', ...
    'Position', [120 650 210 670]);
positionLoopEnableHandles = get_param(positionLoopEnableBlock, 'PortHandles');
add_line(modelName, positionLoopEnableHandles.Outport, positionLoopHandles.Inport(5), 'autorouting', 'on');
```

Keep the remaining parameter specs in this order:

```matlab
specs = { ...
    'position_loop_kp', char(target.Tunables.PositionLoopKp), 'int32'; ...
    'position_loop_ki', char(target.Tunables.PositionLoopKi), 'int32'; ...
    'position_loop_kd', char(target.Tunables.PositionLoopKd), 'int32'; ...
    'position_loop_sample_time', char(target.Tunables.PositionLoopSampleTime), 'double'; ...
    'position_loop_integrator_limit', char(target.Tunables.PositionLoopIntegratorLimit), 'int32'; ...
    'position_velocity_gain', char(target.Tunables.PositionVelocityGain), 'int32'; ...
    'position_velocity_bias', char(target.Tunables.PositionVelocityBias), 'int32'; ...
    'command_deadband', char(target.Tunables.CommandDeadband), 'int32'; ...
    'max_tracking_speed', char(target.Tunables.MaxTrackingSpeed), 'int32'};
```

Connect those specs to PT-5 input ports `6:14`, because input port `5` is now owned by the fixed enable request.

- [ ] **Step 7: Update observability outputs**

Modify `matlab/model/+sgv2/+internal/addObservabilityPorts.m` signature:

```matlab
function addObservabilityPorts(target, controllerBlock, positionLoopBlock, positionLoopCommandDelayBlock, getStateBlock, rxBlocks, txBlocks, commandBlocks, referenceBlocks) %#ok<INUSD>
```

Add these signal rows before `PositionActual6064`:

```matlab
target.Signals.PositionReference6064, referenceBlocks.SourceBlock, 1; ...
target.Signals.PositionRateReference6064, referenceBlocks.SourceBlock, 2; ...
target.Signals.PositionCommand6064, referenceBlocks.SourceBlock, 1; ...
target.Signals.PositionRateCommand6064, referenceBlocks.SourceBlock, 2; ...
```

- [ ] **Step 8: Run model-generation test and verify GREEN**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_modelGeneration.m'); disp(table(results)); assertSuccess(results);"
```

Expected: PASS and generated model contains `Position Reference Source` plus top-level reference observability signals.

- [ ] **Step 9: Commit Task 3**

Run:

```powershell
git add matlab/model/+sgv2/+internal/addPositionReferenceSource.m matlab/model/+sgv2/+internal/buildMinimalModel.m matlab/model/+sgv2/+internal/addPositionLoopController.m matlab/model/+sgv2/+internal/addObservabilityPorts.m matlab/tests/test_modelGeneration.m
git commit -m "feat: wire txt reference into position loop"
```

## Task 4: Package Contract

**Files:**
- Modify: `matlab/model/build_speedgoat_v2_minimal_app.m`
- Modify: `matlab/tests/test_task5CommandCompatibility.m`

- [ ] **Step 1: Update package tests to fail for old enable tunable**

Modify `verifyPackageContainsPositionTunables` in `matlab/tests/test_task5CommandCompatibility.m`:

```matlab
verifyTrue(testCase, contains(paramInfo, 'SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED'));
verifyFalse(testCase, contains(paramInfo, 'SGV2_POSITION_LOOP_ENABLED'));
verifyTrue(testCase, contains(paramInfo, 'SGV2_POSITION_LOOP_KP'));
verifyTrue(testCase, contains(paramInfo, 'SGV2_POSITION_LOOP_KI'));
verifyTrue(testCase, contains(paramInfo, 'SGV2_POSITION_LOOP_KD'));
verifyTrue(testCase, contains(paramInfo, 'SGV2_MAX_TRACKING_SPEED'));
```

Remove assertions for:

```matlab
SGV2_POSITION_COMMAND_6064
SGV2_POSITION_RATE_COMMAND_6064
SGV2_POSITION_LOOP_ENABLED
```

- [ ] **Step 2: Run package test and verify RED**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_task5CommandCompatibility.m'); disp(table(results)); assert(any([results.Failed]), 'Expected package test to fail before package assertion updates.');"
```

Expected: FAIL because `build_speedgoat_v2_minimal_app` still requires `SGV2_POSITION_LOOP_ENABLED`.

- [ ] **Step 3: Update application package assertion**

Modify `requiredTokens` in `matlab/model/build_speedgoat_v2_minimal_app.m`:

```matlab
requiredTokens = { ...
    'SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED'
    'SGV2_POSITION_LOOP_KP'
    'SGV2_POSITION_LOOP_KI'
    'SGV2_POSITION_LOOP_KD'
    'SGV2_MAX_TRACKING_SPEED'};
```

After the required-token loop, add:

```matlab
forbiddenTokens = {'SGV2_POSITION_LOOP_ENABLED'};
for k = 1:numel(forbiddenTokens)
    if contains(paramInfo, forbiddenTokens{k})
        error('sgv2:ApplicationPackageForbiddenTunable', ...
            'Package %s still exposes %s.', appPath, forbiddenTokens{k});
    end
end
```

- [ ] **Step 4: Run package test and verify GREEN**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_task5CommandCompatibility.m'); disp(table(results)); assertSuccess(results);"
```

Expected: PASS, with the package exporting `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED` and not exporting `SGV2_POSITION_LOOP_ENABLED`.

- [ ] **Step 5: Commit Task 4**

Run:

```powershell
git add matlab/model/build_speedgoat_v2_minimal_app.m matlab/tests/test_task5CommandCompatibility.m
git commit -m "test: lock reference package tunables"
```

## Task 5: Operator Documentation

**Files:**
- Modify: `matlab/tests/test_documentContracts.m`
- Modify: `docs/reference/speedgoat_v2_signal_parameter_reference.md`
- Modify: `docs/field_validation/speedgoat_v2_position_tuning.md`
- Modify: `SPEEDGOAT_V2_MINIMAL_LOGIC.md`

- [ ] **Step 1: Update docs-contract test**

Modify `matlab/tests/test_documentContracts.m` to assert the reference workflow:

```matlab
function testPositionReferenceTxtWorkflowIsDocumented(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
signalRef = fileread(fullfile(projectRoot, 'docs', 'reference', ...
    'speedgoat_v2_signal_parameter_reference.md'));
tuning = fileread(fullfile(projectRoot, 'docs', 'field_validation', ...
    'speedgoat_v2_position_tuning.md'));
logic = fileread(fullfile(projectRoot, 'SPEEDGOAT_V2_MINIMAL_LOGIC.md'));

verifyTrue(testCase, contains(signalRef, 'data/reference/position_reference_6064.txt'));
verifyTrue(testCase, contains(signalRef, 'position_reference_6064'));
verifyTrue(testCase, contains(signalRef, 'position_rate_reference_6064'));
verifyTrue(testCase, contains(signalRef, 'SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED'));
verifyTrue(testCase, contains(signalRef, 'SGV2_POSITION_LOOP_ENABLED'));
verifyTrue(testCase, contains(signalRef, '不再'));

verifyTrue(testCase, contains(tuning, 'data/reference/position_reference_6064.txt'));
verifyTrue(testCase, contains(tuning, '每行一个位置点'));
verifyTrue(testCase, contains(tuning, 'Data Inspector'));
verifyTrue(testCase, contains(tuning, 'position_actual_6064'));

verifyTrue(testCase, contains(logic, 'Position Reference Source'));
verifyTrue(testCase, contains(logic, 'position_reference_6064'));
end
```

- [ ] **Step 2: Run docs test and verify RED**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_documentContracts.m'); disp(table(results)); assert(any([results.Failed]), 'Expected docs contract to fail before docs updates.');"
```

Expected: FAIL because the docs still describe the old tunable-command workflow.

- [ ] **Step 3: Update signal and parameter reference**

In `docs/reference/speedgoat_v2_signal_parameter_reference.md`, update the reference rows to include:

```md
| `data/reference/position_reference_6064.txt` | 一列位置参考文件；每行一个控制周期的位置点 | Operator txt file | 构建前编辑，构建时自动读入模型 | PT-8 调参 runbook |
| `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED` | 自动差分速度前馈开关，默认 `1` | AxisConfig / Tunables | `1` 使用差分速度前馈，`0` 速度前馈强制为 `0` | 位置参考源 |
| `position_reference_6064` | txt 文件播放出来的位置参考 | Position Reference Source | 在 Data Inspector 里和 `position_actual_6064` 叠加看 | txt reference 文件和模型采样时间 |
| `position_rate_reference_6064` | 自动差分出来的速度前馈参考，受 feedforward 开关控制 | Position Reference Source | 在 Data Inspector 里确认前馈是否符合轨迹斜率 | `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED` |
```

Replace the old explanation of `SGV2_POSITION_LOOP_ENABLED` with:

```md
`SGV2_POSITION_LOOP_ENABLED` 不再作为现场可调参数暴露。位置环请求在模型内部固定为 `1`，实际是否输出运动命令仍由 `ready_to_run`、PT-5 限幅和启动控制器门禁决定。
```

- [ ] **Step 4: Update position tuning runbook**

In `docs/field_validation/speedgoat_v2_position_tuning.md`, replace the “要改哪些参数” section for position command/rate with:

```md
## 位置 reference 文件

构建前编辑：

```text
data/reference/position_reference_6064.txt
```

文件每行一个位置点，不写时间列。模型会用内部 `target.SampleTime` 解释每一行的时间间隔。播放到最后一行后，`position_reference_6064` 和 `position_rate_reference_6064` 都回到 `0`。

如果要关闭自动速度前馈，在 `Parameters` 页签里把：

```text
SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED = 0
```

默认值是 `1`，表示使用相邻位置点差分出来的速度前馈。
```

Remove operator instructions that say to tune:

```text
SGV2_POSITION_COMMAND_6064
SGV2_POSITION_RATE_COMMAND_6064
SGV2_POSITION_LOOP_ENABLED
```

- [ ] **Step 5: Update logic document**

In `SPEEDGOAT_V2_MINIMAL_LOGIC.md`, add this paragraph near the PT-5 section:

```md
`Position Reference Source` 是 PT-5 的主 reference 入口。构建时会读取 `data/reference/position_reference_6064.txt`，按 `target.SampleTime` 把每一行解释成一个位置点，输出 `position_reference_6064` 和 `position_rate_reference_6064`。`position_command_6064` / `position_rate_command_6064` 继续作为进入 PT-5 的实际命令观测信号存在，但它们现在来自 reference source，而不是现场手动改位置命令参数。`SGV2_POSITION_LOOP_ENABLED` 不再暴露为可调参数，位置环请求内部固定开启，实际运动仍由 `ready_to_run` 和限速门禁保护。
```

- [ ] **Step 6: Run docs test and verify GREEN**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_documentContracts.m'); disp(table(results)); assertSuccess(results);"
```

Expected: PASS for documentation contracts.

- [ ] **Step 7: Commit Task 5**

Run:

```powershell
git add matlab/tests/test_documentContracts.m docs/reference/speedgoat_v2_signal_parameter_reference.md docs/field_validation/speedgoat_v2_position_tuning.md SPEEDGOAT_V2_MINIMAL_LOGIC.md
git commit -m "docs: describe txt position reference workflow"
```

## Task 6: Focused Regression And Application Build

**Files:**
- Test: `matlab/tests/test_positionReferenceTxt.m`
- Test: `matlab/tests/test_targetConfig.m`
- Test: `matlab/tests/test_modelGeneration.m`
- Test: `matlab/tests/test_task5CommandCompatibility.m`
- Test: `matlab/tests/test_documentContracts.m`

- [ ] **Step 1: Run the focused regression**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests({'tests/test_positionReferenceTxt.m','tests/test_targetConfig.m','tests/test_modelGeneration.m','tests/test_task5CommandCompatibility.m','tests/test_documentContracts.m'}); disp(table(results)); assertSuccess(results);"
```

Expected: all focused tests pass.

- [ ] **Step 2: Run full MATLAB test suite**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests'); disp(table(results)); assertSuccess(results);"
```

Expected: all tests pass. If unrelated Simulink Real-Time dependencies fail locally, capture the exact failure and still keep the focused non-packaging tests green.

- [ ] **Step 3: Build the application package**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); appPath = build_speedgoat_v2_minimal_app(); disp(appPath);"
```

Expected: `matlab/speedgoat_v2_minimal.mldatx` and `matlab/model/speedgoat_v2_minimal.mldatx` are regenerated.

- [ ] **Step 4: Inspect generated model signals**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); target = target_minimal_slrtexplorer(); build_speedgoat_v2_minimal(); load_system(char(target.GeneratedModelFile)); names = {'Position Reference Source','position_reference_6064','position_rate_reference_6064','position_actual_6064','position_loop_enabled'}; for k = 1:numel(names); assert(getSimulinkBlockHandle([char(target.ModelName) '/' names{k}]) > 0, names{k}); end; close_system(char(target.ModelName), 0);"
```

Expected: command completes without assertion failure.

- [ ] **Step 5: Commit final generated artifacts only if changed intentionally**

Run:

```powershell
git status --short
```

If generated `.slx` or `.mldatx` files changed and the repository normally tracks them, stage them with the implementation files:

```powershell
git add matlab/model/models/speedgoat_v2_minimal.slx matlab/speedgoat_v2_minimal.mldatx matlab/model/speedgoat_v2_minimal.mldatx
git commit -m "build: refresh position reference application"
```

If generated binary artifacts are not changed or are not meant to be committed, leave them unstaged and record that in the final answer.

## Plan Self-Review

### Spec Coverage

- One-column txt input is covered by Task 1 and the default `data/reference/position_reference_6064.txt`.
- Internal `target.SampleTime` interpretation and finite-difference rate are covered by Task 1.
- Runtime zero after the final sample is covered by Task 1 and Task 3.
- Feedforward enable tunable is covered by Tasks 2, 3, and 4.
- PT-5 integration through existing position command/rate ports is covered by Task 3.
- Removal of operator-facing `SGV2_POSITION_LOOP_ENABLED` is covered by Tasks 2, 3, 4, and 5.
- Data Inspector reference/actual visibility is covered by Tasks 3 and 5.
- Application package behavior is covered by Task 4 and Task 6.

### Placeholder Scan

- No `TBD`, `TODO`, “implement later”, or “similar to Task N” placeholders remain.
- Each task names exact files, concrete commands, and expected outcomes.

### Type Consistency

- Position reference values stay `int32`.
- Rate reference values stay `int32`.
- Feedforward enable stays `int32`.
- Sample index/count stay `uint32`.
- Existing PT-5 input order remains 14 ports, with port 5 supplied by a fixed root enable constant.
