function state = statusState(statusword)
sw = uint16(statusword);

if bitand(sw, uint16(hex2dec('004F'))) == uint16(hex2dec('0008'))
    state = uint8(10);
elseif bitand(sw, uint16(hex2dec('006F'))) == uint16(hex2dec('0027'))
    state = uint8(4);
elseif bitand(sw, uint16(hex2dec('006F'))) == uint16(hex2dec('0023'))
    state = uint8(3);
elseif bitand(sw, uint16(hex2dec('006F'))) == uint16(hex2dec('0021'))
    state = uint8(2);
elseif bitand(sw, uint16(hex2dec('004F'))) == uint16(hex2dec('0040'))
    state = uint8(1);
else
    state = uint8(0);
end
end
