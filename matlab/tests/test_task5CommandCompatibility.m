function tests = test_task5CommandCompatibility
tests = functiontests(localfunctions);
end

function testFocusedRegressionFilesReturnVertcatCompatibleResults(testCase)
testsRoot = fileparts(mfilename('fullpath'));
names = { ...
    'test_targetConfig'
    'test_modelGeneration'
    'test_sequenceHarness'
    'test_documentContracts'};

for k = 1:numel(names)
    suite = feval(names{k});
    verifyEqual(testCase, size(suite, 2), 1, ...
        sprintf('Expected %s to return an Nx1 test suite.', names{k}));
end
end

function testApplicationBuildExportsPositionTunables(testCase)
target = target_minimal_slrtexplorer();
modelName = char(target.ModelName);
matlabRoot = fileparts(fileparts(mfilename('fullpath')));
originalDir = pwd;
cd(matlabRoot);
dirCleanup = onCleanup(@() cd(originalDir));

evalin('base', ['clear(' ...
    '''SGV2_SPEED_COMMAND_60FF'', ' ...
    '''SGV2_SPEED_LIMIT_607F'', ' ...
    '''SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED'')']);

appPath = build_speedgoat_v2_minimal_app();
verifyTrue(testCase, isfile(appPath));
verifyPackageContainsPositionTunables(testCase, appPath);

legacyAppPath = fullfile(matlabRoot, 'model', [modelName '.mldatx']);
verifyTrue(testCase, isfile(legacyAppPath));
verifyPackageContainsPositionTunables(testCase, legacyAppPath);

clear dirCleanup;
end

function testApplicationBuildBootstrapsProjectPath(testCase)
target = target_minimal_slrtexplorer();
modelName = char(target.ModelName);
matlabRoot = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
originalDir = pwd;
cleanup = onCleanup(@() localRestoreMatlabState(originalPath, originalDir, modelName)); %#ok<NASGU>

rmpath(genpath(matlabRoot));
addpath(fullfile(matlabRoot, 'config'));
addpath(fullfile(matlabRoot, 'model'));
cd(matlabRoot);

appPath = build_speedgoat_v2_minimal_app();
verifyTrue(testCase, isfile(appPath));
verifyNotEmpty(testCase, which('sgv2.control.computePositionLoopGate'));
verifyPackageContainsPositionTunables(testCase, appPath);

clear cleanup;
end

function closeLoadedModel(modelName)
if bdIsLoaded(modelName)
    set_param(modelName, 'Dirty', 'off');
    close_system(modelName, 0);
end
end

function localRestoreMatlabState(originalPath, originalDir, modelName)
closeLoadedModel(modelName);
path(originalPath);
cd(originalDir);
end

function verifyPackageContainsPositionTunables(testCase, appPath)
tempRoot = tempname;
mkdir(tempRoot);
cleanup = onCleanup(@() rmdir(tempRoot, 's')); %#ok<NASGU>
unzip(appPath, tempRoot);

paramInfoPath = fullfile(tempRoot, 'paramSet', 'paramInfo.json');
paramInfo = fileread(paramInfoPath);
verifyTrue(testCase, contains(paramInfo, 'SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED'));
verifyFalse(testCase, contains(paramInfo, 'SGV2_POSITION_LOOP_ENABLED'));
verifyTrue(testCase, contains(paramInfo, 'SGV2_POSITION_LOOP_KP'));
verifyTrue(testCase, contains(paramInfo, 'SGV2_POSITION_LOOP_KI'));
verifyTrue(testCase, contains(paramInfo, 'SGV2_POSITION_LOOP_KD'));
verifyTrue(testCase, contains(paramInfo, 'SGV2_MAX_TRACKING_SPEED'));
verifyFalse(testCase, contains(paramInfo, 'SGV2_POSITION_REFERENCE_VALUES_6064'));
verifyFalse(testCase, contains(paramInfo, 'SGV2_POSITION_RATE_REFERENCE_VALUES_6064'));
end
