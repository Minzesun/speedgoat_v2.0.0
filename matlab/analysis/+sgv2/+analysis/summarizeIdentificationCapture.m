function summary = summarizeIdentificationCapture(capture)
requiredFields = { ...
    'Time', ...
    'SpeedCommand60FF', ...
    'VelocityCommand60FF', ...
    'VelocityActual606C', ...
    'PositionActual6064', ...
    'ReadyToRun', ...
    'Statusword6041', ...
    'ErrorCode603F', ...
    'Metadata'};

localRequireFields(capture, requiredFields);

time = double(capture.Time(:));
speedCommand = int32(capture.SpeedCommand60FF(:));
velocityCommand = int32(capture.VelocityCommand60FF(:));
velocityActual = double(capture.VelocityActual606C(:));
positionActual = int32(capture.PositionActual6064(:));
readyToRun = double(capture.ReadyToRun(:));
statusword = uint16(capture.Statusword6041(:));
errorCode = uint16(capture.ErrorCode603F(:));

localValidateVectorLengths(time, speedCommand, velocityCommand, velocityActual, positionActual, readyToRun, statusword, errorCode);

if numel(time) < 2
    error('sgv2:analysis:TooShortCapture', 'Identification capture must contain at least two samples.');
end

timeDeltas = diff(time);
if any(timeDeltas <= 0)
    error('sgv2:analysis:NonMonotonicTime', 'Identification capture time must be strictly increasing.');
end

sampleTime = timeDeltas(1);
positionDelta = [int32(0); diff(positionActual)];
positionOffset = double(positionActual) - double(positionActual(1));
approxVelocityFromPosition = [0; diff(double(positionActual)) ./ timeDeltas];
velocityError = velocityActual - approxVelocityFromPosition;
maxTravel = int32(max(abs(positionOffset)));
maxSpeedCommand = int32(max(abs(double(speedCommand))));
readyFraction = mean(readyToRun ~= 0);
faultSeen = any(errorCode ~= 0) || any(localIsFaultStatus(statusword));

summary = struct( ...
    'SampleTime', sampleTime, ...
    'Duration', time(end) - time(1), ...
    'PositionDelta6064', positionDelta, ...
    'ApproxVelocityFromPosition6064', approxVelocityFromPosition, ...
    'VelocityError606C', velocityError, ...
    'MaxAbsTravel6064', maxTravel, ...
    'MaxAbsSpeedCommand60FF', maxSpeedCommand, ...
    'ReadyFraction', readyFraction, ...
    'FaultSeen', faultSeen, ...
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

function localValidateVectorLengths(time, speedCommand, velocityCommand, velocityActual, positionActual, readyToRun, statusword, errorCode)
expectedLength = numel(time);
vectorLengths = [numel(speedCommand), numel(velocityCommand), numel(velocityActual), numel(positionActual), numel(readyToRun), numel(statusword), numel(errorCode)];
if any(vectorLengths ~= expectedLength)
    error('sgv2:analysis:LengthMismatch', 'Identification capture vectors must share the same length.');
end
end

function isFault = localIsFaultStatus(statusword)
isFault = bitand(statusword, uint16(hex2dec('004F'))) == uint16(hex2dec('0008'));
end
