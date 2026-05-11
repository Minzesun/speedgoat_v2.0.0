function result = computeInverseFeedforward(positionRateRef6064, params)
positionRateRef = double(positionRateRef6064(:));

if ~localHasValidGain(params)
    result = localFallback(positionRateRef, "invalid_position_velocity_gain");
    return;
end

gain = double(params.PositionVelocityGain);
bias = double(params.PositionVelocityBias);
deadband = max(0, double(params.CommandDeadband));
maxSpeed = double(params.MaxTrackingSpeed);

if ~isfinite(maxSpeed) || maxSpeed <= 0
    result = localFallback(positionRateRef, "invalid_max_tracking_speed");
    return;
end

rawSpeed = (positionRateRef - bias) ./ gain;
deadbandMask = abs(rawSpeed) <= deadband;
deadbandedSpeed = rawSpeed;
deadbandedSpeed(deadbandMask) = 0;
limitedSpeed = min(max(deadbandedSpeed, -maxSpeed), maxSpeed);
limitedMask = limitedSpeed ~= deadbandedSpeed;

result = struct( ...
    'ModelValid', true, ...
    'RawSpeedFeedforward60FF', rawSpeed, ...
    'SpeedFeedforward60FF', int32(round(limitedSpeed)), ...
    'DeadbandMask', deadbandMask, ...
    'LimitedMask', limitedMask, ...
    'FallbackReason', "");
end

function isValid = localHasValidGain(params)
isValid = isstruct(params) && isfield(params, 'PositionVelocityGain') && ...
    isfield(params, 'PositionVelocityBias') && isfield(params, 'CommandDeadband') && ...
    isfield(params, 'MaxTrackingSpeed') && isfinite(double(params.PositionVelocityGain)) && ...
    double(params.PositionVelocityGain) ~= 0;
end

function result = localFallback(positionRateRef, reason)
zeroSpeed = zeros(size(positionRateRef), 'int32');
logicalMask = false(size(positionRateRef));

result = struct( ...
    'ModelValid', false, ...
    'RawSpeedFeedforward60FF', zeros(size(positionRateRef)), ...
    'SpeedFeedforward60FF', zeroSpeed, ...
    'DeadbandMask', logicalMask, ...
    'LimitedMask', logicalMask, ...
    'FallbackReason', reason);
end
