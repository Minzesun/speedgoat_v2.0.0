function tests = test_inverseModel
tests = functiontests(localfunctions);
end

function testComputeInverseFeedforwardAppliesBiasDeadbandAndLimit(testCase)
params = struct( ...
    'PositionVelocityGain', 1.0, ...
    'PositionVelocityBias', 0.0, ...
    'CommandDeadband', 5.0, ...
    'MaxTrackingSpeed', 6000.0);

result = sgv2.control.computeInverseFeedforward([0 10 6010 -6010]', params);

verifyTrue(testCase, result.ModelValid);
verifyEqual(testCase, result.RawSpeedFeedforward60FF, [0 10 6010 -6010]', 'AbsTol', 1e-12);
verifyEqual(testCase, result.SpeedFeedforward60FF, int32([0 10 6000 -6000])');
verifyEqual(testCase, result.DeadbandMask, [true false false false]');
verifyEqual(testCase, result.LimitedMask, [false false true true]');
verifyEqual(testCase, result.FallbackReason, "");
end

function testComputeInverseFeedforwardFallsBackToZeroWhenModelInvalid(testCase)
params = struct( ...
    'PositionVelocityGain', 0.0, ...
    'PositionVelocityBias', 0.0, ...
    'CommandDeadband', 5.0, ...
    'MaxTrackingSpeed', 6000.0);

result = sgv2.control.computeInverseFeedforward([100 -100]', params);

verifyFalse(testCase, result.ModelValid);
verifyEqual(testCase, result.SpeedFeedforward60FF, int32([0 0])');
verifyEqual(testCase, result.FallbackReason, "invalid_position_velocity_gain");
end
