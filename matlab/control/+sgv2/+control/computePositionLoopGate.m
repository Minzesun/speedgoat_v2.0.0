function gate = computePositionLoopGate(readyToRun, positionLoopEnabledRequest)
gate = logical(positionLoopEnabledRequest) && uint8(readyToRun) == uint8(1);
end
