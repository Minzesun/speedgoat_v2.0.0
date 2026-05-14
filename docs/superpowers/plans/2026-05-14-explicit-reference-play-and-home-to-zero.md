# Explicit Reference Play And Home To Zero Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit txt playback and ramped home-to-zero requests so Start only enables the drive and never consumes trajectory samples by itself.

**Architecture:** Extend `computePositionReferenceStep` to accept play/home requests, home speed, sample time, and position unit scaling. Wire three new slrtExplorer tunables into `Position Reference Source` and seed their model workspace defaults. Keep all motor output protection in the existing PT-5 and startup-controller path.

**Tech Stack:** MATLAB function tests, Simulink model generation scripts, Simulink Real-Time tunable parameters, project Markdown docs.

---

## File Map

- Modify `matlab/tests/test_positionReferenceStep.m`: add red tests for explicit play gating and home-to-zero ramp behavior.
- Modify `matlab/control/+sgv2/+control/computePositionReferenceStep.m`: implement new state machine behavior in pure MATLAB.
- Modify `matlab/tests/test_targetConfig.m`: require three new tunables and defaults.
- Modify `matlab/config/axes/sv660n_axis1.m`: add default request and speed values.
- Modify `matlab/config/target_minimal_slrtexplorer.m`: expose new slrtExplorer parameter names.
- Modify `matlab/model/+sgv2/+internal/buildMinimalModel.m`: seed model workspace defaults.
- Modify `matlab/model/+sgv2/+internal/addPositionReferenceSource.m`: add Constant blocks, subsystem inputs, delays, and MATLAB Function arguments.
- Modify `matlab/tests/test_modelGeneration.m`: verify new Constant blocks exist and use the expected tunables.
- Modify `docs/field_validation/speedgoat_v2_position_tuning.md`: document the new Start, play, and home-to-zero field sequence.
- Modify `docs/reference/speedgoat_v2_signal_parameter_reference.md`: document the three new tunables.
- Modify `matlab/tests/test_documentContracts.m`: require operator docs to mention the new workflow.

## Task 1: Pure MATLAB Reference Behavior

**Files:**
- Modify: `matlab/tests/test_positionReferenceStep.m`
- Modify: `matlab/control/+sgv2/+control/computePositionReferenceStep.m`

- [ ] **Step 1: Write failing tests for explicit play and home-to-zero**

Add tests that call:

```matlab
sgv2.control.computePositionReferenceStep( ...
    positionValues, rateValues, feedforwardEnabled, readyToRun, ...
    positionActual6064, referencePlayRequest, homeToZeroRequest, ...
    homeToZeroSpeed, sampleTime, positionUnitMillimetersPerCount6064, state)
```

Cover these expected behaviors:

- ready with play request `0` parks on actual and keeps `SampleIndexNext = 1`.
- play request `0 -> 1` starts row 1 and then advances.
- clearing play request resets playback and the next rising edge locks the new actual position.
- home request has priority over txt playback.
- positive position ramps down toward zero at `speed / unit * sampleTime` counts per sample.
- negative position ramps up toward zero.
- zero arrival clamps at `0` and emits zero rate.

- [ ] **Step 2: Run the test and verify red**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_positionReferenceStep.m'); disp(table(results)); assert(any([results.Failed]), 'Expected new reference-step tests to fail before implementation.');"
```

Expected: failure because the function signature and behavior do not yet support play/home requests.

- [ ] **Step 3: Implement minimal reference state machine**

Update `computePositionReferenceStep` to:

- accept the six new inputs.
- track `WasPlayRequested`, `LastReference6064`, and `HasReference` in `state`.
- park on actual when not ready or no request is active.
- start txt playback only on `referencePlayRequest` rising edge.
- ramp toward absolute zero when `homeToZeroRequest ~= 0`.
- return new state fields in the result struct.

- [ ] **Step 4: Run the pure MATLAB tests and verify green**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_positionReferenceStep.m'); disp(table(results)); assert(all([results.Passed]), 'Expected position reference step tests to pass.');"
```

Expected: all `test_positionReferenceStep` tests pass.

## Task 2: Target Config Tunables

**Files:**
- Modify: `matlab/tests/test_targetConfig.m`
- Modify: `matlab/config/axes/sv660n_axis1.m`
- Modify: `matlab/config/target_minimal_slrtexplorer.m`

