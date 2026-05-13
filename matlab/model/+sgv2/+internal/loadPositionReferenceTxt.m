function reference = loadPositionReferenceTxt(target)
referencePath = localResolveReferencePath(target);

if ~isfile(referencePath)
    error('sgv2:PositionReferenceFileMissing', ...
        'Position reference file does not exist: %s', referencePath);
end

text = strtrim(fileread(referencePath));
if strlength(string(text)) == 0
    error('sgv2:PositionReferenceFileEmpty', ...
        'Position reference file is empty: %s', referencePath);
end

try
    values = readmatrix(referencePath, 'FileType', 'text');
catch ME
    error('sgv2:PositionReferenceFileInvalid', ...
        'Could not parse position reference file %s: %s', referencePath, ME.message);
end

if isempty(values) || ~isnumeric(values) || size(values, 2) ~= 1 || ...
        any(~isfinite(values(:)))
    error('sgv2:PositionReferenceFileInvalid', ...
        'Position reference file must contain exactly one finite numeric column: %s', referencePath);
end

if any(values(:) < double(intmin('int32'))) || any(values(:) > double(intmax('int32')))
    error('sgv2:PositionReferenceFileInvalid', ...
        'Position reference values must fit int32: %s', referencePath);
end

sampleTime = double(target.SampleTime);
if ~isfinite(sampleTime) || sampleTime <= 0
    error('sgv2:PositionReferenceSampleTimeInvalid', ...
        'Target sample time must be positive and finite.');
end

positionValues = int32(round(values(:)));
positionValues = [positionValues; int32(0)];

rateValues = zeros(size(positionValues), 'int32');
if numel(positionValues) > 2
    positionDelta = double(positionValues(2:end-1)) - double(positionValues(1:end-2));
    rateValues(2:end-1) = int32(round(positionDelta ./ sampleTime));
end

reference = struct( ...
    'FilePath', string(referencePath), ...
    'SampleTime', sampleTime, ...
    'PositionValues6064', positionValues, ...
    'RateValues6064', rateValues, ...
    'SampleCount', uint32(numel(positionValues)), ...
    'PositionVariableName', "SGV2_POSITION_REFERENCE_VALUES_6064", ...
    'RateVariableName', "SGV2_POSITION_RATE_REFERENCE_VALUES_6064", ...
    'CountVariableName', "SGV2_POSITION_REFERENCE_SAMPLE_COUNT");
end

function referencePath = localResolveReferencePath(target)
if isfield(target.AxisConfig, 'DefaultPositionReferenceFile')
    pathValue = string(target.AxisConfig.DefaultPositionReferenceFile);
else
    pathValue = "data/reference/position_reference_6064.txt";
end

if isfile(pathValue) || isfolder(fileparts(pathValue))
    referencePath = char(pathValue);
    return;
end

defaults = project_defaults();
referencePath = char(fullfile(defaults.ProjectRoot, pathValue));
end
