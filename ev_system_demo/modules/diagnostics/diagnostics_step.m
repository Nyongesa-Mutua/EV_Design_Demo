function diag = diagnostics_step(sensors, bms, network, driver, P)
% DIAGNOSTICS_STEP Aggregate plausibility, BMS, and communication faults.
% Bit assignments: 1 sensor, 2 BMS, 4 network timeout, 8 pedal, 16 emergency,
% 32 overcurrent, 64 cell isolation, 128 bus load, 256 EKF numerical-health.
diag.mask = 0;
diag.primaryCode = 'OK';
if ~sensors.valid || ~isfinite(sensors.speedKph) || sensors.dcVoltageV < 250 || sensors.dcVoltageV > 450
    diag.mask = diag.mask + 1;
    diag.primaryCode = 'SENSOR_RANGE_OR_DROPOUT';
end
if bms.temperatureC > P.maxBatteryTempC || bms.temperatureC < P.minBatteryTempC || bms.soc <= 0.01
    diag.mask = diag.mask + 2;
    if diag.mask == 2
        diag.primaryCode = 'BMS_LIMIT';
    end
end
if isfield(bms,'isolationRequested') && bms.isolationRequested
    diag.mask = diag.mask + 64;
    diag.primaryCode = 'CELL_LIMIT_ISOLATION_REQUEST';
end
if network.timeout
    diag.mask = diag.mask + 4;
    if diag.mask == 4
        diag.primaryCode = 'COMMUNICATION_TIMEOUT';
    end
end
if isfield(network,'busLoadFraction') && network.busLoadFraction > P.canMaxBusLoadFraction
    diag.mask = diag.mask + 128;
    diag.primaryCode = 'COMMUNICATION_BUS_LOAD';
end
if driver.accelerator > 0.2 && driver.brake > 0.2
    diag.mask = diag.mask + 8;
    if diag.mask == 8
        diag.primaryCode = 'PEDAL_PLAUSIBILITY';
    end
end
if driver.emergencyStop
    diag.mask = diag.mask + 16;
    diag.primaryCode = 'EMERGENCY_STOP';
end
if sensors.motorCurrentA > P.maxMotorCurrentA
    diag.mask = diag.mask + 32;
    diag.primaryCode = 'MOTOR_OVERCURRENT';
end
if isfield(sensors,'ekfHealthy') && ~sensors.ekfHealthy
    diag.mask = diag.mask + 256;
    diag.primaryCode = 'EKF_NUMERICAL_HEALTH';
end
if isfield(driver,'injectDtc') && driver.injectDtc ~= 0
    diag.mask = bitor(diag.mask,uint16(driver.injectDtc));
    if strcmp(diag.primaryCode,'OK')
        diag.primaryCode = 'INJECTED_DTC';
    end
end
diag.active = diag.mask ~= 0;
if ~diag.active
    diag.primaryCode = 'OK';
end
end
