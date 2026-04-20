function tests = test_targetConfig
tests = functiontests(localfunctions);
end

function testTargetContractMatchesApprovedSpec(testCase)
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
    "D:\Temporary_file\speedgoat_v2.0.0\matlab\model\models\speedgoat_v2_minimal.slx");
verifyEqual(testCase, target.EniFile, ...
    "D:\Temporary_file\speedgoat_v2.0.0\matlab\config\ethercat\eni\ENI2.xml");
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
    'SpeedLimit607F'});
verifyEqual(testCase, fieldnames(target.Signals), { ...
    'ActualNetworkState'
    'ExpectedNetworkState'
    'Statusword6041'
    'ErrorCode603F'
    'ModeDisplay6061'
    'VelocityActual606C'
    'DiagCode'
    'DiagMessageId'
    'DiagLookupGroup'
    'DiagLookupHint'
    'ReadyToRun'
    'AutoStartStep'
    'SpeedCommand60FF'
    'SpeedLimit607F'});
verifyEqual(testCase, numel(target.PdoMap.Tx), 4);
verifyEqual(testCase, numel(target.PdoMap.Rx), 4);
verifyEqual(testCase, {target.PdoMap.Tx.Key}, ...
    {"controlword6040", "targetVelocity60FF", "modeOfOperation6060", "maxProfileVelocity607F"});
verifyEqual(testCase, {target.PdoMap.Rx.Key}, ...
    {"errorCode603F", "statusword6041", "modeDisplay6061", "velocityActual606C"});
verifyEqual(testCase, [target.PdoMap.Tx.Offset], [568 616 664 688]);
verifyEqual(testCase, [target.PdoMap.Rx.Offset], [568 584 648 768]);
verifyEqual(testCase, {target.PdoMap.Tx.DataType}, ...
    {"uint16", "int32", "int8", "uint32"});
verifyEqual(testCase, {target.PdoMap.Rx.DataType}, ...
    {"uint16", "uint16", "int8", "int32"});
verifyEqual(testCase, [target.PdoMap.Tx.TypeSize], [16 32 8 32]);
verifyEqual(testCase, [target.PdoMap.Rx.TypeSize], [16 16 8 32]);
end
