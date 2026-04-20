function tests = test_sequenceHarness
tests = functiontests(localfunctions);
end

function testSequenceHarnessStartupAndReadyCases(testCase)
modelName = sgv2.internal.buildFrameworkHarness();
in = Simulink.SimulationInput(modelName);
in = in.setVariable('network_state_ts', timeseries(int32([1 1]), [0 0.05]));
in = in.setVariable('statusword_ts', timeseries(uint16([hex2dec('0040') hex2dec('0040')]), [0 0.05]));
in = in.setVariable('error_code_ts', timeseries(uint16([0 0]), [0 0.05]));
in = in.setVariable('mode_display_ts', timeseries(int8([9 9]), [0 0.05]));
in = in.setVariable('velocity_actual_ts', timeseries(int32([0 0]), [0 0.05]));
in = in.setVariable('speed_command_ts', timeseries(int32([120 120]), [0 0.05]));
in = in.setVariable('speed_limit_ts', timeseries(uint32([1000 1000]), [0 0.05]));
out = sim(in);

verifyEqual(testCase, out.logsout.get('ready_to_run').Values.Data(end), uint8(0));
verifyEqual(testCase, out.logsout.get('controlword_6040').Values.Data(end), ...
    sgv2.controlword('disable_voltage'));
verifyEqual(testCase, out.logsout.get('auto_start_step').Values.Data(end), ...
    sgv2.internal.autoStartStepIds().WAIT_BUS_OP);
verifyEqual(testCase, out.logsout.get('diag_code').Values.Data(end), ...
    sgv2.internal.diagCodes().BUS_NOT_OP);
verifyEqual(testCase, out.logsout.get('diag_message_id').Values.Data(end), ...
    sgv2.internal.diagMessageIds().CHECK_ETHERCAT_STATE);
verifyEqual(testCase, out.logsout.get('diag_lookup_group').Values.Data(end), ...
    sgv2.internal.diagLookupGroups().ETHERCAT);
verifyEqual(testCase, out.logsout.get('diag_lookup_hint').Values.Data(end, 1:48), ...
    uint8('Check EtherCAT manual: Get State / state machine'));

modelName = sgv2.internal.buildFrameworkHarness();
in = Simulink.SimulationInput(modelName);
in = in.setVariable('network_state_ts', timeseries(int32([8 8]), [0 0.05]));
in = in.setVariable('statusword_ts', timeseries(uint16([hex2dec('0027') hex2dec('0027')]), [0 0.05]));
in = in.setVariable('error_code_ts', timeseries(uint16([0 0]), [0 0.05]));
in = in.setVariable('mode_display_ts', timeseries(int8([9 9]), [0 0.05]));
in = in.setVariable('velocity_actual_ts', timeseries(int32([0 0]), [0 0.05]));
in = in.setVariable('speed_command_ts', timeseries(int32([120 120]), [0 0.05]));
in = in.setVariable('speed_limit_ts', timeseries(uint32([1000 1000]), [0 0.05]));
out = sim(in);

verifyEqual(testCase, out.logsout.get('ready_to_run').Values.Data(end), uint8(1));
verifyEqual(testCase, out.logsout.get('controlword_6040').Values.Data(end), ...
    sgv2.controlword('enable_operation'));
verifyEqual(testCase, out.logsout.get('auto_start_step').Values.Data(end), ...
    sgv2.internal.autoStartStepIds().READY_TO_RUN);
verifyEqual(testCase, out.logsout.get('velocity_command_60ff').Values.Data(end), int32(120));
verifyEqual(testCase, out.logsout.get('diag_code').Values.Data(end), sgv2.internal.diagCodes().NONE);
verifyEqual(testCase, out.logsout.get('diag_message_id').Values.Data(end), ...
    sgv2.internal.diagMessageIds().NONE);
verifyEqual(testCase, out.logsout.get('diag_lookup_group').Values.Data(end), ...
    sgv2.internal.diagLookupGroups().NONE);
verifyEqual(testCase, out.logsout.get('diag_lookup_hint').Values.Data(end, 1:48), uint8(zeros(1, 48)));
end
