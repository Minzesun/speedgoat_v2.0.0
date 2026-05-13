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
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/PT-5 Position Loop']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/Position Reference Source']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/speed_command_60ff']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/speed_limit_607f']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_reference_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_rate_reference_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_reference_values_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_rate_reference_values_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_reference_feedforward_enabled']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_command_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_rate_command_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_loop_enabled_request']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_loop_kp']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_loop_ki']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_loop_kd']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/max_tracking_speed']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_loop_speed_command_60ff_delay']) > 0);
verifyEqual(testCase, get_param([modelName '/position_reference_feedforward_enabled'], 'Value'), ...
    char(target.Tunables.PositionReferenceFeedforwardEnabled));
verifyNotEqual(testCase, get_param([modelName '/position_command_6064'], 'BlockType'), 'Constant');
verifyNotEqual(testCase, get_param([modelName '/position_rate_command_6064'], 'BlockType'), 'Constant');
verifyEqual(testCase, get_param([modelName '/position_loop_enabled_request'], 'BlockType'), 'Constant');
verifyEqual(testCase, get_param([modelName '/position_loop_kp'], 'BlockType'), 'Constant');
verifyEqual(testCase, get_param([modelName '/position_loop_ki'], 'BlockType'), 'Constant');
verifyEqual(testCase, get_param([modelName '/position_loop_kd'], 'BlockType'), 'Constant');
verifyEqual(testCase, get_param([modelName '/max_tracking_speed'], 'BlockType'), 'Constant');
verifyEqual(testCase, get_param([modelName '/position_loop_speed_command_60ff_delay'], 'BlockType'), 'UnitDelay');
verifyEqual(testCase, get_param([modelName '/position_loop_enabled_request'], 'Value'), 'int32(1)');
verifyEqual(testCase, get_param([modelName '/position_loop_kp'], 'Value'), char(target.Tunables.PositionLoopKp));
verifyEqual(testCase, get_param([modelName '/position_loop_ki'], 'Value'), char(target.Tunables.PositionLoopKi));
verifyEqual(testCase, get_param([modelName '/position_loop_kd'], 'Value'), char(target.Tunables.PositionLoopKd));
verifyEqual(testCase, get_param([modelName '/max_tracking_speed'], 'Value'), char(target.Tunables.MaxTrackingSpeed));
verifyEqual(testCase, get_param([modelName '/position_loop_speed_command_60ff_delay'], 'SampleTime'), num2str(target.SampleTime));
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_loop_speed_command_60ff']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_error_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_ff_velocity_60ff']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_pid_velocity_60ff']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_loop_enabled']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/Rx Position actual 6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/position_actual_6064']) > 0);
verifyTrue(testCase, getSimulinkBlockHandle([modelName '/diag_lookup_hint']) > 0);

positionLoopHandles = get_param([modelName '/PT-5 Position Loop'], 'PortHandles');
verifyEqual(testCase, numel(positionLoopHandles.Inport), 14);
verifyFalse(testCase, getSimulinkBlockHandle([modelName '/PT-5 Position Loop/position_loop_enabled_request_constant']) > 0);
verifyFalse(testCase, getSimulinkBlockHandle([modelName '/PT-5 Position Loop/position_loop_kp_constant']) > 0);
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
