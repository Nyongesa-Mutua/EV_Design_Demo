function P = ev_demo_config(calibration)
% EV_DEMO_CONFIG Illustrative assumptions for the software-in-the-loop demo.
% Replace these values with measured vehicle, motor, pack, and charger data.
P.dt = 0.05;
P.massKg = 1200;
P.gearRatio = 8.4;
P.wheelRadiusM = 0.32;
P.rollingCoefficient = 0.012;
P.dragAreaM2 = 0.62;
P.airDensity = 1.225;
P.gravity = 9.81;
P.maxSpeedKph = 90;
P.ecoSpeedLimitKph = 65;
P.speedControllerKpNmPerKph = 3.2;
P.speedControllerKiNmPerKphS = 0.35;
P.speedControllerAntiWindup = 1.5;
P.maxDriveTorqueNm = 140;
P.maxRegenTorqueNm = 80;
P.maxMotorCurrentA = 250;
P.motorTorqueConstantNmPerA = 0.60;
P.motorEfficiency = 0.92;
P.motorResistanceOhm = 0.015;
P.motorFluxWb = 0.10;
P.motorThermalCoefficient = 0.00393;
P.motorPolePairs = 4;
P.motorLd = 0.4e-3;
P.motorLq = 0.9e-3;
% The dashboard runs many scenario steps synchronously in a MATLAB UI
% callback. This 2 kHz illustrative plant rate keeps those callbacks
% responsive while retaining substantially faster electrical dynamics than
% the 20 Hz vehicle/log rate.
P.motorSampleTime = 500e-6;
P.motorKpD = 2*pi*500*P.motorLd;
P.motorKpQ = 2*pi*500*P.motorLq;
P.motorKiD = P.motorKpD*(2*pi*500)/5;
P.motorKiQ = P.motorKpQ*(2*pi*500)/5;
P.motorAntiWindup = 2*pi*500;
P.ekfDivider = 10;
P.ekfMinElectricalSpeedRadS = 200;
P.ekfMinCurrentA = 20;
P.motorCurrentSensorOffsetA = 0;
P.motorCurrentSensorNoiseA = 0.5;
P.currentAdcLsbA = 0.25;
P.ekfMeasurementNoiseA = 0.5;
P.ekfProcessNoise = diag([0.04,0.04,0.03^2,0.003^2])*P.motorSampleTime;
P.ekfRsBounds = [0.5*P.motorResistanceOhm,2*P.motorResistanceOhm];
P.ekfFluxBounds = [0.5*P.motorFluxWb,1.2*P.motorFluxWb];
P.batteryCapacityAh = 60;
P.nominalVoltage = 360;
P.packSeriesCells = 96; % generic illustrative voltage-matched series count
P.packParallelCells = 2;
P.cellCapacityAh = P.batteryCapacityAh/P.packParallelCells;
P.cellNominalVoltageV = P.nominalVoltage/P.packSeriesCells;
P.cellResistanceOhm = 0.002;
P.cellVoltageInterceptV = 3.3;
P.cellVoltageSocSlopeV = 0.65;
P.cellVoltageSensorOffsetV = 0;
P.cellVoltageSensorNoiseV = 0.002;
P.cellVoltageSensorLsbV = 0.001;
P.cellMinVoltageV = 2.8;
P.cellMaxVoltageV = 4.25;
P.cellBalanceStartDeltaV = 0.015;
P.cellBalanceCurrentA = 0.05;
P.cellTemperatureLimitC = 60;
P.cellTemperatureSpreadLimitC = 12;
P.cellTemperatureSensorOffsetC = 0;
P.cellTemperatureSensorNoiseC = 0.2;
P.normalConsumptionWhPerKm = 180;
P.ecoConsumptionWhPerKm = 145;
P.batteryResistanceOhm = 0.075;
P.maxDischargeA = 220;
P.maxChargeA = 90;
P.maxBatteryTempC = 60;
P.minBatteryTempC = -10;
P.chargerPowerKw = 7.2;
P.maxChargeSoc = 0.95;
P.maxFrictionBrakeN = 4200;
P.prechargeTimeS = 0.8;
P.sensorNoiseSpeedKph = 0.15;
P.sensorNoiseVoltageV = 0.5;
P.sensorSpeedOffsetKph = 0;
P.sensorVoltageOffsetV = 0;
P.sensorCurrentLsbA = 0.25;
P.sensorVoltageLsbV = 0.1;
P.sensorSpeedLsbKph = 0.1;
P.networkFramePeriodS = 0.05;
P.canBitrateBps = 500000; % illustrative placeholder; confirm the selected STM32 network
P.canNominalBitsPerFrame = 130; % approximate classic-CAN wire occupancy, not a timing guarantee
P.canMaxBusLoadFraction = 0.70; % demonstrator warning threshold only
P.networkTimeoutS = 3*P.networkFramePeriodS;
P.chargerProtocol = 'UNSPECIFIED_DEMO';
P.stm32Family = 'STM32 (exact part not selected)';
P.parameterStatus = 'Illustrative defaults: replace with calibrated component and vehicle data.';
if nargin > 0 && ~isempty(calibration)
	if ~isstruct(calibration) || ~isscalar(calibration)
		error('Calibration input must be a scalar struct of parameter overrides.');
	end
	fields = fieldnames(calibration);
	for k = 1:numel(fields)
		field = fields{k};
		if ~isfield(P,field)
			error('Unknown calibration field: %s',field);
		end
		value = calibration.(field);
		if isnumeric(value) && any(~isfinite(value(:)))
			error('Calibration field %s contains non-finite data.',field);
		end
		P.(field) = value;
	end
	positiveFields = {'massKg','gearRatio','wheelRadiusM','motorResistanceOhm', ...
		'motorLd','motorLq','motorFluxWb','motorSampleTime','motorPolePairs', ...
		'batteryCapacityAh','nominalVoltage','packSeriesCells','packParallelCells', ...
		'maxDischargeA','maxChargeA','sensorCurrentLsbA','sensorVoltageLsbV', ...
		'sensorSpeedLsbKph','cellVoltageSensorLsbV'};
	for k = 1:numel(positiveFields)
		field = positiveFields{k};
		if ~isscalar(P.(field)) || P.(field) <= 0
			error('Calibration field %s must be a positive scalar.',field);
		end
	end
	if P.packSeriesCells ~= round(P.packSeriesCells) || ...
		P.packParallelCells ~= round(P.packParallelCells) || ...
		P.motorPolePairs ~= round(P.motorPolePairs)
		error('Pack cell counts and motorPolePairs must be integers.');
	end
	if ~isfield(calibration,'cellCapacityAh')
		P.cellCapacityAh = P.batteryCapacityAh/P.packParallelCells;
	end
	if ~isfield(calibration,'cellNominalVoltageV')
		P.cellNominalVoltageV = P.nominalVoltage/P.packSeriesCells;
	end
	if ~isfield(calibration,'motorTorqueConstantNmPerA')
		P.motorTorqueConstantNmPerA = 1.5*P.motorPolePairs*P.motorFluxWb;
	end
	if ~isfield(calibration,'motorKpD'), P.motorKpD = 2*pi*500*P.motorLd; end
	if ~isfield(calibration,'motorKpQ'), P.motorKpQ = 2*pi*500*P.motorLq; end
	if ~isfield(calibration,'motorKiD'), P.motorKiD = P.motorKpD*(2*pi*500)/5; end
	if ~isfield(calibration,'motorKiQ'), P.motorKiQ = P.motorKpQ*(2*pi*500)/5; end
	if ~isfield(calibration,'ekfRsBounds')
		P.ekfRsBounds = [0.5*P.motorResistanceOhm,2*P.motorResistanceOhm];
	end
	if ~isfield(calibration,'ekfFluxBounds')
		P.ekfFluxBounds = [0.5*P.motorFluxWb,1.2*P.motorFluxWb];
	end
	if ~isfield(calibration,'ekfProcessNoise')
		P.ekfProcessNoise = diag([0.04,0.04,0.03^2,0.003^2])*P.motorSampleTime;
	end
	P.parameterStatus = 'User-supplied calibration overrides applied; verification still required.';
end
end
