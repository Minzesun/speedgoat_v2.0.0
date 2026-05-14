# Simulink Chart Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generated Stateflow Chart blocks with Simulink-library-first subsystems plus small MATLAB Function blocks, preserving all external model behavior.

**Architecture:** Keep the existing generator entry points and subsystem interfaces stable. Add structural tests first, then change the two builder functions so they create ordinary Simulink blocks, visible signal paths, Unit Delay state, and approved MATLAB Function blocks instead of `sflib/Chart`.

**Tech Stack:** MATLAB R2021a, Simulink, MATLAB Function blocks, Simulink Real-Time target settings, MATLAB `functiontests`.

---

### Task 1: Lock the No-Chart Structure With Tests

**Files:**
- Modify: `matlab/tests/test_modelGeneration.m`

- [ ] **Step 1: Add failing structural assertions**

Add assertions to `testGeneratedModelShellAndCleanupBehavior` after the existing position-loop port count check:

```matlab
verifyFalse(testCase, getSimulinkBlockHandle([modelName '/SV660N Sequence Controller/StartupChart']) > 0);
verifyFalse(testCase, getSimulinkBlockHandle([modelName '/PT-5 Position Loop/PositionLoopChart']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/SV660N Sequence Controller/startup_decision']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/PT-5 Position Loop/pid_state_update']) > 0);

chartBlocks = find_system(modelName, ...
    'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', ...
    'ReferenceBlock', 'sflib/Chart');
verifyEmpty(testCase, chartBlocks);
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_modelGeneration.m'); assert(~all([results.Passed]));"
```

Expected: command exits successfully because at least one assertion fails against the current Chart-based model.

---

### Task 2: Replace StartupChart With a Simulink/MATLAB Function Subsystem

**Files:**
- Modify: `matlab/model/+sgv2/+internal/buildStartupChart.m`
- Modify: `matlab/model/+sgv2/+internal/buildFrameworkHarness.m`

- [ ] **Step 1: Replace chart construction**

Update `buildStartupChart.m` so it:

- Creates the same 8 Inports and 10 Outports.
- Adds a MATLAB Function block named `startup_decision`.
- Sets `startup_decision` script to the current priority logic.
- Builds visible `velocity_command_60ff` Switch, `mode_command_6060` Constant, `speed_limit_out_607f` pass-through, and `diag_lookup_hint` Multiport Switch network.
- Terminates unused `velocity_actual_606c` if it remains unused.

- [ ] **Step 2: Run the sequence harness**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_sequenceHarness.m'); assertSuccess(results);"
```

Expected: both bus-not-OP and ready-to-run harness cases pass.

---

### Task 3: Replace PositionLoopChart With a Simulink/MATLAB Function Subsystem

**Files:**
- Modify: `matlab/model/+sgv2/+internal/buildPositionLoopChart.m`

- [ ] **Step 1: Replace chart construction**

Update `buildPositionLoopChart.m` so it:

- Creates the same 14 Inports and 5 Outports.
- Builds a visible enable gate from `ready_to_run` and `position_loop_enabled_request`.
- Builds a visible position error branch.
- Builds a visible feedforward branch with gain protection, deadband, and speed limiting.
- Adds Unit Delay blocks for `integral_6064` and `previous_error_6064`.
- Adds MATLAB Function block `pid_state_update` for integral reset/update, derivative, and PID velocity.
- Builds visible final speed command summing, limiting, conversion, and disabled-zeroing.

- [ ] **Step 2: Run the model-generation structural test**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests('tests/test_modelGeneration.m'); assertSuccess(results);"
```

Expected: generated model has no `sflib/Chart` reference blocks and contains the approved MATLAB Function blocks.

---

### Task 4: Full Verification and Generated Artifact

**Files:**
- Generated: `matlab/model/models/speedgoat_v2_minimal.slx`

- [ ] **Step 1: Run focused tests**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); results = runtests({'tests/test_modelGeneration.m','tests/test_sequenceHarness.m','tests/test_positionLoop.m','tests/test_positionLoopGate.m'}); assertSuccess(results);"
```

Expected: focused tests pass.

- [ ] **Step 2: Regenerate the model**

Run:

```powershell
matlab -batch "cd('D:\Temporary_file\speedgoat_v2.0.0\matlab'); addpath(genpath(pwd)); modelPath = build_speedgoat_v2_minimal(); disp(modelPath);"
```

Expected: command exits with code 0 and writes `matlab/model/models/speedgoat_v2_minimal.slx`.

- [ ] **Step 3: Inspect git diff**

Run:

```powershell
git status --short
git diff --stat
```

Expected: changes are limited to tests, model builders, plan/spec/doc updates if needed, and the generated `.slx`.

---

## Self-Review

Spec coverage:

- Both Chart blocks are replaced by Tasks 2 and 3.
- Interface stability is verified by the existing model-generation test and retained port checks.
- Signal-flow readability is covered by the explicit builder layout requirements in Tasks 2 and 3.
- No-Chart acceptance is covered by Task 1 structural assertions.
- Behavior parity is covered by the existing sequence and position-loop tests in Tasks 2 through 4.

Placeholder scan:

- No placeholders, TODOs, or deferred implementation steps remain in this plan.

Type consistency:

- The named MATLAB Function blocks are `startup_decision` and `pid_state_update`.
- The removed Chart block names are `StartupChart` and `PositionLoopChart`.
- Existing subsystem and signal names remain unchanged.
