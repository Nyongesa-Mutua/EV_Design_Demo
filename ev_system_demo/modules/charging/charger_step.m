function charger = charger_step(plugged, chargingEnabled, soc, voltageV, P, maxChargeLimitA, packPermitted)
% CHARGER_STEP Simplified onboard charger; output current is positive into pack.
if nargin < 6 || isempty(maxChargeLimitA), maxChargeLimitA = P.maxChargeA; end
if nargin < 7, packPermitted = true; end
charger.plugged = logical(plugged);
charger.enabled = logical(plugged && chargingEnabled && packPermitted && ...
    soc < P.maxChargeSoc && maxChargeLimitA > 0);
if charger.enabled && voltageV > 0
    charger.currentA = min(P.chargerPowerKw*1000/voltageV, ...
        min(P.maxChargeA,maxChargeLimitA));
else
    charger.currentA = 0;
end
charger.powerKw = voltageV * charger.currentA / 1000;
charger.status = 'DISCONNECTED';
if charger.plugged
    charger.status = 'CONNECTED_UNSPECIFIED_PROTOCOL';
end
if charger.enabled
    charger.status = 'SIMULATED_CHARGING';
end
charger.protocol = P.chargerProtocol;
charger.protocolNegotiated = false;
charger.communicationValidated = false;
end
