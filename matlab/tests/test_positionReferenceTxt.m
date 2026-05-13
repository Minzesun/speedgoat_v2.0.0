function tests = test_positionReferenceTxt
tests = functiontests(localfunctions);
end

function testOneColumnTxtUsesTargetSampleTimeAndComputesRate(testCase)
tempRoot = tempname;
mkdir(tempRoot);
cleanup = onCleanup(@() rmdir(tempRoot, 's')); %#ok<NASGU>
referencePath = fullfile(tempRoot, 'position_reference_6064.txt');
writematrix(int32([0; 0; 2; 5]), referencePath, 'FileType', 'text');

target = target_minimal_slrtexplorer();
target.AxisConfig.DefaultPositionReferenceFile = string(referencePath);

reference = sgv2.internal.loadPositionReferenceTxt(target);

verifyEqual(testCase, reference.FilePath, string(referencePath));
verifyEqual(testCase, reference.SampleTime, target.SampleTime);
verifyEqual(testCase, reference.PositionValues6064, int32([0; 0; 2; 5; 0]));
verifyEqual(testCase, reference.RateValues6064, int32([0; 0; 1000; 1500; 0]));
verifyEqual(testCase, reference.SampleCount, uint32(5));
verifyEqual(testCase, reference.PositionVariableName, "SGV2_POSITION_REFERENCE_VALUES_6064");
verifyEqual(testCase, reference.RateVariableName, "SGV2_POSITION_RATE_REFERENCE_VALUES_6064");
end

function testDefaultReferencePathResolvesFromProjectRoot(testCase)
target = target_minimal_slrtexplorer();
reference = sgv2.internal.loadPositionReferenceTxt(target);

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
expectedPath = fullfile(projectRoot, "data", "reference", "position_reference_6064.txt");
verifyEqual(testCase, reference.FilePath, expectedPath);
verifyGreaterThanOrEqual(testCase, reference.SampleCount, uint32(2));
verifyEqual(testCase, reference.PositionValues6064(end), int32(0));
verifyEqual(testCase, reference.RateValues6064(end), int32(0));
end

function testRejectsInvalidReferenceFiles(testCase)
target = target_minimal_slrtexplorer();

missingTarget = target;
missingTarget.AxisConfig.DefaultPositionReferenceFile = "missing_reference.txt";
verifyError(testCase, @() sgv2.internal.loadPositionReferenceTxt(missingTarget), ...
    'sgv2:PositionReferenceFileMissing');

emptyPath = localWriteText("");
emptyTarget = target;
emptyTarget.AxisConfig.DefaultPositionReferenceFile = string(emptyPath);
verifyError(testCase, @() sgv2.internal.loadPositionReferenceTxt(emptyTarget), ...
    'sgv2:PositionReferenceFileEmpty');

badTextPath = localWriteText("1" + newline + "abc");
badTextTarget = target;
badTextTarget.AxisConfig.DefaultPositionReferenceFile = string(badTextPath);
verifyError(testCase, @() sgv2.internal.loadPositionReferenceTxt(badTextTarget), ...
    'sgv2:PositionReferenceFileInvalid');

nanPath = localWriteText("1" + newline + "NaN");
nanTarget = target;
nanTarget.AxisConfig.DefaultPositionReferenceFile = string(nanPath);
verifyError(testCase, @() sgv2.internal.loadPositionReferenceTxt(nanTarget), ...
    'sgv2:PositionReferenceFileInvalid');
end

function path = localWriteText(text)
tempRoot = tempname;
mkdir(tempRoot);
path = fullfile(tempRoot, 'position_reference_6064.txt');
fid = fopen(path, 'w');
fprintf(fid, '%s', text);
fclose(fid);
end
