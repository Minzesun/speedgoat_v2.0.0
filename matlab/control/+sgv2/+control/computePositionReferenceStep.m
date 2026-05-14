function result = computePositionReferenceStep(positionValues6064, rateValues6064, feedforwardEnabled, readyToRun, positionActual6064, referencePlayRequest, homeToZeroRequest, homeToZeroSpeed, sampleTime, positionUnitMillimetersPerCount6064, state)
positionValues = int32(positionValues6064(:));
rateValues = int32(rateValues6064(:));
count = min(numel(positionValues), numel(rateValues));

ready = uint8(readyToRun) == uint8(1);
actual = int32(positionActual6064);
playRequested = int32(referencePlayRequest) ~= int32(0);
homeRequested = int32(homeToZeroRequest) ~= int32(0);

sampleIndex = localStateValue(state, 'SampleIndex', 1);
basePosition = int32(localStateValue(state, 'BasePosition6064', actual));
wasReady = localStateLogical(state, 'WasReady', false);
wasPlayRequested = localStateLogical(state, 'WasPlayRequested', false);
lastReference = int32(localStateValue(state, 'LastReference6064', actual));
hasReference = localStateLogical(state, 'HasReference', false);

if ~ready
    result = localResult(actual, int32(0), 1, actual, false, false, actual, false);
    return;
end

if homeRequested
    if hasReference
        startReference = lastReference;
    else
        startReference = actual;
    end
    [positionReference, rateReference] = localHomeToZeroStep( ...
        startReference, homeToZeroSpeed, sampleTime, positionUnitMillimetersPerCount6064);
    result = localResult(positionReference, rateReference, sampleIndex, basePosition, ...
        true, playRequested, positionReference, true);
    return;
end

if count < 1 || ~playRequested
    result = localResult(actual, int32(0), 1, actual, true, false, actual, true);
    return;
end

if ~wasReady || ~wasPlayRequested
    basePosition = actual;
    sampleIndex = 1;
end

idx = round(double(sampleIndex));
if idx < 1
    idx = 1;
end

if idx > count
    relativePosition = int32(0);
    rawRate = int32(0);
else
    relativePosition = positionValues(idx);
    rawRate = rateValues(idx);
end

positionReference = int32(double(basePosition) + double(relativePosition));
if int32(feedforwardEnabled) ~= int32(0)
    rateReference = rawRate;
else
    rateReference = int32(0);
end

if idx < count
    nextIndex = idx + 1;
else
    nextIndex = count + 1;
end

result = localResult(positionReference, rateReference, nextIndex, basePosition, ...
    true, true, positionReference, true);
end

function [positionReference, rateReference] = localHomeToZeroStep(startReference, homeToZeroSpeed, sampleTime, positionUnitMillimetersPerCount6064)
sampleTimeValue = double(sampleTime);
unitValue = double(positionUnitMillimetersPerCount6064);
speedValue = abs(double(homeToZeroSpeed));

if ~isfinite(sampleTimeValue) || sampleTimeValue <= 0 || ...
        ~isfinite(unitValue) || unitValue <= 0 || ...
        ~isfinite(speedValue) || speedValue <= 0
    positionReference = int32(startReference);
    rateReference = int32(0);
    return;
end

stepCounts = max(1, round(speedValue * sampleTimeValue / unitValue));
startValue = double(startReference);

if startValue > 0
    nextValue = max(0, startValue - stepCounts);
elseif startValue < 0
    nextValue = min(0, startValue + stepCounts);
else
    nextValue = 0;
end

positionReference = int32(round(nextValue));
if nextValue == 0
    rateReference = int32(0);
elseif startValue > 0
    rateReference = int32(round(-stepCounts / sampleTimeValue));
else
    rateReference = int32(round(stepCounts / sampleTimeValue));
end
end

function value = localStateValue(state, fieldName, defaultValue)
if isstruct(state) && isfield(state, fieldName)
    value = double(state.(fieldName));
else
    value = double(defaultValue);
end
end

function value = localStateLogical(state, fieldName, defaultValue)
if isstruct(state) && isfield(state, fieldName)
    value = logical(state.(fieldName));
else
    value = logical(defaultValue);
end
end

function result = localResult(positionReference, rateReference, sampleIndexNext, basePositionNext, wasReadyNext, wasPlayRequestedNext, lastReferenceNext, hasReferenceNext)
result = struct( ...
    'PositionReference6064', int32(positionReference), ...
    'RateReference6064', int32(rateReference), ...
    'SampleIndexNext', double(sampleIndexNext), ...
    'BasePosition6064Next', int32(basePositionNext), ...
    'WasReadyNext', logical(wasReadyNext), ...
    'WasPlayRequestedNext', logical(wasPlayRequestedNext), ...
    'LastReference6064Next', int32(lastReferenceNext), ...
    'HasReferenceNext', logical(hasReferenceNext));
end
