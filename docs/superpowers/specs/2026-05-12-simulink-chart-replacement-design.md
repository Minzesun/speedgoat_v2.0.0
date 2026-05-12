# Simulink Chart Replacement Design

Date: 2026-05-12

## Goal

Replace the current Stateflow Chart implementation in `speedgoat_v2_minimal` with a Simulink-library-first implementation while keeping all external behavior unchanged.

The generated model must preserve the existing top-level signal names, subsystem names, port order, data types, tunable parameters, and Speedgoat/SLRT build flow. The main change is internal implementation style: simple signal operations use standard Simulink blocks; logic that becomes hard to read as basic blocks uses MATLAB Function blocks.

## Scope

Replace both current charts:

- `SV660N Sequence Controller/StartupChart`
- `PT-5 Position Loop/PositionLoopChart`

Keep these interfaces unchanged:

- `SV660N Sequence Controller` inputs and outputs
- `PT-5 Position Loop` 14 inputs and 5 outputs
- Top-level `position_loop_speed_command_60ff_delay` Unit Delay
- Existing operator-facing signals and tunable parameters
- Existing helper functions such as `sgv2.statusState`, `sgv2.controlword`, and diagnostic ID helpers

No new control feature is added in this change.

## Implementation Strategy

Use a hybrid Simulink implementation.

Simple operations use Simulink library blocks:

- Inport and Outport blocks
- Constant blocks
- Sum, Gain, Product, Bias, Abs, MinMax, Saturation-style limit networks
- Relational Operator and Logical Operator blocks
- Switch and Multiport Switch blocks
- Data Type Conversion blocks
- Unit Delay blocks for discrete state

More complex priority logic uses MATLAB Function blocks:

- Startup decision priority and diagnostics
- Position PID state update where reset, integral limit, derivative, and output calculation need to stay readable

This avoids replacing Stateflow with one large opaque code block while also avoiding unreadable Simulink switch forests.

## Signal Flow Layout

Subsystems should be laid out to match the control block diagram as closely as practical.

Use a left-to-right signal flow. Inputs enter on the left, intermediate control branches occupy the middle, and outputs leave on the right. Related branches should stay vertically grouped.

### PT-5 Position Loop

The layout should expose the main control paths:

```text
position_command_6064 + position_actual_6064
    -> position_error_6064
    -> PID/state update
    -> position_pid_velocity_60ff

position_rate_command_6064
    -> inverse feedforward
    -> deadband
    -> tracking-speed limit
    -> position_ff_velocity_60ff

feedforward + PID
    -> final tracking-speed limit
    -> position_loop_speed_command_60ff

ready_to_run + position_loop_enabled_request
    -> enable gate
    -> position_loop_enabled
    -> PID state reset when disabled
```

The position error branch and feedforward branch should be visually separate before they combine.

### SV660N Sequence Controller

The layout should expose the startup and command paths:

```text
actual_network_state + expected_network_state
statusword_6041 + error_code_603f + mode_display_6061
    -> startup decision
    -> controlword_6040 / ready_to_run / diagnostics

speed_command_60ff
    -> passes through only when ready_to_run == 1
    -> velocity_command_60ff

speed_limit_607f
    -> speed_limit_out_607f

diag_message_id
    -> lookup selection
    -> diag_lookup_hint
```

The startup decision can be a MATLAB Function block, but the speed command path, speed limit path, and diagnostic lookup path should remain visible as Simulink signals around it.

## PT-5 Position Loop Details

Inputs remain:

1. `position_command_6064`
2. `position_rate_command_6064`
3. `position_actual_6064`
4. `ready_to_run`
5. `position_loop_enabled_request`
6. `position_loop_kp`
7. `position_loop_ki`
8. `position_loop_kd`
9. `position_loop_sample_time`
10. `position_loop_integrator_limit`
11. `position_velocity_gain`
12. `position_velocity_bias`
13. `command_deadband`
14. `max_tracking_speed`

Outputs remain:

1. `position_loop_speed_command_60ff`
2. `position_error_6064`
3. `position_ff_velocity_60ff`
4. `position_pid_velocity_60ff`
5. `position_loop_enabled`

