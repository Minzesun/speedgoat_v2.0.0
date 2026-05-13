function buildPositionLoopChart(target, targetConfig)
load_system('simulink');

subsystemPath = char(target);
localClearSubsystem(subsystemPath);

inputSpecs = { ...
    'position_command_6064', 1; ...
    'position_actual_6064', 2; ...
    'ready_to_run', 3; ...
    'position_loop_enabled_request', 4; ...
    'position_loop_kp', 5; ...
    'position_loop_ki', 6; ...
    'position_loop_kd', 7; ...
    'position_loop_sample_time', 8; ...
    'position_loop_integrator_limit', 9; ...
    'max_tracking_speed', 10};

outputSpecs = { ...
    'position_loop_speed_command_60ff', 1; ...
    'position_error_6064', 2; ...
    'position_ff_velocity_60ff', 3; ...
    'position_pid_velocity_60ff', 4; ...
    'position_loop_enabled', 5};

for k = 1:size(inputSpecs, 1)
    add_block('simulink/Sources/In1', [subsystemPath '/' inputSpecs{k, 1}], ...
        'Port', num2str(inputSpecs{k, 2}), ...
        'Position', [35 45 + (k - 1) * 40 65 59 + (k - 1) * 40]);
end

for k = 1:size(outputSpecs, 1)
    add_block('simulink/Sinks/Out1', [subsystemPath '/' outputSpecs{k, 1}], ...
        'Port', num2str(outputSpecs{k, 2}), ...
        'Position', [1110 100 + (k - 1) * 70 1140 114 + (k - 1) * 70]);
end

sampleTime = localUnitDelaySampleTime(targetConfig);
inputHandles = localBlockHandles(subsystemPath, inputSpecs(:, 1));
outputHandles = localBlockHandles(subsystemPath, outputSpecs(:, 1));

blocks = localAddControlBlocks(subsystemPath, sampleTime);
localWireEnableGate(subsystemPath, inputHandles, outputHandles, blocks);
localWireErrorBranch(subsystemPath, inputHandles, outputHandles, blocks);
localWireFeedforwardOutput(subsystemPath, outputHandles, blocks);
localWirePidBranch(subsystemPath, inputHandles, outputHandles, blocks);
localWireFinalCommand(subsystemPath, inputHandles, outputHandles, blocks);
end

function sampleTime = localUnitDelaySampleTime(targetConfig)
sampleTime = '-1';
if nargin > 0 && isstruct(targetConfig) && isfield(targetConfig, 'SampleTime')
    sampleTime = num2str(targetConfig.SampleTime);
end
end

