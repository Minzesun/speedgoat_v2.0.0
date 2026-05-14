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
    'DefaultParameterBehavior', 'Inlined', ...
    'SystemTargetFile', 'slrealtime.tlc');

localSeedModelWorkspaceDefaults(target);

[controllerBlock, getStateBlock, rxBlocks, txBlocks] = sgv2.internal.addEthercatIo(target);
referenceBlocks = sgv2.internal.addPositionReferenceSource(target, controllerBlock, rxBlocks.positionActual6064);
[positionLoopBlock, positionLoopCommandDelayBlock] = sgv2.internal.addPositionLoopController( ...
    target, controllerBlock, rxBlocks.positionActual6064, referenceBlocks);
commandBlocks = sgv2.internal.addManualCommandInterface(target, controllerBlock);
sgv2.internal.addObservabilityPorts(target, controllerBlock, positionLoopBlock, ...
    positionLoopCommandDelayBlock, getStateBlock, rxBlocks, txBlocks, commandBlocks, referenceBlocks);
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
localAssignTunable(modelWorkspace, char(target.Tunables.SpeedCommand60FF), ...
    target.AxisConfig.DefaultSafeVelocity60FF);
localAssignTunable(modelWorkspace, char(target.Tunables.SpeedLimit607F), ...
    target.AxisConfig.DefaultMaxProfileVelocity607F);
reference = sgv2.internal.loadPositionReferenceTxt(target);
assignin(modelWorkspace, char(reference.PositionVariableName), ...
    reference.PositionValues6064);
assignin(modelWorkspace, char(reference.RateVariableName), ...
    reference.RateValues6064);
assignin(modelWorkspace, char(reference.CountVariableName), ...
    reference.SampleCount);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionReferenceFeedforwardEnabled), ...
    target.AxisConfig.DefaultPositionReferenceFeedforwardEnabled);
localAssignTunable(modelWorkspace, char(target.Tunables.ReferencePlayRequest), ...
    target.AxisConfig.DefaultReferencePlayRequest);
localAssignTunable(modelWorkspace, char(target.Tunables.HomeToZeroRequest), ...
    target.AxisConfig.DefaultHomeToZeroRequest);
localAssignTunable(modelWorkspace, char(target.Tunables.HomeToZeroSpeed), ...
    target.AxisConfig.DefaultHomeToZeroSpeed);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionVelocityGain), ...
    target.AxisConfig.DefaultPositionVelocityGain);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionVelocityBias), ...
    target.AxisConfig.DefaultPositionVelocityBias);
localAssignTunable(modelWorkspace, char(target.Tunables.CommandDeadband), ...
    target.AxisConfig.DefaultCommandDeadband);
localAssignTunable(modelWorkspace, char(target.Tunables.CommandDelaySamples), ...
    target.AxisConfig.DefaultCommandDelaySamples);
localAssignTunable(modelWorkspace, char(target.Tunables.MaxTrackingSpeed), ...
    target.AxisConfig.DefaultMaxTrackingSpeed);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionUnitMillimetersPerCount6064), ...
    target.AxisConfig.DefaultPositionUnitMillimetersPerCount6064);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionLoopKp), ...
    target.AxisConfig.DefaultPositionLoopKp);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionLoopKi), ...
    target.AxisConfig.DefaultPositionLoopKi);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionLoopKd), ...
    target.AxisConfig.DefaultPositionLoopKd);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionLoopSampleTime), ...
    target.AxisConfig.DefaultPositionLoopSampleTime);
localAssignTunable(modelWorkspace, char(target.Tunables.PositionLoopIntegratorLimit), ...
    target.AxisConfig.DefaultPositionLoopIntegratorLimit);
end

function localAssignTunable(modelWorkspace, name, value)
parameter = Simulink.Parameter(value);
parameter.CoderInfo.StorageClass = 'ExportedGlobal';
assignin(modelWorkspace, name, parameter);
end
