function tests = test_documentContracts
tests = functiontests(localfunctions);
end

function testDocumentationContractsStayOperatorFacing(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
runbook = fileread(fullfile(projectRoot, 'docs', 'field_validation', 'speedgoat_v2_minimal.md'));

verifyTrue(testCase, contains(runbook, '连接目标机'));
verifyTrue(testCase, contains(runbook, '点击 `Start`'));
verifyTrue(testCase, contains(runbook, '确认 `ready_to_run == 1`'));
verifyTrue(testCase, contains(runbook, '人工把速度降回 `0`'));
verifyTrue(testCase, contains(runbook, '位置跟踪'));
verifyTrue(testCase, contains(runbook, '实时记录'));
verifyTrue(testCase, contains(runbook, '同步导出'));
verifyTrue(testCase, contains(runbook, 'position_command_6064'));
verifyTrue(testCase, contains(runbook, 'position_rate_command_6064'));
boundary = fileread(fullfile(projectRoot, 'docs', 'reference', 'speedgoat_v2_boundary_statement.md'));

verifyTrue(testCase, contains(boundary, '不改 ENI'));
verifyTrue(testCase, contains(boundary, '不做 MATLAB helper'));
verifyTrue(testCase, contains(boundary, '不做 TwinCAT'));
verifyTrue(testCase, contains(boundary, 'demo_stable'));
verifyTrue(testCase, contains(boundary, '1702h Outputs + 1B04h Inputs'));
verifyTrue(testCase, contains(boundary, '只支持单轴 CSV'));
verifyTrue(testCase, contains(boundary, 'ready_to_run'));
verifyTrue(testCase, contains(boundary, '非零速度仍由人工给定'));

reference = fileread(fullfile(projectRoot, 'docs', 'reference', 'speedgoat_v2_signal_parameter_reference.md'));

verifyTrue(testCase, contains(reference, '| Name | Meaning | Source | slrtExplorer 里怎么看 | 出问题查 |'));
verifyTrue(testCase, contains(reference, 'slrtExplorer'));
verifyTrue(testCase, contains(reference, 'Signals'));
verifyTrue(testCase, contains(reference, 'Diagnostics'));
verifyTrue(testCase, contains(reference, 'Commands'));
verifyTrue(testCase, contains(reference, '出问题查'));
verifyTrue(testCase, contains(reference, 'EtherCAT 手册'));
verifyTrue(testCase, contains(reference, 'SV660N 手册'));
verifyTrue(testCase, contains(reference, '603Fh'));
verifyTrue(testCase, contains(reference, '6041h'));
verifyTrue(testCase, contains(reference, '6064h'));
verifyTrue(testCase, contains(reference, '60FFh'));
verifyTrue(testCase, contains(reference, 'IdentificationMaxSpeed60FF'));
verifyTrue(testCase, contains(reference, 'IdentificationMaxTravel6064'));
verifyTrue(testCase, contains(reference, 'IdentificationStep6064'));
verifyTrue(testCase, contains(reference, 'IdentificationStopBand6064'));
verifyTrue(testCase, contains(reference, 'PositionVelocityGain'));
verifyTrue(testCase, contains(reference, 'PositionVelocityBias'));
verifyTrue(testCase, contains(reference, 'CommandDeadband'));
verifyTrue(testCase, contains(reference, 'CommandDelaySamples'));
verifyTrue(testCase, contains(reference, 'MaxTrackingSpeed'));
verifyTrue(testCase, contains(reference, '6000'));
verifyTrue(testCase, contains(reference, 'PositionUnitMillimetersPerCount6064'));
verifyTrue(testCase, contains(reference, 'PositionLoopEnabled'));
verifyTrue(testCase, contains(reference, 'PositionLoopKp'));
verifyTrue(testCase, contains(reference, 'PositionLoopKi'));
verifyTrue(testCase, contains(reference, 'PositionLoopKd'));
verifyTrue(testCase, contains(reference, 'PositionLoopSampleTime'));
verifyTrue(testCase, contains(reference, 'PositionLoopIntegratorLimit'));
verifyTrue(testCase, contains(reference, 'SGV2_POSITION_COMMAND_6064'));
verifyTrue(testCase, contains(reference, 'SGV2_POSITION_RATE_COMMAND_6064'));
verifyTrue(testCase, contains(reference, 'position_command_6064'));
verifyTrue(testCase, contains(reference, 'position_rate_command_6064'));
verifyTrue(testCase, contains(reference, 'position_error_6064'));
verifyTrue(testCase, contains(reference, 'position_ff_velocity_60ff'));
verifyTrue(testCase, contains(reference, 'position_pid_velocity_60ff'));
verifyTrue(testCase, contains(reference, 'position_loop_speed_command_60ff'));
verifyTrue(testCase, contains(reference, 'position_loop_enabled'));
verifyTrue(testCase, contains(reference, 'computePositionLoopGate'));
verifyTrue(testCase, contains(reference, 'computePositionLoopCommand'));

identification = fileread(fullfile(projectRoot, 'docs', 'field_validation', 'speedgoat_v2_position_identification.md'));

verifyTrue(testCase, contains(identification, '采集元数据'));
verifyTrue(testCase, contains(identification, '记录流程'));
verifyTrue(testCase, contains(identification, '实时记录'));
verifyTrue(testCase, contains(identification, '同步导出'));
verifyTrue(testCase, contains(identification, 'IdentificationMaxSpeed60FF'));
verifyTrue(testCase, contains(identification, 'IdentificationMaxTravel6064'));
verifyTrue(testCase, contains(identification, 'IdentificationStep6064'));
verifyTrue(testCase, contains(identification, 'IdentificationStopBand6064'));
verifyTrue(testCase, contains(identification, 'position_actual_6064'));
verifyTrue(testCase, contains(identification, 'velocity_actual_606c'));
verifyTrue(testCase, contains(identification, 'speed_command_60ff'));
verifyTrue(testCase, contains(identification, 'sgv2.analysis.summarizeIdentificationCapture'));
verifyTrue(testCase, contains(identification, 'sgv2.analysis.fitIdentificationRelationship'));
verifyTrue(testCase, contains(identification, 'PositionDelta6064'));
verifyTrue(testCase, contains(identification, 'VelocityError606C'));
verifyTrue(testCase, contains(identification, 'IdentificationTransientGuardSamples'));
verifyTrue(testCase, contains(identification, 'TransientMask'));
verifyTrue(testCase, contains(identification, 'ValidMask'));
verifyTrue(testCase, contains(identification, 'K_cmd'));
verifyTrue(testCase, contains(identification, 'B_cmd'));
verifyTrue(testCase, contains(identification, 'RSquared'));

tuning = fileread(fullfile(projectRoot, 'docs', 'field_validation', 'speedgoat_v2_position_tuning.md'));

verifyTrue(testCase, contains(tuning, 'PT-8'));
verifyTrue(testCase, contains(tuning, '低速小位移'));
verifyTrue(testCase, contains(tuning, 'PositionLoopEnabled'));
verifyTrue(testCase, contains(tuning, 'SGV2_POSITION_COMMAND_6064'));
verifyTrue(testCase, contains(tuning, 'SGV2_POSITION_RATE_COMMAND_6064'));
verifyTrue(testCase, contains(tuning, 'PositionLoopKp'));
verifyTrue(testCase, contains(tuning, 'PositionLoopKi'));
verifyTrue(testCase, contains(tuning, 'PositionLoopKd'));
verifyTrue(testCase, contains(tuning, 'PositionLoopIntegratorLimit'));
verifyTrue(testCase, contains(tuning, 'position_loop_speed_command_60ff'));
verifyTrue(testCase, contains(tuning, 'position_loop_enabled'));

logic = fileread(fullfile(projectRoot, 'SPEEDGOAT_V2_MINIMAL_LOGIC.md'));

verifyTrue(testCase, contains(logic, 'sgv2.control.computeInverseFeedforward'));
verifyTrue(testCase, contains(logic, 'PositionVelocityGain'));
verifyTrue(testCase, contains(logic, 'PositionVelocityBias'));
verifyTrue(testCase, contains(logic, 'CommandDeadband'));
verifyTrue(testCase, contains(logic, 'CommandDelaySamples'));
verifyTrue(testCase, contains(logic, 'MaxTrackingSpeed'));
verifyTrue(testCase, contains(logic, '6000'));
verifyTrue(testCase, contains(logic, 'PositionUnitMillimetersPerCount6064'));
verifyTrue(testCase, contains(logic, 'PositionVelocityGain = 1'));
verifyTrue(testCase, contains(logic, 'position_rate_ref'));
verifyTrue(testCase, contains(logic, 'speed_ff = position_rate_ref'));
verifyTrue(testCase, contains(logic, 'position_command_6064'));
verifyTrue(testCase, contains(logic, 'position_rate_command_6064'));
verifyTrue(testCase, contains(logic, 'SGV2_POSITION_COMMAND_6064'));
verifyTrue(testCase, contains(logic, 'SGV2_POSITION_RATE_COMMAND_6064'));
verifyTrue(testCase, contains(logic, 'computePositionLoopGate'));
verifyTrue(testCase, contains(logic, 'computePositionLoopCommand'));

dataReadme = fileread(fullfile(projectRoot, 'data', 'field_validation', 'README.md'));

verifyTrue(testCase, contains(dataReadme, 'data/field_validation'));
verifyTrue(testCase, contains(dataReadme, 'speedgoat_v2_position_identification.md'));
verifyTrue(testCase, contains(dataReadme, '.mat'));
verifyTrue(testCase, contains(dataReadme, '.csv'));
verifyTrue(testCase, contains(dataReadme, '.md'));
end
