function [vcu, torqueAllowed] = vcu_step(vcu, driver, diag, bms, dt, P)
% VCU_STEP State machine includes ECO as a distinct torque-limited drive state.
S = ev_state_definitions();
torqueAllowed = false;
if diag.active
    vcu.state = S.FAULT;
    vcu.faultLatched = true;
    vcu.faultCode = diag.primaryCode;
    vcu.stateTime = 0;
elseif vcu.state == S.FAULT
    if driver.reset && ~diag.active
        vcu.state = S.OFF;
        vcu.faultLatched = false;
        vcu.faultCode = 'OK';
        vcu.stateTime = 0;
    end
elseif vcu.state == S.OFF
    if driver.plugged && ~driver.ignition
        vcu.state = S.CHARGING;
        vcu.stateTime = 0;
    elseif driver.ignition && bms.voltageV > 250
        vcu.state = S.PRECHARGE;
        vcu.stateTime = 0;
    end
elseif vcu.state == S.PRECHARGE
    if ~driver.ignition
        vcu.state = S.OFF;
        vcu.stateTime = 0;
    else
        vcu.stateTime = vcu.stateTime + dt;
        if vcu.stateTime >= P.prechargeTimeS && bms.voltageV > 300
            vcu.state = S.READY;
            vcu.stateTime = 0;
        end
    end
elseif vcu.state == S.READY
    if driver.plugged
        vcu.state = S.CHARGING;
    elseif driver.ignition && driver.accelerator > 0.05 && driver.driveRequest
        if driver.ecoMode
            vcu.state = S.ECO;
        else
            vcu.state = S.DRIVE;
        end
    elseif driver.ignition && driver.brake > 0.05
        vcu.state = S.REGEN;
    elseif ~driver.ignition
        vcu.state = S.OFF;
    end
elseif vcu.state == S.DRIVE
    if ~driver.ignition
        vcu.state = S.OFF;
    elseif driver.brake > 0.05 && driver.brake >= driver.accelerator
        vcu.state = S.REGEN;
    elseif driver.accelerator < 0.03
        vcu.state = S.READY;
    elseif driver.ecoMode
        vcu.state = S.ECO;
    end
elseif vcu.state == S.ECO
    if ~driver.ignition
        vcu.state = S.OFF;
    elseif driver.brake > 0.05 && driver.brake >= driver.accelerator
        vcu.state = S.REGEN;
    elseif driver.accelerator < 0.03
        vcu.state = S.READY;
    elseif ~driver.ecoMode
        vcu.state = S.DRIVE;
    end
elseif vcu.state == S.REGEN
    if ~driver.ignition
        vcu.state = S.OFF;
    elseif driver.accelerator > 0.05 && driver.accelerator > driver.brake
        if driver.ecoMode
            vcu.state = S.ECO;
        else
            vcu.state = S.DRIVE;
        end
    elseif driver.brake < 0.03
        vcu.state = S.READY;
    end
elseif vcu.state == S.CHARGING
    if ~driver.plugged || bms.soc >= P.maxChargeSoc
        vcu.state = S.OFF;
    end
end
vcu.faultLatched = vcu.faultLatched || (vcu.state == S.FAULT);
torqueAllowed = any(vcu.state == [S.DRIVE S.ECO S.REGEN]) && ...
    ~vcu.faultLatched && bms.contactorClosed && ~driver.plugged;
end
