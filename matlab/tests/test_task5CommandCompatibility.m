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

function testRawSlbuildWorksWithoutManualBaseWorkspaceTunables(testCase)
target = target_minimal_slrtexplorer();
modelName = char(target.ModelName);
matlabRoot = fileparts(fileparts(mfilename('fullpath')));
originalDir = pwd;
cd(matlabRoot);
dirCleanup = onCleanup(@() cd(originalDir));

build_speedgoat_v2_minimal();
evalin('base', 'clear(''SGV2_SPEED_COMMAND_60FF'', ''SGV2_SPEED_LIMIT_607F'')');

closeLoadedModel(modelName);
load_system(modelName);
closeCleanup = onCleanup(@() closeLoadedModel(modelName));

thrown = [];
try
    slbuild(modelName);
catch ME
    thrown = ME;
end

verifyEmpty(testCase, thrown, ...
    'Expected raw load_system + slbuild to work without manual base-workspace tunables.');
clear closeCleanup;
clear dirCleanup;
end

function closeLoadedModel(modelName)
if bdIsLoaded(modelName)
    set_param(modelName, 'Dirty', 'off');
    close_system(modelName, 0);
end
end
