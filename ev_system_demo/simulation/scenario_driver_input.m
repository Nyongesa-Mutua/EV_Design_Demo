function driver = scenario_driver_input(key, timeS, P)
% SCENARIO_DRIVER_INPUT Repeatable bounded inputs for dashboard demonstrations.
driver.ignition = false;
driver.driveRequest = false;
driver.accelerator = 0;
driver.brake = 0;
driver.plugged = false;
driver.reset = false;
driver.emergencyStop = false;
driver.sensorDropout = false;
driver.networkLoss = false;
driver.thermalDrift = false;
driver.cellVoltageFault = false;
driver.grade = 0;
driver.speedLimitKph = P.maxSpeedKph;
driver.ecoMode = false;
driver.driveMode = 'NORMAL';
switch key
    case 'startup'
        driver.ignition = timeS >= 2;
        driver.driveRequest = timeS >= 3.5;
        driver.accelerator = min(0.65, max(0, (timeS-4)/2)*0.65);
        if timeS > 10, driver.accelerator = 0.42; end
        if timeS > 14, driver.brake = 0.55; driver.accelerator = 0; end
    case 'acceleration'
        driver.ignition = timeS >= 0.5;
        driver.driveRequest = true;
        driver.accelerator = min(1, max(0, (timeS-2)/4));
        driver.speedLimitKph = 45; % deliberately reduced to make limiting visible
        if timeS > 13, driver.accelerator = 0.55; driver.driveMode = 'SPORT'; end
    case 'grade'
        driver.ignition = true; driver.driveRequest = true;
        driver.accelerator = 0.58;
        if timeS >= 8 && timeS < 17
            driver.grade = 0.08;
            driver.ecoMode = true;
            driver.driveMode = 'ECO';
        end
        if timeS >= 17, driver.grade = 0.04; driver.accelerator = 0.48; end
    case 'braking'
        driver.ignition = true; driver.driveRequest = true;
        if timeS < 8, driver.accelerator = 0.68;
        elseif timeS < 17, driver.brake = min(0.85, 0.25 + 0.12*(timeS-8));
        end
    case 'restart'
        driver.ignition = (timeS >= 1.5 && timeS < 8) || timeS >= 11;
        driver.driveRequest = true;
        if timeS >= 3 && timeS < 8, driver.accelerator = 0.55; end
        if timeS >= 13, driver.accelerator = 0.45; end
        if timeS >= 20, driver.brake = 0.4; driver.accelerator = 0; end
    case 'thermal_drift'
        driver.ignition = true; driver.driveRequest = true; driver.accelerator = 0.62;
        driver.thermalDrift = true;
    case 'sensor_fault'
        driver.ignition = true; driver.driveRequest = true; driver.accelerator = 0.52;
        driver.sensorDropout = timeS >= 7 && timeS < 11;
        driver.reset = timeS >= 14;
    case 'emergency_fault'
        driver.ignition = true; driver.driveRequest = true; driver.accelerator = 0.5;
        driver.emergencyStop = timeS >= 8 && timeS < 10;
        driver.reset = timeS >= 13;
    case 'charging'
        driver.plugged = true;
        driver.driveMode = 'CHARGE';
    case 'network_loss'
        driver.ignition = true; driver.driveRequest = true; driver.accelerator = 0.5;
        driver.networkLoss = timeS >= 7 && timeS < 10;
        driver.reset = timeS >= 13;
    case 'eco_range'
        driver.ignition = true; driver.driveRequest = true;
        driver.ecoMode = true;
        driver.driveMode = 'ECO';
        driver.speedLimitKph = P.ecoSpeedLimitKph;
        if timeS < 12
            driver.accelerator = min(0.72, max(0, timeS/12*0.72));
        elseif timeS < 68
            driver.accelerator = 0.42;
        elseif timeS < 78
            driver.brake = 0.55;
        end
    case 'cell_fault'
        driver.ignition = true; driver.driveRequest = true; driver.accelerator = 0.35;
        driver.cellVoltageFault = timeS >= 6 && timeS < 10;
        driver.reset = timeS >= 14;
    otherwise
        error('Unknown EV scenario key: %s', key);
end
driver.accelerator = min(1, max(0, driver.accelerator));
driver.brake = min(1, max(0, driver.brake));
if driver.accelerator > 0.2 && driver.brake > 0.2
    driver.accelerator = 0;
end
end