- [ ] **Step 1: Write failing config assertions**

Require:

```matlab
DefaultReferencePlayRequest = int32(0)
DefaultHomeToZeroRequest = int32(0)
DefaultHomeToZeroSpeed = int32(10)
ReferencePlayRequest = "SGV2_REFERENCE_PLAY_REQUEST"
HomeToZeroRequest = "SGV2_HOME_TO_ZERO_REQUEST"
HomeToZeroSpeed = "SGV2_HOME_TO_ZERO_SPEED"
```

- [ ] **Step 2: Run config test and verify red**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_targetConfig.m'); disp(table(results)); assert(any([results.Failed]), 'Expected target config tests to fail before tunables exist.');"
```

- [ ] **Step 3: Add the config fields**

Add defaults to `sv660n_axis1.m` and tunable names to `target_minimal_slrtexplorer.m`, keeping field order close to existing reference tunables.

- [ ] **Step 4: Run config test and verify green**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_targetConfig.m'); disp(table(results)); assert(all([results.Passed]), 'Expected target config tests to pass.');"
```

## Task 3: Simulink Reference Source Wiring

**Files:**
- Modify: `matlab/tests/test_modelGeneration.m`
- Modify: `matlab/model/+sgv2/+internal/buildMinimalModel.m`
- Modify: `matlab/model/+sgv2/+internal/addPositionReferenceSource.m`

- [ ] **Step 1: Write failing model-generation assertions**

Require top-level Constant blocks:

```text
reference_play_request
home_to_zero_request
home_to_zero_speed
```

Each block must use the matching `target.Tunables.*` value.

- [ ] **Step 2: Run model-generation test and verify red**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_modelGeneration.m'); disp(table(results)); assert(any([results.Failed]), 'Expected model generation tests to fail before wiring exists.');"
```

- [ ] **Step 3: Seed and wire the new tunables**

In `buildMinimalModel.m`, assign the three new `Simulink.Parameter` defaults.

In `addPositionReferenceSource.m`, add Constant blocks and subsystem inputs for play request, home request, home speed, sample time, and position unit. Add Unit Delay state for play request, last reference, and has-reference. Pass all values into the MATLAB Function block.

- [ ] **Step 4: Run model-generation test and verify green**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_modelGeneration.m'); disp(table(results)); assert(all([results.Passed]), 'Expected model generation tests to pass.');"
```

## Task 4: Operator Documentation

**Files:**
- Modify: `matlab/tests/test_documentContracts.m`
- Modify: `docs/field_validation/speedgoat_v2_position_tuning.md`
- Modify: `docs/reference/speedgoat_v2_signal_parameter_reference.md`
- Optionally modify: `SPEEDGOAT_V2_MINIMAL_LOGIC.md`

- [ ] **Step 1: Write failing documentation assertions**

Require docs to contain:

```text
SGV2_REFERENCE_PLAY_REQUEST
SGV2_HOME_TO_ZERO_REQUEST
SGV2_HOME_TO_ZERO_SPEED
Start
ready_to_run = 1
```

- [ ] **Step 2: Run documentation test and verify red**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_documentContracts.m'); disp(table(results)); assert(any([results.Failed]), 'Expected docs tests to fail before docs are updated.');"
```

- [ ] **Step 3: Update operator docs**

Document that Start only enables the system, txt playback begins only after `SGV2_REFERENCE_PLAY_REQUEST = 1`, and home-to-zero begins only after `SGV2_HOME_TO_ZERO_REQUEST = 1` with default speed `10`.

- [ ] **Step 4: Run documentation test and verify green**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_documentContracts.m'); disp(table(results)); assert(all([results.Passed]), 'Expected document contract tests to pass.');"
```

## Task 5: Regression Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run focused regression tests**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests({'tests/test_positionReferenceStep.m','tests/test_targetConfig.m','tests/test_modelGeneration.m','tests/test_documentContracts.m'}); disp(table(results)); assert(all([results.Passed]), 'Expected explicit play/home-to-zero regression tests to pass.');"
```

- [ ] **Step 2: Run whitespace check**

Run:

```powershell
git diff --check
```

Expected: no new whitespace errors from this feature. Existing CRLF warnings may be reported by Git on this Windows workspace.
