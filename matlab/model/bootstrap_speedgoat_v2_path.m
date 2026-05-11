function matlabRoot = bootstrap_speedgoat_v2_path()
modelRoot = fileparts(mfilename('fullpath'));
matlabRoot = fileparts(modelRoot);

sourceRoots = { ...
    fullfile(matlabRoot, 'analysis')
    fullfile(matlabRoot, 'config')
    fullfile(matlabRoot, 'control')
    fullfile(matlabRoot, 'model')
    fullfile(matlabRoot, 'scripts')
    fullfile(matlabRoot, 'tests')};

for k = 1:numel(sourceRoots)
    if isfolder(sourceRoots{k})
        addpath(genpath(sourceRoots{k}));
    end
end
end
