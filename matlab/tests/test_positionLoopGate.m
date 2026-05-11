function tests = test_positionLoopGate
tests = functiontests(localfunctions);
end

function testPositionLoopGateDependsOnReadyAndEnableRequest(testCase)
verifyFalse(testCase, sgv2.control.computePositionLoopGate(uint8(0), uint8(1)));
verifyFalse(testCase, sgv2.control.computePositionLoopGate(uint8(1), uint8(0)));
verifyTrue(testCase, sgv2.control.computePositionLoopGate(uint8(1), uint8(1)));
end
