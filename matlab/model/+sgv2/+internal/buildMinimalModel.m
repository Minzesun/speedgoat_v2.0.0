function modelPath = buildMinimalModel(target)
outputDir = fileparts(target.GeneratedModelFile);
finalModelPath = char(target.GeneratedModelFile);
backupModelPath = [finalModelPath '.bak'];

if ~isfolder(outputDir)
    mkdir(outputDir);
end

if bdIsLoaded(target.ModelName)
    set_param(target.ModelName, 'Dirty', 'off');
    close_system(target.ModelName, 0);
end

hadBackup = localBackupGeneratedModel(finalModelPath, backupModelPath);
restoreCleanup = onCleanup(@() localRestoreBackupOnFailure( ...
    target.ModelName, finalModelPath, backupModelPath, hadBackup)); %#ok<NASGU>

load_system('simulink');
load_system('sflib');
load_system('slrealtimeethercatlib');

new_system(target.ModelName);
set_param(target.ModelName, ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', num2str(target.SampleTime), ...
    'StopTime', 'inf', ...
    'SimulationMode', 'external', ...
    'DefaultParameterBehavior', 'Tunable', ...
    'SystemTargetFile', 'slrealtime.tlc', ...
    'InitFcn', localBootstrapPathCallback());

localSeedModelWorkspaceDefaults(target);

[controllerBlock, getStateBlock, rxBlocks, txBlocks] = sgv2.internal.addEthercatIo(target);
[positionLoopBlock, positionLoopCommandDelayBlock] = sgv2.internal.addPositionLoopController(target, controllerBlock, rxBlocks.positionActual6064);
commandBlocks = sgv2.internal.addManualCommandInterface(target, controllerBlock);
sgv2.internal.addObservabilityPorts(target, controllerBlock, positionLoopBlock, positionLoopCommandDelayBlock, getStateBlock, rxBlocks, txBlocks, commandBlocks);
set_param(target.ModelName, 'SimulationCommand', 'update');

save_system(target.ModelName, finalModelPath);
set_param(target.ModelName, 'Dirty', 'off');
close_system(target.ModelName, 0);
localDeleteIfExists(backupModelPath);
clear restoreCleanup;
modelPath = string(finalModelPath);
end

function hadBackup = localBackupGeneratedModel(finalModelPath, backupModelPath)
hadBackup = isfile(finalModelPath);
if ~hadBackup
    return;
end

[status, message] = copyfile(finalModelPath, backupModelPath, 'f');
if ~status
    error('sgv2:MinimalModelBackupFailed', ...
        'Could not back up generated model at %s: %s', finalModelPath, message);
end
end

function localDeleteIfExists(path)
if isfile(path)
    delete(path);
end
end

function localRestoreBackupOnFailure(modelName, finalModelPath, backupModelPath, hadBackup)
if bdIsLoaded(modelName)
    set_param(modelName, 'Dirty', 'off');
    close_system(modelName, 0);
end

if isfile(backupModelPath)
    if hadBackup
        copyfile(backupModelPath, finalModelPath, 'f');
    else
        localDeleteIfExists(finalModelPath);
    end
    localDeleteIfExists(backupModelPath);
elseif ~hadBackup
    localDeleteIfExists(finalModelPath);
end
end

function localSeedModelWorkspaceDefaults(target)
modelWorkspace = get_param(char(target.ModelName), 'ModelWorkspace');
assignin(modelWorkspace, char(target.Tunables.SpeedCommand60FF), ...
    target.AxisConfig.DefaultSafeVelocity60FF);
assignin(modelWorkspace, char(target.Tunables.SpeedLimit607F), ...
    target.AxisConfig.DefaultMaxProfileVelocity607F);
assignin(modelWorkspace, char(target.Tunables.PositionCommand6064), ...
    target.AxisConfig.DefaultPositionCommand6064);
assignin(modelWorkspace, char(target.Tunables.MaxTrackingSpeed), ...
    target.AxisConfig.DefaultMaxTrackingSpeed);
assignin(modelWorkspace, char(target.Tunables.PositionUnitMillimetersPerCount6064), ...
    target.AxisConfig.DefaultPositionUnitMillimetersPerCount6064);
assignin(modelWorkspace, char(target.Tunables.PositionLoopEnabled), ...
    target.AxisConfig.DefaultPositionLoopEnabled);
assignin(modelWorkspace, char(target.Tunables.PositionLoopKp), ...
    target.AxisConfig.DefaultPositionLoopKp);
assignin(modelWorkspace, char(target.Tunables.PositionLoopKi), ...
    target.AxisConfig.DefaultPositionLoopKi);
assignin(modelWorkspace, char(target.Tunables.PositionLoopKd), ...
    target.AxisConfig.DefaultPositionLoopKd);
assignin(modelWorkspace, char(target.Tunables.PositionLoopSampleTime), ...
    target.AxisConfig.DefaultPositionLoopSampleTime);
assignin(modelWorkspace, char(target.Tunables.PositionLoopIntegratorLimit), ...
    target.AxisConfig.DefaultPositionLoopIntegratorLimit);
end

function callback = localBootstrapPathCallback()
callback = sprintf([ ...
    'modelFile = get_param(bdroot, ''FileName'');\n' ...
    'if ~isempty(modelFile)\n' ...
    '    bootstrapScript = fullfile(fileparts(modelFile), ''..'', ''bootstrap_speedgoat_v2_path.m'');\n' ...
    '    if isfile(bootstrapScript)\n' ...
    '        run(bootstrapScript);\n' ...
    '    end\n' ...
    'end']);
end
