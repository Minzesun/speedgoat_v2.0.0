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
    'SystemTargetFile', 'slrealtime.tlc');

localSeedModelWorkspaceDefaults(target);

[controllerBlock, getStateBlock, rxBlocks, txBlocks] = sgv2.internal.addEthercatIo(target);
commandBlocks = sgv2.internal.addManualCommandInterface(target, controllerBlock);
sgv2.internal.addObservabilityPorts(target, controllerBlock, getStateBlock, rxBlocks, txBlocks, commandBlocks);

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
end
