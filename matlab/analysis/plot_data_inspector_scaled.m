function [fig, plotted] = plot_data_inspector_scaled(exportPath, varargin)
%PLOT_DATA_INSPECTOR_SCALED Plot Simulink Data Inspector exports with count scaling.
%
%   plot_data_inspector_scaled(exportPath) reads a table-like export file,
%   rebuilds the time axis with 0.002 s sample time, divides plotted signal
%   values by 1000, and plots position-related numeric columns.
%
%   plot_data_inspector_scaled(exportPath, 'SignalNames', names) plots only
%   the requested columns.

parser = inputParser;
addRequired(parser, 'exportPath', @(value) ischar(value) || isstring(value));
addParameter(parser, 'SampleTime', 0.002, @(value) isnumeric(value) && isscalar(value) && isfinite(value) && value > 0);
addParameter(parser, 'ScaleDivisor', 1000, @(value) isnumeric(value) && isscalar(value) && isfinite(value) && value ~= 0);
addParameter(parser, 'SignalNames', string.empty(1, 0), @(value) ischar(value) || isstring(value) || iscellstr(value));
parse(parser, exportPath, varargin{:});

exportPath = char(parser.Results.exportPath);
sampleTime = double(parser.Results.SampleTime);
scaleDivisor = double(parser.Results.ScaleDivisor);
requestedNames = string(parser.Results.SignalNames);

if ~isfile(exportPath)
    error('sgv2:analysis:DataInspectorExportMissing', ...
        'Data Inspector export file does not exist: %s', exportPath);
end

data = readtable(exportPath, 'VariableNamingRule', 'preserve');
if height(data) < 1
    error('sgv2:analysis:DataInspectorExportEmpty', ...
        'Data Inspector export file has no samples: %s', exportPath);
end

variableNames = string(data.Properties.VariableNames);
selectedColumns = localSelectColumns(data, variableNames, requestedNames);
time = (0:(height(data) - 1))' .* sampleTime;

fig = figure('Name', 'Data Inspector Scaled Plot');
axesHandle = axes(fig);
hold(axesHandle, 'on');

scaledValues = zeros(height(data), numel(selectedColumns));
for k = 1:numel(selectedColumns)
    columnIndex = selectedColumns(k);
    scaledValues(:, k) = double(data{:, columnIndex}) ./ scaleDivisor;
    plot(axesHandle, time, scaledValues(:, k), ...
        'DisplayName', char(variableNames(columnIndex)));
end

grid(axesHandle, 'on');
xlabel(axesHandle, 'Time (s)');
ylabel(axesHandle, sprintf('Value / %.15g', scaleDivisor));
legend(axesHandle, 'Location', 'best', 'Interpreter', 'none');
hold(axesHandle, 'off');

plotted = struct( ...
    'Time', time, ...
    'SignalNames', variableNames(selectedColumns), ...
    'ScaledValues', scaledValues, ...
    'SampleTime', sampleTime, ...
    'ScaleDivisor', scaleDivisor);
end

function selectedColumns = localSelectColumns(data, variableNames, requestedNames)
if ~isempty(requestedNames)
    selectedColumns = zeros(1, numel(requestedNames));
    for k = 1:numel(requestedNames)
        matchIndex = localFindSignalIndex(variableNames, requestedNames(k));
        if isempty(matchIndex)
            error('sgv2:analysis:DataInspectorSignalMissing', ...
                'Requested signal was not found in the export: %s', requestedNames(k));
        end
        if ~isnumeric(data{:, matchIndex})
            error('sgv2:analysis:DataInspectorSignalNonNumeric', ...
                'Requested signal is not numeric: %s', requestedNames(k));
        end
        selectedColumns(k) = matchIndex;
    end
    return;
end

isNumeric = false(1, numel(variableNames));
for k = 1:numel(variableNames)
    isNumeric(k) = isnumeric(data{:, k});
end

lowerNames = lower(variableNames);
isTimeLike = lowerNames == "time" | contains(lowerNames, "time_s") | contains(lowerNames, "timestamp");
isPositionLike = contains(lowerNames, "position");

selectedColumns = find(isNumeric & ~isTimeLike & isPositionLike);
if isempty(selectedColumns)
    selectedColumns = find(isNumeric & ~isTimeLike);
end

if isempty(selectedColumns)
    error('sgv2:analysis:DataInspectorNoNumericSignals', ...
        'Data Inspector export does not contain numeric signal columns.');
end
end

function matchIndex = localFindSignalIndex(variableNames, requestedName)
matchIndex = find(variableNames == requestedName, 1);
if ~isempty(matchIndex)
    return;
end

decoratedPrefix = requestedName + ":";
matchIndex = find(startsWith(variableNames, decoratedPrefix), 1);
end
