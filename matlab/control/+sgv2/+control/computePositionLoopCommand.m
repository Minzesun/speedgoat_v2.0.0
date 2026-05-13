function result = computePositionLoopCommand(positionCommand6064, varargin)
if nargin == 4
    positionActual6064 = varargin{1};
    params = varargin{2};
    state = varargin{3};
elseif nargin == 5
    positionActual6064 = varargin{2};
    params = varargin{3};
    state = varargin{4};
else
    error('sgv2:InvalidPositionLoopCommandArguments', ...
        'Expected position command, position actual, params, and state.');
end

positionCommand = double(positionCommand6064(:));
positionActual = double(positionActual6064(:));

if ~localHasValidParams(params)
    result = localFallback(positionCommand, "invalid_position_loop_params", false);
    return;
end

if ~isfield(params, 'PositionLoopEnabled') || ~logical(params.PositionLoopEnabled)
    result = localFallback(positionCommand, "position_loop_disabled", true);
    return;
end

sampleTime = double(params.PositionLoopSampleTime);
if ~isfinite(sampleTime) || sampleTime <= 0
    result = localFallback(positionCommand, "invalid_position_loop_sample_time", false);
    return;
end

kp = double(params.PositionLoopKp);
ki = double(params.PositionLoopKi);
kd = double(params.PositionLoopKd);
integratorLimit = max(0, double(params.PositionLoopIntegratorLimit));
maxSpeed = double(params.MaxTrackingSpeed);

if ~isfinite(maxSpeed) || maxSpeed <= 0
    result = localFallback(positionCommand, "invalid_max_tracking_speed", false);
    return;
end

error6064 = positionCommand - positionActual;
integral6064 = localStateValue(state, 'Integral6064', zeros(size(error6064)));
previousError6064 = localStateValue(state, 'PreviousError6064', error6064);

integral6064Next = integral6064 + ki .* error6064 .* sampleTime;
integral6064Next = min(max(integral6064Next, -integratorLimit), integratorLimit);
derivative6064 = (error6064 - previousError6064) ./ sampleTime;
rawPidVelocity60FF = kp .* error6064 + integral6064Next + kd .* derivative6064;
limitedSpeedCommand60FF = min(max(rawPidVelocity60FF, -maxSpeed), maxSpeed);
limitedMask = limitedSpeedCommand60FF ~= rawPidVelocity60FF;
zeroSpeed = int32(zeros(size(positionCommand)));

result = struct( ...
    'ModelValid', true, ...
    'Enabled', true, ...
    'PositionError6064', int32(round(error6064)), ...
    'RawPositionPidVelocity60FF', rawPidVelocity60FF, ...
    'PositionPidVelocity60FF', int32(round(rawPidVelocity60FF)), ...
    'PositionFeedforwardVelocity60FF', zeroSpeed, ...
    'SpeedCommand60FF', int32(round(limitedSpeedCommand60FF)), ...
    'Integrator6064Next', integral6064Next, ...
    'PreviousError6064Next', error6064, ...
    'LimitedMask', limitedMask, ...
    'FallbackReason', "");
end

function isValid = localHasValidParams(params)
isValid = isstruct(params) && ...
    isfield(params, 'PositionLoopEnabled') && ...
    isfield(params, 'PositionLoopKp') && ...
    isfield(params, 'PositionLoopKi') && ...
    isfield(params, 'PositionLoopKd') && ...
    isfield(params, 'PositionLoopSampleTime') && ...
    isfield(params, 'PositionLoopIntegratorLimit') && ...
    isfield(params, 'MaxTrackingSpeed');
end

function value = localStateValue(state, fieldName, defaultValue)
if isstruct(state) && isfield(state, fieldName)
    value = double(state.(fieldName));
else
    value = double(defaultValue);
end
end

function result = localFallback(positionCommand, reason, enabled)
zeroSpeed = int32(zeros(size(positionCommand)));
logicalMask = false(size(positionCommand));

result = struct( ...
    'ModelValid', false, ...
    'Enabled', enabled, ...
    'PositionError6064', int32(zeros(size(positionCommand))), ...
    'RawPositionPidVelocity60FF', zeros(size(positionCommand)), ...
    'PositionPidVelocity60FF', zeroSpeed, ...
    'PositionFeedforwardVelocity60FF', zeroSpeed, ...
    'SpeedCommand60FF', zeroSpeed, ...
    'Integrator6064Next', zeros(size(positionCommand)), ...
    'PreviousError6064Next', zeros(size(positionCommand)), ...
    'LimitedMask', logicalMask, ...
    'FallbackReason', reason);
end
