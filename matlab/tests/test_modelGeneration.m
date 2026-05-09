function tests = test_modelGeneration
tests = functiontests(localfunctions);
end

function testGeneratedModelShellAndCleanupBehavior(testCase)
modelPath = build_speedgoat_v2_minimal();
target = target_minimal_slrtexplorer();

load_system(modelPath);
closeCleanup = onCleanup(@() close_system(char(target.ModelName), 0));
modelName = char(target.ModelName);

verifyEqual(testCase, get_param(modelName, 'SystemTargetFile'), 'slrealtime.tlc');
verifyEqual(testCase, get_param(modelName, 'FixedStep'), num2str(target.SampleTime));
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/EtherCAT Init']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/EtherCAT Get State']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/expected_network_state']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/SV660N Sequence Controller']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/speed_command_60ff']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/speed_limit_607f']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/Rx Position actual 6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_actual_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/diag_lookup_hint']) > 0);
clear closeCleanup;

tempRoot = tempname;
mkdir(tempRoot);
cleanup = onCleanup(@() rmdir(tempRoot, 's'));
target.GeneratedModelFile = string(fullfile(tempRoot, "speedgoat_v2_minimal.slx"));
target.PdoMap.Tx(1).BlockName = "Broken/Tx Block";

thrown = [];
try
    sgv2.internal.buildMinimalModel(target);
catch ME
    thrown = ME;
end

verifyNotEmpty(testCase, thrown);
verifyFalse(testCase, bdIsLoaded(char(target.ModelName)));
verifyFalse(testCase, isfile(char(target.GeneratedModelFile)));
clear cleanup;
end
