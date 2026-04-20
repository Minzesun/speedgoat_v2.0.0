function value = controlword(action)
switch char(action)
    case 'disable_voltage'
        value = uint16(hex2dec('0000'));
    case 'shutdown'
        value = uint16(hex2dec('0006'));
    case 'switch_on'
        value = uint16(hex2dec('0007'));
    case 'enable_operation'
        value = uint16(hex2dec('000F'));
    otherwise
        error('sgv2:UnknownControlwordAction', 'Unknown action: %s', char(action));
end
end
