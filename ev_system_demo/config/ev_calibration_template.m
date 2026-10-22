function calibration = ev_calibration_template()
% EV_CALIBRATION_TEMPLATE Override only values supported by measurements.
% This starts empty deliberately: do not treat example values as calibration.
% Example MATLAB workflow:
%   C = ev_calibration_template();
%   C.motorResistanceOhm = measuredRsOhm;
%   C.motorLd = measuredLdH;
%   P = ev_demo_config(C);
calibration = struct();
% Candidate measured parameters include:
% vehicle: massKg, gearRatio, wheelRadiusM, rollingCoefficient, dragAreaM2
% motor: motorResistanceOhm, motorLd, motorLq, motorFluxWb, motorPolePairs
% battery: batteryCapacityAh, batteryResistanceOhm, packSeriesCells, packParallelCells
% sensors: sensorSpeedOffsetKph, sensorVoltageOffsetV, ADC LSB/noise fields
% controllers: speed gains and current-loop PI gains (after system identification)
% Add a provenance/conditions record to a separate experiment log before using.
end
