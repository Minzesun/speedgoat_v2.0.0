function hintText = diagLookupHint(messageId)
switch uint8(messageId)
    case sgv2.internal.diagMessageIds().NONE
        hintText = '';
    case sgv2.internal.diagMessageIds().CHECK_ETHERCAT_STATE
        hintText = 'Check EtherCAT manual: Get State / state machine';
    case sgv2.internal.diagMessageIds().CHECK_603F
        hintText = 'Check SV660N manual: 603Fh error code';
    case sgv2.internal.diagMessageIds().CHECK_6041
        hintText = 'Check SV660N manual: 6041h statusword / CiA402';
    case sgv2.internal.diagMessageIds().CHECK_6061
        hintText = 'Check SV660N manual: 6061h mode';
    otherwise
        hintText = '';
end
end
