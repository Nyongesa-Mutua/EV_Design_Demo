function sensors = sensor_step(vehicle, battery, motor, injectDropout, timeS, P)
% SENSOR_STEP Deterministic noisy sensor layer with a speed dropout injector.
sensors.speedKph = quantize(vehicle.speedKph + P.sensorSpeedOffsetKph + ...
    P.sensorNoiseSpeedKph*sin(1.7*timeS),P.sensorSpeedLsbKph);
sensors.dcVoltageV = quantize(battery.voltageV + P.sensorVoltageOffsetV + ...
    P.sensorNoiseVoltageV*sin(0.9*timeS),P.sensorVoltageLsbV);
sensors.batteryCurrentA = quantize(battery.currentA,P.sensorCurrentLsbA);
sensors.motorCurrentA = quantize(motor.currentA,P.sensorCurrentLsbA);
sensors.motorTemperatureC = motor.temperatureC;
sensors.ekfHealthy = true;
if isfield(motor,'ekfHealthy'), sensors.ekfHealthy = motor.ekfHealthy; end
sensors.valid = true;
if injectDropout
    sensors.speedKph = NaN;
    sensors.valid = false;
end

function value = quantize(value,lsb)
value = round(value/lsb)*lsb;
end
end
