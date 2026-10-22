function bms = bms_step(bms, batteryCurrentA, dt, P, injectCellFault, resetRequest, timeS)
% BMS_STEP Generic illustrative cell-monitor, passive-balance and isolation model.
% Positive pack current discharges. This is not a cell chemistry/IC validated BMS.
if nargin < 5, injectCellFault = false; end
if nargin < 6, resetRequest = false; end
if nargin < 7, timeS = 0; end
if ~isfield(bms,'cellSoc')
    initialSoc = 0.68 + linspace(-0.012,0.012,P.packSeriesCells)';
    bms.cellSoc = min(max(initialSoc,0),1);
    bms.cellTemperatureC = 25*ones(P.packSeriesCells,1);
    bms.isolationLatched = false;
end
bms.currentA = batteryCurrentA;
cellCurrentA = batteryCurrentA/P.packParallelCells;
cellVoc = P.cellVoltageInterceptV+P.cellVoltageSocSlopeV*bms.cellSoc;
cellVoltageTrue = max(0,cellVoc-cellCurrentA*P.cellResistanceOhm);
bms.cellVoltageV = quantize(cellVoltageTrue+P.cellVoltageSensorOffsetV+ ...
    P.cellVoltageSensorNoiseV*sin((1:P.packSeriesCells)'*0.37+timeS),P.cellVoltageSensorLsbV);
if injectCellFault
    bms.cellVoltageV(1) = P.cellMaxVoltageV+0.08;
end
bms.cellVoltageMinV = min(bms.cellVoltageV);
bms.cellVoltageMaxV = max(bms.cellVoltageV);
bms.cellVoltageSpreadV = bms.cellVoltageMaxV-bms.cellVoltageMinV;

% Passive balancing is enabled only during charge and above the imbalance threshold.
bms.balanceActive = false(P.packSeriesCells,1);
if batteryCurrentA < 0 && bms.cellVoltageSpreadV > P.cellBalanceStartDeltaV
    highCells = bms.cellVoltageV >= bms.cellVoltageMaxV-P.cellBalanceStartDeltaV/2;
    bms.balanceActive = highCells;
end
bleedA = double(bms.balanceActive)*P.cellBalanceCurrentA;
bms.cellSoc = min(max(bms.cellSoc-(cellCurrentA+bleedA)*dt/(P.cellCapacityAh*3600),0),1);
cellHeatW = (cellCurrentA.^2)*P.cellResistanceOhm;
bms.cellTemperatureC = bms.cellTemperatureC + dt*(cellHeatW/900-(bms.cellTemperatureC-25)/900);
bms.cellTemperatureMeasurementC = bms.cellTemperatureC+P.cellTemperatureSensorOffsetC+ ...
    P.cellTemperatureSensorNoiseC*sin((1:P.packSeriesCells)'*0.19+timeS);
bms.cellTempSpreadC = max(bms.cellTemperatureMeasurementC)-min(bms.cellTemperatureMeasurementC);
bms.temperatureC = max(bms.cellTemperatureMeasurementC);
bms.soc = mean(bms.cellSoc);
bms.voltageV = sum(bms.cellVoltageV);
bms.isolationRequested = injectCellFault || ...
    any(bms.cellVoltageV < P.cellMinVoltageV | bms.cellVoltageV > P.cellMaxVoltageV) || ...
    any(bms.cellTemperatureMeasurementC > P.cellTemperatureLimitC) || ...
    bms.cellTempSpreadC > P.cellTemperatureSpreadLimitC;
if bms.isolationRequested
    bms.isolationLatched = true;
elseif resetRequest
    bms.isolationLatched = false;
end
bms.maxDischargeA = P.maxDischargeA*min(1,max(0,(bms.soc-0.02)/0.15));
bms.maxChargeA = P.maxChargeA*min(1,max(0,(0.99-bms.soc)/0.08));
if bms.isolationLatched || bms.temperatureC > P.maxBatteryTempC || bms.soc <= 0.01
    bms.maxDischargeA = 0;
    bms.maxChargeA = 0;
end
bms.contactorClosed = ~bms.isolationLatched && bms.voltageV > 250 && ...
    bms.soc > 0.01 && bms.temperatureC <= P.maxBatteryTempC && ...
    bms.temperatureC >= P.minBatteryTempC;

function value = quantize(value,lsb)
value = round(value/lsb)*lsb;
end
end
