function commandBlocks = addManualCommandInterface(target, controllerBlock)
modelName = char(target.ModelName);

items = { ...
    'command_expected_network_state', sprintf('int32(%d)', target.Ethercat.ExpectedNetworkState), [360 45 520 75], 2; ...
    'command_speed_command_60ff', target.Tunables.SpeedCommand60FF, [360 90 520 120], 7; ...
    'command_speed_limit_607f', target.Tunables.SpeedLimit607F, [360 135 520 165], 8};

for k = 1:size(items, 1)
    blockPath = [modelName '/' items{k, 1}];
    add_block('simulink/Sources/Constant', blockPath, ...
        'Position', items{k, 3}, ...
        'Value', char(items{k, 2}));
    add_line(modelName, [items{k, 1} '/1'], [get_param(controllerBlock, 'Name') '/' num2str(items{k, 4})], 'autorouting', 'on');
    commandBlocks.(matlab.lang.makeValidName(items{k, 1})) = blockPath;
end
end
