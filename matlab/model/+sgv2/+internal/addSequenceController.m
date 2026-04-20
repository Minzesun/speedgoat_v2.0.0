function controllerBlock = addSequenceController(target)
modelName = char(target.ModelName);
controllerBlock = [modelName '/SV660N Sequence Controller'];
add_block('simulink/Ports & Subsystems/Subsystem', controllerBlock, ...
    'Position', [560 170 900 520]);
sgv2.internal.buildStartupChart(controllerBlock);
end
