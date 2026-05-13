function tests = test_targetConfig
tests = functiontests(localfunctions);
end

function testTargetContractMatchesApprovedSpec(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
target = target_minimal_slrtexplorer();

verifyEqual(testCase, fieldnames(target), { ...
    'TargetName'
    'ModelName'
    'ApplicationName'
    'GeneratedModelFile'
    'EniFile'
    'SampleTime'
    'AxisConfig'
    'Ethercat'
    'PdoMap'
    'Tunables'
    'Signals'});

verifyEqual(testCase, target.TargetName, "Minimal slrtExplorer");
verifyEqual(testCase, target.ModelName, "speedgoat_v2_minimal");
verifyEqual(testCase, target.ApplicationName, "speedgoat_v2_minimal");
verifyEqual(testCase, target.GeneratedModelFile, ...
    fullfile(projectRoot, "matlab", "model", "models", "speedgoat_v2_minimal.slx"));
verifyEqual(testCase, target.EniFile, ...
    fullfile(projectRoot, "matlab", "config", "ethercat", "eni", "ENI2.xml"));
verifyEqual(testCase, target.SampleTime, 0.002);
verifyEqual(testCase, target.Ethercat.InitStateValue, "2");
verifyEqual(testCase, target.Ethercat.ExpectedNetworkState, int32(8));
verifyEqual(testCase, target.Ethercat.ExpectedModeOfOperation, int8(9));
verifyEqual(testCase, target.Tunables.SpeedCommand60FF, "SGV2_SPEED_COMMAND_60FF");
verifyEqual(testCase, target.Tunables.SpeedLimit607F, "SGV2_SPEED_LIMIT_607F");
verifyEqual(testCase, fieldnames(target.AxisConfig), { ...
    'AxisKey'
    'DriveType'
    'SlaveName'
    'EthercatDeviceIndex'
    'EthernetPortNumber'
    'DefaultSafeVelocity60FF'
    'DefaultMaxProfileVelocity607F'
    'DefaultIdentificationMaxSpeed60FF'
    'DefaultIdentificationMaxTravel6064'
    'DefaultIdentificationStep6064'
    'DefaultIdentificationStopBand6064'
    'DefaultPositionReferenceFile'
    'DefaultPositionReferenceFeedforwardEnabled'
    'DefaultPositionCommand6064'
    'DefaultPositionRateCommand6064'
    'DefaultPositionVelocityGain'
    'DefaultPositionVelocityBias'
    'DefaultCommandDeadband'
    'DefaultCommandDelaySamples'
    'DefaultMaxTrackingSpeed'
    'DefaultPositionUnitMillimetersPerCount6064'
    'DefaultPositionLoopKp'
    'DefaultPositionLoopKi'
    'DefaultPositionLoopKd'
    'DefaultPositionLoopSampleTime'
    'DefaultPositionLoopIntegratorLimit'
    'ExpectedModeOfOperation'});
verifyEqual(testCase, fieldnames(target.Ethercat), { ...
    'EniFile'
    'DeviceIndex'
    'PortNumber'
    'InitStateValue'
    'ExpectedNetworkState'
    'EnableDC'
    'DCModeValue'
    'DCTuningValue'
    'ExpectedModeOfOperation'
    'SampleTime'});
verifyEqual(testCase, fieldnames(target.PdoMap), {'Rx'; 'Tx'});
verifyEqual(testCase, fieldnames(target.Tunables), { ...
    'SpeedCommand60FF'
    'SpeedLimit607F'
    'IdentificationMaxSpeed60FF'
    'IdentificationMaxTravel6064'
    'IdentificationStep6064'
    'IdentificationStopBand6064'
    'PositionReferenceFeedforwardEnabled'
    'PositionCommand6064'
    'PositionRateCommand6064'
    'PositionVelocityGain'
    'PositionVelocityBias'
    'CommandDeadband'
    'CommandDelaySamples'
    'MaxTrackingSpeed'
    'PositionUnitMillimetersPerCount6064'
    'PositionLoopKp'
    'PositionLoopKi'
    'PositionLoopKd'
    'PositionLoopSampleTime'
    'PositionLoopIntegratorLimit'});
verifyEqual(testCase, fieldnames(target.Signals), { ...
    'ActualNetworkState'
    'ExpectedNetworkState'
    'Statusword6041'
    'ErrorCode603F'
    'PositionActual6064'
    'ModeDisplay6061'
    'VelocityActual606C'
    'DiagCode'
    'DiagMessageId'
    'DiagLookupGroup'
    'DiagLookupHint'
    'ReadyToRun'
    'AutoStartStep'
    'PositionReference6064'
    'PositionRateReference6064'
    'PositionCommand6064'
    'PositionRateCommand6064'
    'PositionError6064'
    'PositionFeedforwardVelocity60FF'
    'PositionPidVelocity60FF'
    'PositionLoopSpeedCommand60FF'
    'PositionLoopEnabled'
    'SpeedCommand60FF'
    'SpeedLimit607F'});
verifyEqual(testCase, numel(target.PdoMap.Tx), 4);
verifyEqual(testCase, numel(target.PdoMap.Rx), 5);
verifyEqual(testCase, {target.PdoMap.Tx.Key}, ...
    {"controlword6040", "targetVelocity60FF", "modeOfOperation6060", "maxProfileVelocity607F"});
verifyEqual(testCase, {target.PdoMap.Rx.Key}, ...
    {"errorCode603F", "statusword6041", "positionActual6064", "modeDisplay6061", "velocityActual606C"});
verifyEqual(testCase, [target.PdoMap.Tx.Offset], [568 616 664 688]);
verifyEqual(testCase, [target.PdoMap.Rx.Offset], [568 584 600 648 768]);
verifyEqual(testCase, {target.PdoMap.Tx.DataType}, ...
    {"uint16", "int32", "int8", "uint32"});
verifyEqual(testCase, {target.PdoMap.Rx.DataType}, ...
    {"uint16", "uint16", "int32", "int8", "int32"});
verifyEqual(testCase, [target.PdoMap.Tx.TypeSize], [16 32 8 32]);
verifyEqual(testCase, [target.PdoMap.Rx.TypeSize], [16 16 32 8 32]);
verifyEqual(testCase, target.AxisConfig.DefaultIdentificationMaxSpeed60FF, int32(200));
verifyEqual(testCase, target.AxisConfig.DefaultIdentificationMaxTravel6064, int32(1000));
verifyEqual(testCase, target.AxisConfig.DefaultIdentificationStep6064, int32(100));
verifyEqual(testCase, target.AxisConfig.DefaultIdentificationStopBand6064, int32(20));
verifyEqual(testCase, target.AxisConfig.DefaultPositionReferenceFile, ...
    "data/reference/position_reference_6064.txt");
verifyEqual(testCase, target.AxisConfig.DefaultPositionReferenceFeedforwardEnabled, int32(1));
verifyEqual(testCase, target.AxisConfig.DefaultPositionCommand6064, int32(0));
verifyEqual(testCase, target.AxisConfig.DefaultPositionRateCommand6064, int32(0));
verifyEqual(testCase, target.AxisConfig.DefaultPositionVelocityGain, int32(1));
verifyEqual(testCase, target.AxisConfig.DefaultPositionVelocityBias, int32(0));
verifyEqual(testCase, target.AxisConfig.DefaultCommandDeadband, int32(0));
verifyEqual(testCase, target.AxisConfig.DefaultCommandDelaySamples, uint32(0));
verifyEqual(testCase, target.AxisConfig.DefaultMaxTrackingSpeed, int32(6000));
verifyEqual(testCase, target.AxisConfig.DefaultPositionUnitMillimetersPerCount6064, double(1));
verifyEqual(testCase, target.AxisConfig.DefaultPositionLoopKp, int32(0));
verifyEqual(testCase, target.AxisConfig.DefaultPositionLoopKi, int32(0));
verifyEqual(testCase, target.AxisConfig.DefaultPositionLoopKd, int32(0));
verifyEqual(testCase, target.AxisConfig.DefaultPositionLoopSampleTime, double(0.002));
verifyEqual(testCase, target.AxisConfig.DefaultPositionLoopIntegratorLimit, int32(0));
verifyEqual(testCase, target.Tunables.IdentificationMaxSpeed60FF, "SGV2_IDENTIFICATION_MAX_SPEED_60FF");
verifyEqual(testCase, target.Tunables.IdentificationMaxTravel6064, "SGV2_IDENTIFICATION_MAX_TRAVEL_6064");
verifyEqual(testCase, target.Tunables.IdentificationStep6064, "SGV2_IDENTIFICATION_STEP_6064");
verifyEqual(testCase, target.Tunables.IdentificationStopBand6064, "SGV2_IDENTIFICATION_STOP_BAND_6064");
verifyEqual(testCase, target.Tunables.PositionReferenceFeedforwardEnabled, "SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED");
verifyEqual(testCase, target.Tunables.PositionCommand6064, "SGV2_POSITION_COMMAND_6064");
verifyEqual(testCase, target.Tunables.PositionRateCommand6064, "SGV2_POSITION_RATE_COMMAND_6064");
verifyEqual(testCase, target.Tunables.PositionVelocityGain, "SGV2_POSITION_VELOCITY_GAIN");
verifyEqual(testCase, target.Tunables.PositionVelocityBias, "SGV2_POSITION_VELOCITY_BIAS");
verifyEqual(testCase, target.Tunables.CommandDeadband, "SGV2_COMMAND_DEADBAND");
verifyEqual(testCase, target.Tunables.CommandDelaySamples, "SGV2_COMMAND_DELAY_SAMPLES");
verifyEqual(testCase, target.Tunables.MaxTrackingSpeed, "SGV2_MAX_TRACKING_SPEED");
verifyEqual(testCase, target.Tunables.PositionUnitMillimetersPerCount6064, "SGV2_POSITION_UNIT_MILLIMETERS_PER_COUNT_6064");
verifyEqual(testCase, target.Tunables.PositionLoopKp, "SGV2_POSITION_LOOP_KP");
verifyEqual(testCase, target.Tunables.PositionLoopKi, "SGV2_POSITION_LOOP_KI");
verifyEqual(testCase, target.Tunables.PositionLoopKd, "SGV2_POSITION_LOOP_KD");
verifyEqual(testCase, target.Tunables.PositionLoopSampleTime, "SGV2_POSITION_LOOP_SAMPLE_TIME");
verifyEqual(testCase, target.Tunables.PositionLoopIntegratorLimit, "SGV2_POSITION_LOOP_INTEGRATOR_LIMIT");
verifyEqual(testCase, target.Signals.PositionReference6064, "position_reference_6064");
verifyEqual(testCase, target.Signals.PositionRateReference6064, "position_rate_reference_6064");
verifyFalse(testCase, isfield(target.Tunables, 'PositionLoopEnabled'));
verifyFalse(testCase, isfield(target.AxisConfig, 'DefaultPositionLoopEnabled'));
end
