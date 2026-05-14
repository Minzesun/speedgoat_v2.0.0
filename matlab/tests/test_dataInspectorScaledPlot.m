function tests = test_dataInspectorScaledPlot
tests = functiontests(localfunctions);
end

function testPlotsSelectedSignalsWithGeneratedTimeAndScaledCounts(testCase)
tempRoot = tempname;
mkdir(tempRoot);
cleanup = onCleanup(@() rmdir(tempRoot, 's')); %#ok<NASGU>
exportPath = fullfile(tempRoot, 'data_inspector_export.csv');

data = table( ...
    [10; 20; 30], ...
    int32([0; 1000; -1000]), ...
    int32([100; 200; 300]), ...
    'VariableNames', {'Time', 'position_reference_6064:1', 'speed_command_60ff'});
writetable(data, exportPath);

[fig, plotted] = plot_data_inspector_scaled(exportPath, ...
    'SignalNames', "position_reference_6064");
close(fig);

verifyEqual(testCase, plotted.Time, [0; 0.002; 0.004], 'AbsTol', 1e-12);
verifyEqual(testCase, plotted.SignalNames, "position_reference_6064:1");
verifyEqual(testCase, plotted.ScaledValues, [0; 1; -1], 'AbsTol', 1e-12);
verifyEqual(testCase, plotted.SampleTime, 0.002);
verifyEqual(testCase, plotted.ScaleDivisor, 1000);
end
