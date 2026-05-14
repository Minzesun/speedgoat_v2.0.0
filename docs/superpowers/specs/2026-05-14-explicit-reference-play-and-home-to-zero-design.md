# Explicit Reference Play And Home To Zero Design

Date: 2026-05-14

## Goal

Improve the PT-5 position reference workflow so pressing Start only brings the drive to an enabled and ready state. Motion must begin only after the operator explicitly requests either txt reference playback or a ramped return to absolute zero.

This fixes the current field problem where `ready_to_run` starts consuming the txt trajectory before the operator has time to verify or tune `SGV2_POSITION_LOOP_KP/KI/KD`.

## Operator Contract

Add three slrtExplorer tunable parameters:

```text
SGV2_REFERENCE_PLAY_REQUEST = 0
SGV2_HOME_TO_ZERO_REQUEST = 0
SGV2_HOME_TO_ZERO_SPEED = 10
```

`SGV2_REFERENCE_PLAY_REQUEST` starts the normal txt reference path. `SGV2_HOME_TO_ZERO_REQUEST` starts a ramped move to absolute `position_reference_6064 = 0`. `SGV2_HOME_TO_ZERO_SPEED` is the requested ramp speed in the current position engineering-unit assumption, defaulting to `10 mm/s`.

The normal field sequence becomes:

1. Start the application and let the system reach `ready_to_run = 1`.
2. Confirm the machine remains still because both motion requests are `0`.
3. Tune or confirm `SGV2_POSITION_LOOP_KP/KI/KD`, feedforward, and return-to-zero speed.
4. Set `SGV2_REFERENCE_PLAY_REQUEST = 1` to play the txt trajectory, or set `SGV2_HOME_TO_ZERO_REQUEST = 1` to ramp to absolute zero.

## Reference Playback Behavior

When `ready_to_run = 0`, txt playback is inactive. `position_reference_6064` follows the current `position_actual_6064`, and `position_rate_reference_6064 = 0`.

When `ready_to_run = 1` and `SGV2_REFERENCE_PLAY_REQUEST = 0`, the drive may be enabled, but the reference remains parked on the current actual position with zero rate. No txt samples are consumed.

On the rising edge of `SGV2_REFERENCE_PLAY_REQUEST` while ready, the model locks the current `position_actual_6064` as the txt trajectory base and starts playback from the first txt row.

While `SGV2_REFERENCE_PLAY_REQUEST = 1`, playback continues through the txt trajectory. After the last row, the existing zero tail behavior remains: the relative txt reference returns to `0`, so the absolute command returns to the locked base position and holds there.

Setting `SGV2_REFERENCE_PLAY_REQUEST` back to `0` resets playback state. The next `0 -> 1` transition locks the then-current actual position and replays from the beginning.

## Home To Zero Behavior

`SGV2_HOME_TO_ZERO_REQUEST = 1` has priority over txt playback.

When home-to-zero starts while ready, the reference generator commands a monotonic ramp from the last emitted `position_reference_6064` toward absolute zero. If no prior reference has been emitted in the current ready period, it starts from the current `position_actual_6064`. The default speed is `10 mm/s`, converted through `PositionUnitMillimetersPerCount6064` and `target.SampleTime` into 6064-count steps.

The generated `position_rate_reference_6064` uses the sign required to move toward zero. Once the command reaches zero, both reference outputs hold:

```text
position_reference_6064 = 0
position_rate_reference_6064 = 0
```

If `ready_to_run` drops to `0`, home-to-zero state resets and the effective velocity command remains protected by the existing PT-5 and startup-controller gates.

## Priority And Safety

The reference source priority is:

1. Not ready: park on actual position, zero rate.
2. Home-to-zero request: ramp to absolute zero.
3. Reference play request: play txt trajectory.
4. Ready but no request: park on actual position, zero rate.

The feature reuses the existing PT-5 position loop, output limiting, one-sample command delay, `ready_to_run` gate, and startup controller. It does not change EtherCAT PDO mapping, CiA402 startup sequencing, or the CSV operating mode.

If both motion requests are `1`, home-to-zero wins because it is the more direct recovery action. Documentation must tell the operator to clear the txt play request before or after home-to-zero for clarity.

## Observability

Keep the existing operator-facing signals:

- `position_reference_6064`
- `position_rate_reference_6064`
- `position_command_6064`
- `position_rate_command_6064`
- `position_actual_6064`
- `position_error_6064`
- `position_loop_speed_command_60ff`
- `speed_command_60ff`
- `position_loop_enabled`

Add parameter documentation for:

- `SGV2_REFERENCE_PLAY_REQUEST`
- `SGV2_HOME_TO_ZERO_REQUEST`
- `SGV2_HOME_TO_ZERO_SPEED`

No additional top-level diagnostic signal is required for the first implementation because the active mode can be inferred from the two request parameters and the plotted reference. A future explicit `position_reference_mode` signal can be added if field use shows the two request parameters are not enough for operators.

## Testing

Add or update MATLAB tests for:

- ready without play request does not consume txt samples.
- `SGV2_REFERENCE_PLAY_REQUEST` rising edge starts txt playback from row 1.
- clearing and reasserting play request restarts playback from the current actual position.
- home-to-zero request has priority over txt playback.
- home-to-zero starts from the last emitted reference without a command jump.
- home-to-zero ramps positive actual position down toward absolute zero.
- home-to-zero ramps negative actual position up toward absolute zero.
- home-to-zero holds zero after arrival.
- target config exposes the three new tunables with conservative defaults.
- generated model contains the new Constant blocks wired into `Position Reference Source`.
- operator docs explain that Start does not start motion.

## Acceptance Criteria

- Pressing Start and reaching `ready_to_run = 1` does not start reference playback.
- The operator can tune position loop parameters before any trajectory samples are consumed.
- `SGV2_REFERENCE_PLAY_REQUEST = 1` starts the txt trajectory from the first row.
- `SGV2_HOME_TO_ZERO_REQUEST = 1` ramps the command to absolute zero at the configured speed.
- Home-to-zero wins if both requests are active.
- Existing PT-5 and startup-controller safety gates remain the only path to motor velocity output.
