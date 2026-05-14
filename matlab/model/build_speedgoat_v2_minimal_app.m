function appPath = build_speedgoat_v2_minimal_app()
bootstrap_speedgoat_v2_path();
defaults = project_defaults();
target = target_minimal_slrtexplorer();

originalDir = pwd;
cd(defaults.MatlabRoot);
dirCleanup = onCleanup(@() cd(originalDir)); %#ok<NASGU>

localCleanBuildProducts(defaults, target);
build_speedgoat_v2_minimal();
load_system(char(target.GeneratedModelFile));
modelCleanup = onCleanup(@() localCloseLoadedModel(char(target.ModelName))); %#ok<NASGU>
slbuild(char(target.ModelName));
clear modelCleanup;

appPath = fullfile(defaults.MatlabRoot, target.ApplicationName + ".mldatx");
if ~isfile(appPath)
    error('sgv2:ApplicationPackageMissing', ...
        'Expected application package at %s.', appPath);
end

legacyAppPath = fullfile(defaults.ModelRoot, target.ApplicationName + ".mldatx");
if ~strcmp(appPath, legacyAppPath)
    copyfile(appPath, legacyAppPath, 'f');
end

localAssertPackageContainsTunables(appPath);
localAssertPackageContainsTunables(legacyAppPath);
end

function localCleanBuildProducts(defaults, target)
roots = [defaults.MatlabRoot, defaults.ModelRoot];
for k = 1:numel(roots)
    localDeleteFileIfExists(fullfile(roots(k), target.ApplicationName + ".mldatx"));
    localDeleteFileIfExists(fullfile(roots(k), target.ApplicationName + ".slxc"));
    localRemoveDirIfExists(fullfile(roots(k), target.ApplicationName + "_slrealtime_rtw"));
end
end

function localDeleteFileIfExists(path)
if isfile(path)
    delete(path);
end
end

function localRemoveDirIfExists(path)
if isfolder(path)
    rmdir(path, 's');
end
end

function localCloseLoadedModel(modelName)
if bdIsLoaded(modelName)
    set_param(modelName, 'Dirty', 'off');
    close_system(modelName, 0);
end
end

function localAssertPackageContainsTunables(appPath)
tempRoot = tempname;
mkdir(tempRoot);
cleanup = onCleanup(@() rmdir(tempRoot, 's')); %#ok<NASGU>
unzip(appPath, tempRoot);

paramInfoPath = fullfile(tempRoot, 'paramSet', 'paramInfo.json');
paramInfo = fileread(paramInfoPath);

requiredTokens = { ...
    'SGV2_POSITION_REFERENCE_FEEDFORWARD_ENABLED'
    'SGV2_POSITION_LOOP_KP'
    'SGV2_POSITION_LOOP_KI'
    'SGV2_POSITION_LOOP_KD'
    'SGV2_MAX_TRACKING_SPEED'};

for k = 1:numel(requiredTokens)
    if ~contains(paramInfo, requiredTokens{k})
        error('sgv2:ApplicationPackageMissingTunables', ...
            'Package %s is missing %s.', appPath, requiredTokens{k});
    end
end

forbiddenTokens = { ...
    'SGV2_POSITION_LOOP_ENABLED'
    'SGV2_POSITION_REFERENCE_VALUES_6064'
    'SGV2_POSITION_RATE_REFERENCE_VALUES_6064'};
for k = 1:numel(forbiddenTokens)
    if contains(paramInfo, forbiddenTokens{k})
        error('sgv2:ApplicationPackageForbiddenTunable', ...
            'Package %s still exposes %s.', appPath, forbiddenTokens{k});
    end
end
end
