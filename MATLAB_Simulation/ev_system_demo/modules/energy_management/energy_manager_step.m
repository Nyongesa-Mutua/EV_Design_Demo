function out = energy_manager_step(driver, vcu, bms, speedKph, speedTorqueRequestNm, P)
% ENERGY_MANAGER_STEP Apply mode, speed, battery, and regen-acceptance limits.
S = ev_state_definitions();
modeScale = 1.0;
if vcu.state == S.ECO || strcmp(driver.driveMode, 'ECO')
    modeScale = 0.65;
elseif strcmp(driver.driveMode, 'SPORT')
    modeScale = 1.0;
end
socScale = min(1.0, max(0.25, (bms.soc - 0.02) / 0.18));
request = 0;
if any(vcu.state == [S.DRIVE S.ECO])
    request = speedTorqueRequestNm * modeScale * socScale;
elseif vcu.state == S.REGEN
    regenByBrake = driver.brake * P.maxRegenTorqueNm;
    regenByBattery = bms.maxChargeA * P.motorTorqueConstantNmPerA;
    if speedKph >= 3 && bms.temperatureC < P.maxBatteryTempC
        request = -min([regenByBrake, regenByBattery, P.maxRegenTorqueNm]);
    end
end
% Cut propulsion slightly before the cap to account for motor torque lag.
if speedKph >= max(0, driver.speedLimitKph - 0.5)
    request = min(request, 0);
end
if request > 0
    request = min(request, bms.maxDischargeA * P.motorTorqueConstantNmPerA);
end
request = min(max(request, -P.maxRegenTorqueNm), P.maxDriveTorqueNm);
if ~bms.contactorClosed
    request = 0;
end
out.torqueRequestNm = request;
out.frictionBrakeFraction = min(1, max(0, driver.brake - abs(request)/max(P.maxRegenTorqueNm, 1)));
out.driveMode = driver.driveMode;
end
