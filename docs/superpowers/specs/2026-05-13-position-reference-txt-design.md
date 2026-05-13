# Position Reference Txt Design

Date: 2026-05-13

## Goal

Add a file-based position reference path to `speedgoat_v2_minimal` so the system position follows a reference trajectory supplied by the operator.

The operator provides a plain `.txt` file with one position value per line. The model interprets each row as one internal control step using `target.SampleTime`, generates the corresponding position and rate references, feeds them into the existing PT-5 position loop, and exposes the reference curves in slrtExplorer/Data Inspector together with the actual position.

## Reference File Contract

Default file path:

```text
data/reference/position_reference_6064.txt
```

The file contains one numeric position value per line:

```text
0
0
1
2
3
```

The file does not contain timestamps. The loader derives time from the model sample time:

```text
time[k] = (k - 1) * target.SampleTime
```

If `target.SampleTime` is `0.002`, the five-line example above means:

```text
0.000 s -> 0
0.002 s -> 0
0.004 s -> 1
0.006 s -> 2
0.008 s -> 3
```

After the last file row, the reference position outputs `0`. The generated rate reference also outputs `0`.

Invalid input is a build-time error. The loader must reject a missing file, an empty file, nonnumeric values, `NaN`, `Inf`, or data that cannot be represented as the model's reference signal type.

## Reference Source Behavior

Add a top-level `Position Reference Source` subsystem. It is responsible for producing:

- `position_reference_6064`
- `position_rate_reference_6064`

The subsystem receives its data from model workspace variables populated by a MATLAB loader during model generation. The loader converts the `.txt` vector into the workspace representation required by Simulink and appends a zero-output tail so the reference returns to zero after playback.

The rate reference is computed from adjacent position samples:

```text
position_rate_reference_6064[1] = 0
position_rate_reference_6064[k] = (position[k] - position[k - 1]) / target.SampleTime
```

The rate reference is rounded and limited consistently with the existing `int32` position-rate command path.

Add a tunable parameter:

```text
SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED
```

Behavior:

- `1`: `position_rate_reference_6064` uses the computed finite-difference rate.
- `0`: `position_rate_reference_6064` is forced to `0`.

Default value is `1`.

## PT-5 Integration

Keep the existing PT-5 position loop as the control owner. The new reference source replaces the old fixed position command source:

```text
position_reference_6064      -> PT-5 position_command_6064
position_rate_reference_6064 -> PT-5 position_rate_command_6064
```

The existing PT-5 PID, inverse feedforward, speed limiting, one-sample command delay, and `ready_to_run` gate remain in place.

The position loop enable parameter is removed from the operator-facing tunables:

```text
SGV2_POSITION_LOOP_ENABLED
```

The PT-5 enable request becomes an internal constant `1`. Actual enablement still depends on `ready_to_run` through the existing `computePositionLoopGate` behavior, so the loop does not command motion until the startup controller says the system is ready.

`position_command_6064` remains visible as the actual position command entering PT-5. Its value is equal to `position_reference_6064`. `position_rate_command_6064` remains visible as the actual rate command entering PT-5. Its value is equal to the selected rate reference after the feedforward enable switch.

## Observability

Expose these signals at top level so slrtExplorer/Data Inspector can plot the reference against actual motion:

- `position_reference_6064`
- `position_rate_reference_6064`
- `position_command_6064`
- `position_rate_command_6064`
- `position_actual_6064`
- `position_error_6064`
- `position_loop_enabled`
- `position_loop_speed_command_60ff`
- `speed_command_60ff`

The reference signals must be available without requiring the operator to infer them from tunable parameter values.

## Configuration Changes

Add axis defaults:

- `DefaultPositionReferenceFeedforwardEnabled = int32(1)`
- `DefaultPositionReferenceFile = "data/reference/position_reference_6064.txt"`

Add tunable:

- `PositionReferenceFeedforwardEnabled = "SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED"`

Remove operator-facing use of:

- `PositionLoopEnabled`
- `SGV2_POSITION_LOOP_ENABLED`

Implementation may keep internal helper fields briefly if needed for migration, but the final generated model and application package should not expose `SGV2_POSITION_LOOP_ENABLED` as a tunable parameter.

## Build Flow

`build_speedgoat_v2_minimal_app` remains the primary operator entry point.

During model generation:

1. Resolve the reference txt path relative to the project root unless an absolute path is provided.
2. Load and validate the one-column numeric reference.
3. Build time, position, and finite-difference rate vectors from `target.SampleTime`.
4. Seed model workspace variables for `Position Reference Source`.
5. Generate the model and application package.

Changing the `.txt` file requires rebuilding or regenerating the application package so the packaged application contains the updated reference data.

## Safety And Failure Handling

The model must fail fast during generation if the reference file is invalid. Silent fallback to zero is not acceptable for invalid operator input because it can hide a wrong or stale trajectory.

The runtime post-trajectory output is intentionally zero:

- position reference returns to `0`
- rate reference returns to `0`

The actual motor command remains protected by:

- `ready_to_run`
- existing PT-5 output limiting
- existing one-sample command delay into the startup controller
- existing startup controller command gate

## Documentation Updates

Update the operator-facing references and tuning runbook to state:

- The primary position reference is `data/reference/position_reference_6064.txt`.
- The file has one position point per line and no time column.
- The model uses internal `target.SampleTime` as the row interval.
- Playback returns reference to zero after the last row.
- Data Inspector should plot `position_reference_6064` with `position_actual_6064`.
- `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED` controls automatic velocity feedforward.
- `SGV2_POSITION_LOOP_ENABLED` is no longer a field parameter; the loop request is always on internally and actual enablement follows `ready_to_run`.

## Testing

Add or update tests for:

- txt loader accepts a one-column numeric file.
- txt loader derives time from `target.SampleTime`.
- txt loader appends or otherwise guarantees zero output after the last sample.
- txt loader computes finite-difference rate with first sample rate equal to zero.
- txt loader rejects missing, empty, nonnumeric, `NaN`, and `Inf` input.
- target config includes `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED`.
- target config no longer exposes `SGV2_POSITION_LOOP_ENABLED` as an operator tunable.
- generated model contains `Position Reference Source`.
- generated model exposes `position_reference_6064` and `position_rate_reference_6064`.
- generated model wires reference outputs into PT-5 command inputs.
- application package contains `SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED`.
- application package does not contain `SGV2_POSITION_LOOP_ENABLED`.

The final implementation should run:

```matlab
cd('D:\Temporary_file\speedgoat_v2.0.0\matlab');
addpath(genpath(pwd));
runtests('tests');
build_speedgoat_v2_minimal_app();
```

If local Speedgoat or Simulink Real-Time dependencies prevent packaging, record the exact failure and still run all tests that do not require those dependencies.

## Acceptance Criteria

- The operator can provide a one-column `.txt` position reference.
- The model interprets the reference using internal sample time, not file timestamps.
- The system position loop follows the reference path through existing PT-5 control logic.
- The reference position and rate are visible in slrtExplorer/Data Inspector.
- Reference playback returns to zero after the last sample.
- Automatic rate feedforward is enabled by default and can be disabled with one tunable.
- Position loop enable is no longer an operator tunable; the loop request is internal and always on.
- `ready_to_run` remains the effective safety gate for motion commands.