Block-level implementation:

- Enable gate: compare `position_loop_enabled_request ~= 0`, compare `ready_to_run == 1`, combine with Logical Operator.
- Position error: subtract actual position from command position using Sum and convert/round as needed.
- Feedforward: subtract velocity bias, divide by velocity gain protected with a lower bound of `1`, apply deadband, and limit to `max_tracking_speed`.
- PID state: use Unit Delay blocks for `integral_6064` and `previous_error_6064`.
- PID update: use a MATLAB Function block to compute next integral, derivative, raw PID velocity, and reset state when disabled.
- Final command: add feedforward and PID velocity, limit to `max_tracking_speed`, round, convert to `int32`, and gate to zero when disabled.

The MATLAB Function block should be limited to the part that benefits from code-like readability. Feedforward and final limiting should stay visible as block networks unless implementation constraints make that unsafe.

## SV660N Sequence Controller Details

Inputs remain:

1. `actual_network_state`
2. `expected_network_state`
3. `statusword_6041`
4. `error_code_603f`
5. `mode_display_6061`
6. `velocity_actual_606c`
7. `speed_command_60ff`
8. `speed_limit_607f`

Outputs remain:

1. `controlword_6040`
2. `velocity_command_60ff`
3. `mode_command_6060`
4. `speed_limit_out_607f`
5. `ready_to_run`
6. `auto_start_step`
7. `diag_code`
8. `diag_message_id`
9. `diag_lookup_group`
10. `diag_lookup_hint`

Block-level implementation:

- `speed_limit_out_607f` passes through directly from `speed_limit_607f`.
- `mode_command_6060` is generated by a visible Constant block with value `int8(9)`.
- Startup priority logic lives in a MATLAB Function block that outputs:
  - `controlword_6040`
  - `ready_to_run`
  - `auto_start_step`
  - `diag_code`
  - `diag_message_id`
  - `diag_lookup_group`
- `velocity_command_60ff` uses a visible Switch controlled by `ready_to_run`, selecting `speed_command_60ff` when ready and zero otherwise.
- `diag_lookup_hint` keeps the existing Multiport Switch style lookup network driven by `diag_message_id`.

The startup MATLAB Function should preserve the current priority order:

1. EtherCAT state mismatch
2. `603Fh` error code nonzero
3. `6041h` fault state
4. Switch on disabled
5. Ready to switch on
6. Switched on
7. Operation enabled but mode mismatch
8. Operation enabled and CSV mode
9. Unsupported fallback state

## Generator Changes

The project should remain generator-driven.

Planned file-level changes:

- Replace `buildStartupChart.m` with a non-Stateflow startup subsystem builder.
- Replace `buildPositionLoopChart.m` with a non-Stateflow position loop subsystem builder.
- Update `addSequenceController.m` and `addPositionLoopController.m` to call the new builders.
- Keep wrapper names only if useful for compatibility, but they must no longer create `sflib/Chart` blocks or Stateflow objects.

The generated `.slx` should not contain `StartupChart`, `PositionLoopChart`, or any `Stateflow.Chart` objects.

## Testing

Verification should include:

- Existing MATLAB function tests for position loop command behavior.
- Existing sequence harness tests for startup and ready cases.
- Existing generated model shell test.
- New generated-model assertions that:
  - `StartupChart` does not exist.
  - `PositionLoopChart` does not exist.
  - The generated model contains no Stateflow Chart blocks.
  - The replacement subsystems still expose the same input and output port counts.
  - Expected MATLAB Function blocks exist only for the approved complex logic areas.

The final implementation should run:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
addpath(genpath(pwd));
runtests('tests');
build_speedgoat_v2_minimal();
```

If the local machine lacks a required Simulink Real-Time or Speedgoat dependency, record the exact failure and still run all tests that do not require that dependency.

## Acceptance Criteria

- Existing control behavior is unchanged.
- Generated model has no Stateflow Chart implementation.
- Simple signal paths are readable Simulink block networks.
- Complex decision/state update logic is contained in small MATLAB Function blocks.
- Internal subsystem layout follows the control signal flow so the model is readable when opened.
- Existing docs and tests remain consistent with the implementation.