function localClearSubsystem(subsystemPath)
lines = find_system(subsystemPath, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line');
for k = numel(lines):-1:1
    delete_line(lines(k));
end

blocks = find_system(subsystemPath, 'SearchDepth', 1, 'Type', 'Block');
for k = numel(blocks):-1:1
    if ~strcmp(blocks{k}, subsystemPath)
        delete_block(blocks{k});
    end
end
end

function handles = localBlockHandles(subsystemPath, names)
handles = cell(numel(names), 1);
for k = 1:numel(names)
    handles{k} = get_param([subsystemPath '/' names{k}], 'PortHandles');
end
end

function blocks = localAddControlBlocks(subsystemPath, sampleTime)
blocks.readyOne = [subsystemPath '/ready_to_run_equals_1'];
add_block('simulink/Logic and Bit Operations/Relational Operator', blocks.readyOne, ...
    'Operator', '==', ...
    'Position', [155 165 215 195]);

blocks.readyOneConstant = [subsystemPath '/ready_to_run_one'];
add_block('simulink/Sources/Constant', blocks.readyOneConstant, ...
    'Value', 'uint8(1)', ...
    'OutDataTypeStr', 'uint8', ...
    'Position', [85 190 135 210]);

blocks.enableRequestNonzero = [subsystemPath '/enable_request_nonzero'];
add_block('simulink/Logic and Bit Operations/Relational Operator', blocks.enableRequestNonzero, ...
    'Operator', '~=', ...
    'Position', [155 210 215 240]);

blocks.enableRequestZero = [subsystemPath '/enable_request_zero'];
add_block('simulink/Sources/Constant', blocks.enableRequestZero, ...
    'Value', 'int32(0)', ...
    'OutDataTypeStr', 'int32', ...
    'Position', [85 235 135 255]);

blocks.enableGate = [subsystemPath '/position_loop_enable_gate'];
add_block('simulink/Logic and Bit Operations/Logical Operator', blocks.enableGate, ...
    'Operator', 'AND', ...
    'Inputs', '2', ...
    'Position', [250 185 300 230]);

blocks.enabledToUint8 = [subsystemPath '/position_loop_enabled_to_uint8'];
add_block('simulink/Signal Attributes/Data Type Conversion', blocks.enabledToUint8, ...
    'OutDataTypeStr', 'uint8', ...
    'Position', [1010 370 1065 395]);

blocks.zeroInt32Error = [subsystemPath '/zero_int32_error'];
add_block('simulink/Sources/Constant', blocks.zeroInt32Error, ...
    'Value', 'int32(0)', ...
    'OutDataTypeStr', 'int32', ...
    'Position', [820 175 880 195]);

blocks.zeroInt32Ff = [subsystemPath '/zero_int32_ff'];
add_block('simulink/Sources/Constant', blocks.zeroInt32Ff, ...
    'Value', 'int32(0)', ...
    'OutDataTypeStr', 'int32', ...
    'Position', [1010 250 1070 270]);

blocks.zeroInt32Command = [subsystemPath '/zero_int32_command'];
add_block('simulink/Sources/Constant', blocks.zeroInt32Command, ...
    'Value', 'int32(0)', ...
    'OutDataTypeStr', 'int32', ...
    'Position', [1010 95 1070 115]);

blocks.positionError = [subsystemPath '/position_error_sum'];
add_block('simulink/Math Operations/Sum', blocks.positionError, ...
    'Inputs', '+-', ...
    'OutDataTypeStr', 'int32', ...
    'Position', [345 70 395 105]);

blocks.positionErrorSwitch = [subsystemPath '/position_error_enabled_switch'];
add_block('simulink/Signal Routing/Switch', blocks.positionErrorSwitch, ...
    'Criteria', 'u2 ~= 0', ...
    'Position', [920 150 980 210]);

blocks.errorToDouble = [subsystemPath '/position_error_to_double'];
add_block('simulink/Signal Attributes/Data Type Conversion', blocks.errorToDouble, ...
    'OutDataTypeStr', 'double', ...
    'Position', [430 80 490 105]);

blocks.maxSpeedToDouble = [subsystemPath '/max_tracking_speed_to_double'];
add_block('simulink/Signal Attributes/Data Type Conversion', blocks.maxSpeedToDouble, ...
    'OutDataTypeStr', 'double', ...
    'Position', [180 555 240 580]);

blocks.negativeMaxSpeed = [subsystemPath '/negative_max_tracking_speed'];
add_block('simulink/Math Operations/Gain', blocks.negativeMaxSpeed, ...
    'Gain', '-1', ...
    'OutDataTypeStr', 'double', ...
    'Position', [280 555 330 580]);

blocks.integralDelay = [subsystemPath '/integral_6064_delay'];
add_block('simulink/Discrete/Unit Delay', blocks.integralDelay, ...
    'InitialCondition', '0', ...
    'SampleTime', sampleTime, ...
    'Position', [500 165 550 195]);

blocks.previousErrorDelay = [subsystemPath '/previous_error_6064_delay'];
add_block('simulink/Discrete/Unit Delay', blocks.previousErrorDelay, ...
    'InitialCondition', '0', ...
    'SampleTime', sampleTime, ...
    'Position', [500 215 550 245]);

blocks.pidUpdate = [subsystemPath '/pid_state_update'];
add_block('simulink/User-Defined Functions/MATLAB Function', blocks.pidUpdate, ...
    'Position', [620 115 790 245]);
localSetMatlabFunctionScript(blocks.pidUpdate, localPidStateUpdateScript());

blocks.finalLowerLimit = [subsystemPath '/final_lower_limit'];
add_block('simulink/Math Operations/MinMax', blocks.finalLowerLimit, ...
    'Function', 'max', ...
    'Inputs', '2', ...
    'Position', [850 65 900 110]);

blocks.finalUpperLimit = [subsystemPath '/final_upper_limit'];
add_block('simulink/Math Operations/MinMax', blocks.finalUpperLimit, ...
    'Function', 'min', ...
    'Inputs', '2', ...
    'Position', [925 65 975 110]);

blocks.finalRound = [subsystemPath '/final_speed_round'];
add_block('simulink/Math Operations/Rounding Function', blocks.finalRound, ...
    'Operator', 'round', ...
    'Position', [1005 125 1050 150]);

blocks.finalToInt32 = [subsystemPath '/final_speed_to_int32'];
add_block('simulink/Signal Attributes/Data Type Conversion', blocks.finalToInt32, ...
    'OutDataTypeStr', 'int32', ...
    'Position', [1005 160 1060 185]);

blocks.finalEnabledSwitch = [subsystemPath '/final_speed_enabled_switch'];
add_block('simulink/Signal Routing/Switch', blocks.finalEnabledSwitch, ...
    'Criteria', 'u2 ~= 0', ...
    'Position', [1010 30 1070 90]);
end

function localSetMatlabFunctionScript(blockPath, scriptText)
root = sfroot;
chart = root.find('-isa', 'Stateflow.EMChart', 'Path', blockPath);
if isempty(chart)
    error('sgv2:MatlabFunctionBlockNotFound', ...
        'Could not find MATLAB Function block at %s.', blockPath);
end
chart(1).Script = scriptText;
end

function scriptText = localPidStateUpdateScript()
scriptText = sprintf([ ...
    'function [raw_pid_velocity_60ff, position_pid_velocity_60ff, integral_6064_next, previous_error_6064_next] = pid_state_update(enabled, error6064, previous_error_6064, integral_6064, position_loop_kp, position_loop_ki, position_loop_kd, position_loop_sample_time, position_loop_integrator_limit)\n' ...
    'raw_pid_velocity_60ff = 0.0;\n' ...
    'position_pid_velocity_60ff = int32(0);\n' ...
    'integral_6064_next = 0.0;\n' ...
    'previous_error_6064_next = 0.0;\n' ...
    'if enabled\n' ...
    '    error_value = double(error6064);\n' ...
    '    kp_gain = double(position_loop_kp) * 0.001;\n' ...
    '    ki_gain = double(position_loop_ki) * 0.001;\n' ...
    '    kd_gain = double(position_loop_kd) * 0.001;\n' ...
    '    limit_value = double(position_loop_integrator_limit);\n' ...
    '    sample_time = max(position_loop_sample_time, eps);\n' ...
    '    integral_6064_next = double(integral_6064) + ki_gain * error_value * sample_time;\n' ...
    '    integral_6064_next = min(max(integral_6064_next, -limit_value), limit_value);\n' ...
    '    derivative6064 = (error_value - double(previous_error_6064)) / sample_time;\n' ...
    '    raw_pid_velocity_60ff = kp_gain * error_value + integral_6064_next + kd_gain * derivative6064;\n' ...
    '    position_pid_velocity_60ff = int32(round(raw_pid_velocity_60ff));\n' ...
    '    previous_error_6064_next = error_value;\n' ...
    'end\n' ...
    'end\n']);
end

function localWireEnableGate(subsystemPath, inputHandles, outputHandles, blocks)
readyOneHandles = get_param(blocks.readyOne, 'PortHandles');
readyOneConstantHandles = get_param(blocks.readyOneConstant, 'PortHandles');
enableRequestNonzeroHandles = get_param(blocks.enableRequestNonzero, 'PortHandles');
enableRequestZeroHandles = get_param(blocks.enableRequestZero, 'PortHandles');
enableGateHandles = get_param(blocks.enableGate, 'PortHandles');
enabledToUint8Handles = get_param(blocks.enabledToUint8, 'PortHandles');

add_line(subsystemPath, inputHandles{3}.Outport, readyOneHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, readyOneConstantHandles.Outport, readyOneHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, inputHandles{4}.Outport, enableRequestNonzeroHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, enableRequestZeroHandles.Outport, enableRequestNonzeroHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, readyOneHandles.Outport, enableGateHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, enableRequestNonzeroHandles.Outport, enableGateHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, enableGateHandles.Outport, enabledToUint8Handles.Inport, 'autorouting', 'on');
add_line(subsystemPath, enabledToUint8Handles.Outport, outputHandles{5}.Inport, 'autorouting', 'on');
end

function localWireErrorBranch(subsystemPath, inputHandles, outputHandles, blocks)
errorHandles = get_param(blocks.positionError, 'PortHandles');
errorSwitchHandles = get_param(blocks.positionErrorSwitch, 'PortHandles');
errorToDoubleHandles = get_param(blocks.errorToDouble, 'PortHandles');
enableGateHandles = get_param(blocks.enableGate, 'PortHandles');
zeroInt32Handles = get_param(blocks.zeroInt32Error, 'PortHandles');

add_line(subsystemPath, inputHandles{1}.Outport, errorHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, inputHandles{2}.Outport, errorHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, errorHandles.Outport, errorToDoubleHandles.Inport, 'autorouting', 'on');
add_line(subsystemPath, errorHandles.Outport, errorSwitchHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, enableGateHandles.Outport, errorSwitchHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, zeroInt32Handles.Outport, errorSwitchHandles.Inport(3), 'autorouting', 'on');
add_line(subsystemPath, errorSwitchHandles.Outport, outputHandles{2}.Inport, 'autorouting', 'on');
end

function localWireFeedforwardOutput(subsystemPath, outputHandles, blocks)
zeroInt32Handles = get_param(blocks.zeroInt32Ff, 'PortHandles');
add_line(subsystemPath, zeroInt32Handles.Outport, outputHandles{3}.Inport, 'autorouting', 'on');
end

function localWirePidBranch(subsystemPath, inputHandles, outputHandles, blocks)
enableGateHandles = get_param(blocks.enableGate, 'PortHandles');
errorToDoubleHandles = get_param(blocks.errorToDouble, 'PortHandles');
integralDelayHandles = get_param(blocks.integralDelay, 'PortHandles');
previousErrorDelayHandles = get_param(blocks.previousErrorDelay, 'PortHandles');
pidUpdateHandles = get_param(blocks.pidUpdate, 'PortHandles');

add_line(subsystemPath, enableGateHandles.Outport, pidUpdateHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, errorToDoubleHandles.Outport, pidUpdateHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, previousErrorDelayHandles.Outport, pidUpdateHandles.Inport(3), 'autorouting', 'on');
add_line(subsystemPath, integralDelayHandles.Outport, pidUpdateHandles.Inport(4), 'autorouting', 'on');
add_line(subsystemPath, inputHandles{5}.Outport, pidUpdateHandles.Inport(5), 'autorouting', 'on');
add_line(subsystemPath, inputHandles{6}.Outport, pidUpdateHandles.Inport(6), 'autorouting', 'on');
add_line(subsystemPath, inputHandles{7}.Outport, pidUpdateHandles.Inport(7), 'autorouting', 'on');
add_line(subsystemPath, inputHandles{8}.Outport, pidUpdateHandles.Inport(8), 'autorouting', 'on');
add_line(subsystemPath, inputHandles{9}.Outport, pidUpdateHandles.Inport(9), 'autorouting', 'on');

add_line(subsystemPath, pidUpdateHandles.Outport(2), outputHandles{4}.Inport, 'autorouting', 'on');
add_line(subsystemPath, pidUpdateHandles.Outport(3), integralDelayHandles.Inport, 'autorouting', 'on');
add_line(subsystemPath, pidUpdateHandles.Outport(4), previousErrorDelayHandles.Inport, 'autorouting', 'on');
end

function localWireFinalCommand(subsystemPath, inputHandles, outputHandles, blocks)
pidUpdateHandles = get_param(blocks.pidUpdate, 'PortHandles');
finalLowerLimitHandles = get_param(blocks.finalLowerLimit, 'PortHandles');
finalUpperLimitHandles = get_param(blocks.finalUpperLimit, 'PortHandles');
finalRoundHandles = get_param(blocks.finalRound, 'PortHandles');
finalToInt32Handles = get_param(blocks.finalToInt32, 'PortHandles');
finalEnabledSwitchHandles = get_param(blocks.finalEnabledSwitch, 'PortHandles');
enableGateHandles = get_param(blocks.enableGate, 'PortHandles');
zeroInt32Handles = get_param(blocks.zeroInt32Command, 'PortHandles');
negativeMaxSpeedHandles = get_param(blocks.negativeMaxSpeed, 'PortHandles');
maxSpeedToDoubleHandles = get_param(blocks.maxSpeedToDouble, 'PortHandles');

add_line(subsystemPath, inputHandles{10}.Outport, maxSpeedToDoubleHandles.Inport, 'autorouting', 'on');
add_line(subsystemPath, maxSpeedToDoubleHandles.Outport, negativeMaxSpeedHandles.Inport, 'autorouting', 'on');
add_line(subsystemPath, pidUpdateHandles.Outport(1), finalLowerLimitHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, negativeMaxSpeedHandles.Outport, finalLowerLimitHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, finalLowerLimitHandles.Outport, finalUpperLimitHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, maxSpeedToDoubleHandles.Outport, finalUpperLimitHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, finalUpperLimitHandles.Outport, finalRoundHandles.Inport, 'autorouting', 'on');
add_line(subsystemPath, finalRoundHandles.Outport, finalToInt32Handles.Inport, 'autorouting', 'on');
add_line(subsystemPath, finalToInt32Handles.Outport, finalEnabledSwitchHandles.Inport(1), 'autorouting', 'on');
add_line(subsystemPath, enableGateHandles.Outport, finalEnabledSwitchHandles.Inport(2), 'autorouting', 'on');
add_line(subsystemPath, zeroInt32Handles.Outport, finalEnabledSwitchHandles.Inport(3), 'autorouting', 'on');
add_line(subsystemPath, finalEnabledSwitchHandles.Outport, outputHandles{1}.Inport, 'autorouting', 'on');
end
