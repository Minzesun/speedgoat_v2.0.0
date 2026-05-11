function fit = fitIdentificationRelationship(capture)
requiredFields = { ...
    'Time', ...
    'SpeedCommand60FF', ...
    'VelocityActual606C', ...
    'PositionActual6064', ...
    'ReadyToRun', ...
    'Statusword6041', ...
    'ErrorCode603F', ...
    'Metadata'};

localRequireFields(capture, requiredFields);

time = double(capture.Time(:));
speedCommand = double(capture.SpeedCommand60FF(:));
positionActual = double(capture.PositionActual6064(:));
readyToRun = double(capture.ReadyToRun(:));
statusword = uint16(capture.Statusword6041(:));
errorCode = uint16(capture.ErrorCode603F(:));

localValidateVectorLengths(time, speedCommand, positionActual, readyToRun, statusword, errorCode);

if numel(time) < 2
    error('sgv2:analysis:TooShortCapture', 'Identification capture must contain at least two samples.');
end

timeDeltas = diff(time);
if any(timeDeltas <= 0)
    error('sgv2:analysis:NonMonotonicTime', 'Identification capture time must be strictly increasing.');
end

velocityFromPosition = [NaN; diff(positionActual) ./ timeDeltas];
faultMask = (errorCode ~= 0) | localIsFaultStatus(statusword);
transientGuardSamples = localGetMetadataScalar(capture.Metadata, 'IdentificationTransientGuardSamples', 0);
maxSpeedCommand = localGetMetadataScalar(capture.Metadata, 'IdentificationMaxSpeed60FF', inf);
maxTravel = localGetMetadataScalar(capture.Metadata, 'IdentificationMaxTravel6064', inf);

direction = sign(speedCommand);
transientMask = localBuildTransientMask(direction, transientGuardSamples);
travelOffset = abs(positionActual - positionActual(1));
speedEnvelopeMask = isfinite(maxSpeedCommand) & abs(speedCommand) > maxSpeedCommand;
travelEnvelopeMask = isfinite(maxTravel) & travelOffset > maxTravel;

validMask = readyToRun ~= 0 & ~faultMask & isfinite(velocityFromPosition) & speedCommand ~= 0 & ...
    ~transientMask & ~speedEnvelopeMask & ~travelEnvelopeMask;
usedIndex = find(validMask);

if numel(usedIndex) < 2
    error('sgv2:analysis:InsufficientSamples', 'Need at least two valid motion samples for a linear fit.');
end

x = speedCommand(usedIndex);
y = velocityFromPosition(usedIndex);
design = [x, ones(size(x))];
coefficients = design \ y;
fitVelocity = design * coefficients;
residual = y - fitVelocity;
ssRes = sum(residual .^ 2);
ssTot = sum((y - mean(y)) .^ 2);
if ssTot == 0
    rSquared = 1;
else
    rSquared = 1 - (ssRes / ssTot);
end

fit = struct( ...
    'ModelName', "velocity_from_speed_command", ...
    'K_cmd', coefficients(1), ...
    'B_cmd', coefficients(2), ...
    'RSquared', rSquared, ...
    'SampleCount', uint32(numel(usedIndex)), ...
    'UsedSampleIndex', uint32(usedIndex), ...
    'VelocityFromPosition6064', velocityFromPosition, ...
    'Selection', struct( ...
        'TransientGuardSamples', uint32(transientGuardSamples), ...
        'MaxSpeedCommand60FF', maxSpeedCommand, ...
        'MaxTravel6064', maxTravel, ...
        'ReadyMask', readyToRun ~= 0, ...
        'FaultFreeMask', ~faultMask, ...
        'TransientMask', transientMask, ...
        'SpeedEnvelopeMask', speedEnvelopeMask, ...
        'TravelEnvelopeMask', travelEnvelopeMask, ...
        'ValidMask', validMask), ...
    'Metadata', capture.Metadata);
end

function localRequireFields(value, requiredFields)
for k = 1:numel(requiredFields)
    fieldName = requiredFields{k};
    if ~isfield(value, fieldName)
        error('sgv2:analysis:MissingField', 'Missing required field: %s.', fieldName);
    end
end
end

function localValidateVectorLengths(time, speedCommand, positionActual, readyToRun, statusword, errorCode)
expectedLength = numel(time);
vectorLengths = [numel(speedCommand), numel(positionActual), numel(readyToRun), numel(statusword), numel(errorCode)];
if any(vectorLengths ~= expectedLength)
    error('sgv2:analysis:LengthMismatch', 'Identification capture vectors must share the same length.');
end
end

function isFault = localIsFaultStatus(statusword)
isFault = bitand(statusword, uint16(hex2dec('004F'))) == uint16(hex2dec('0008'));
end

function scalar = localGetMetadataScalar(metadata, fieldName, defaultValue)
scalar = defaultValue;
if isfield(metadata, fieldName)
    value = metadata.(fieldName);
    if ~isempty(value)
        scalar = double(value(1));
    end
end
end

function transientMask = localBuildTransientMask(direction, transientGuardSamples)
count = numel(direction);
transientMask = false(count, 1);
guard = max(0, floor(double(transientGuardSamples)));
if guard == 0 || count < 2
    return;
end

for k = 2:count
    previousDirection = direction(k - 1);
    currentDirection = direction(k);
    if previousDirection ~= 0 && currentDirection ~= 0 && currentDirection ~= previousDirection
        stopIndex = min(count, k + guard);
        transientMask(k:stopIndex) = true;
    end
end
end
