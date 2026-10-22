function S = ev_state_definitions()
% EV_STATE_DEFINITIONS Shared VCU state identifiers and dashboard labels.
S.OFF = 1;
S.PRECHARGE = 2;
S.READY = 3;
S.DRIVE = 4;
S.REGEN = 5;
S.CHARGING = 6;
S.FAULT = 7;
S.ECO = 8;
S.names = {'OFF','PRECHARGE','READY','DRIVE','REGEN','CHARGING','FAULT','ECO'};
end
