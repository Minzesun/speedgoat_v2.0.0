function [positionLoopBlock, positionLoopCommandDelayBlock] = addPositionLoopController(target, controllerBlock, positionActualSourceBlock)
modelName = char(target.ModelName);
positionLoopBlock = [modelName '/PT-5 Position Loop'];
add_block('simulink/Ports & Subsystems/Subsystem', positionLoopBlock, ...
    'Position', [560 540 980 900]);
sgv2.internal.buildPositionLoopChart(positionLoopBlock, target);

positionCommandBlock = [modelName '/position_command_6064'];
positionLoopCommandDelayBlock = [modelName '/position_loop_speed_command_60ff_delay'];
parameterSpecs = localPositionLoopParameterSpecs(target);

if getSimulinkBlockHandle(positionCommandBlock) > 0
    delete_block(positionCommandBlock);
end
for k = 1:size(parameterSpecs, 1)
    parameterBlock = [modelName '/' parameterSpecs{k, 1}];
    if getSimulinkBlockHandle(parameterBlock) > 0
        delete_block(parameterBlock);
    end
end
if getSimulinkBlockHandle(positionLoopCommandDelayBlock) > 0
    delete_block(positionLoopCommandDelayBlock);
end

add_block('simulink/Sources/Constant', positionCommandBlock, ...
    'Value', char(target.Tunables.PositionCommand6064), ...
    'OutDataTypeStr', 'int32', ...
    'Position', [120 560 150 580]);
for k = 1:size(parameterSpecs, 1)
    parameterBlock = [modelName '/' parameterSpecs{k, 1}];
    add_block('simulink/Sources/Constant', parameterBlock, ...
        'Value', parameterSpecs{k, 2}, ...
        'OutDataTypeStr', parameterSpecs{k, 3}, ...
        'Position', [120 650 + (k - 1) * 35 210 670 + (k - 1) * 35]);
end
add_block('simulink/Discrete/Unit Delay', positionLoopCommandDelayBlock, ...
    'InitialCondition', '0', ...
    'SampleTime', num2str(target.SampleTime), ...
    'Position', [1080 610 1130 640]);

positionLoopHandles = get_param(positionLoopBlock, 'PortHandles');
positionCommandHandles = get_param(positionCommandBlock, 'PortHandles');
positionLoopCommandDelayHandles = get_param(positionLoopCommandDelayBlock, 'PortHandles');
positionActualHandles = get_param(positionActualSourceBlock, 'PortHandles');
controllerHandles = get_param(controllerBlock, 'PortHandles');

add_line(modelName, positionCommandHandles.Outport, positionLoopHandles.Inport(1), 'autorouting', 'on');
add_line(modelName, positionActualHandles.Outport, positionLoopHandles.Inport(2), 'autorouting', 'on');
add_line(modelName, controllerHandles.Outport(5), positionLoopHandles.Inport(3), 'autorouting', 'on');
for k = 1:size(parameterSpecs, 1)
    parameterBlock = [modelName '/' parameterSpecs{k, 1}];
    parameterHandles = get_param(parameterBlock, 'PortHandles');
    add_line(modelName, parameterHandles.Outport, positionLoopHandles.Inport(k + 3), 'autorouting', 'on');
end
add_line(modelName, positionLoopHandles.Outport(1), positionLoopCommandDelayHandles.Inport, 'autorouting', 'on');
add_line(modelName, positionLoopCommandDelayHandles.Outport, controllerHandles.Inport(7), 'autorouting', 'on');
end

function specs = localPositionLoopParameterSpecs(target)
specs = { ...
    'position_loop_enabled_request', char(target.Tunables.PositionLoopEnabled), 'int32'; ...
    'position_loop_kp', char(target.Tunables.PositionLoopKp), 'int32'; ...
    'position_loop_ki', char(target.Tunables.PositionLoopKi), 'int32'; ...
    'position_loop_kd', char(target.Tunables.PositionLoopKd), 'int32'; ...
    'position_loop_sample_time', char(target.Tunables.PositionLoopSampleTime), 'double'; ...
    'position_loop_integrator_limit', char(target.Tunables.PositionLoopIntegratorLimit), 'int32'; ...
    'max_tracking_speed', char(target.Tunables.MaxTrackingSpeed), 'int32'};
end
