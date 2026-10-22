function [state, sample] = ev_live_simulation(command, state, controls)
% EV_LIVE_SIMULATION Step a persistent, command-driven EV simulation.
% Commands are 'reset' and 'step'. The caller owns the state so multiple
% dashboards or test cases can run independently.
% Keep the live entry point usable when called directly from MATLAB without
% first running run_ev_system_demo.
if exist('ev_demo_config','file') ~= 2 || exist('pmsm_foc_ekf_step','file') ~= 2
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(projectRoot));
end
if exist('pmsm_foc_ekf_step','file') ~= 2
    error('The EKF controller pmsm_foc_ekf_step.m could not be linked from the project tree.');
end

if nargin < 1 || isempty(command), command = 'reset'; end
if strcmpi(command,'reset')
    state = initialize_state();
    sample = state.log;
    return;
end
if ~strcmpi(command,'step')
    error('Live simulation command must be ''reset'' or ''step''.');
end
if nargin < 3 || isempty(controls), controls = struct(); end
if nargin < 2 || isempty(state)
    state = initialize_state();
end

P = state.P;
S = state.S;
t = state.time + P.dt;
driver = default_controls();
names = fieldnames(controls);
for n = 1:numel(names)
    if isfield(driver,names{n}), driver.(names{n}) = controls.(names{n}); end
end
driver.accelerator = min(1,max(0,driver.accelerator));
driver.brake = min(1,max(0,driver.brake));
if driver.accelerator > 0.2 && driver.brake > 0.2
    driver.accelerator = 0;
end

driver.driveRequest = driver.ignition && (driver.accelerator > 0.01 || driver.brake > 0.01);
if driver.ecoMode
    driver.driveMode = 'ECO';
    driver.speedLimitKph = P.ecoSpeedLimitKph;
else
    driver.driveMode = 'NORMAL';
    driver.speedLimitKph = P.maxSpeedKph;
end

state.network = communication_step(state.network,driver,t,P);
sensors = sensor_step(state.vehicle,state.bms,state.motor,driver.sensorDropout,t,P);
diag = diagnostics_step(sensors,state.bms,state.network,driver,P);
[state.vcu,torqueAllowed] = vcu_step(state.vcu,driver,diag,state.bms,P.dt,P);
charger = charger_step(driver.plugged,state.vcu.state == S.CHARGING, ...
    state.bms.soc,state.bms.voltageV,P,state.bms.maxChargeA,state.bms.contactorClosed);

targetSpeedKph = min(driver.speedLimitKph,driver.speedLimitKph*max(driver.accelerator,0.15));
if any(state.vcu.state == [S.DRIVE S.ECO]) && torqueAllowed
    [state.speedController,speedTorqueRequestNm] = speed_controller_step( ...
        state.speedController,targetSpeedKph,sensors.speedKph,P.dt,P);
else
    state.speedController.integralError = 0;
    state.speedController.errorKph = targetSpeedKph-sensors.speedKph;
    state.speedController.torqueRequestNm = 0;
    speedTorqueRequestNm = 0;
end
energy = energy_manager_step(driver,state.vcu,state.bms,state.vehicle.speedKph, ...
    speedTorqueRequestNm,P);
torqueRequest = energy.torqueRequestNm;
if ~torqueAllowed, torqueRequest = 0; end

[state.motor,motorBatteryCurrentA,motorControl] = pmsm_foc_ekf_step( ...
    state.motor,torqueRequest,state.vehicle.motorSpeedRadS,state.bms.voltageV, ...
    state.motor.temperatureC,P.dt,P,'ekf');
motorBatteryCurrentA = min(max(motorBatteryCurrentA,-state.bms.maxChargeA), ...
    state.bms.maxDischargeA);
if ~torqueAllowed
    state.motor.torqueNm = 0;
    state.motor.iqA = 0;
    state.motor.idA = 0;
    state.motor.currentA = 0;
    motorBatteryCurrentA = 0;
end
state.vehicle = vehicle_step(state.vehicle,state.motor.torqueNm, ...
    energy.frictionBrakeFraction,driver.grade,P.dt,P);
batteryCurrentA = motorBatteryCurrentA-charger.currentA;
state.bms = bms_step(state.bms,batteryCurrentA,P.dt,P,false,driver.reset,t);

state.time = t;
state.distanceKm = state.vehicle.positionM/1000;
state.energyWh = state.energyWh+batteryCurrentA*state.bms.voltageV*P.dt/3600;
state.recoveredWh = state.recoveredWh+max(0, ...
    -motorBatteryCurrentA*state.bms.voltageV*P.dt/3600);
if driver.ecoMode
    consumption = P.ecoConsumptionWhPerKm;
else
    consumption = P.normalConsumptionWhPerKm;
end
usableEnergyWh = max(0,state.bms.soc*P.batteryCapacityAh*P.nominalVoltage);
rangeEstimateKm = usableEnergyWh/max(consumption,1);

sample = make_sample(state,driver,diag,charger,energy,motorControl, ...
    targetSpeedKph,torqueRequest,consumption,rangeEstimateKm);
state.log = append_sample(state.log,sample);
end

function state = initialize_state()
P = ev_demo_config();
S = ev_state_definitions();
state.P = P;
state.S = S;
state.time = 0;
state.distanceKm = 0;
state.energyWh = 0;
state.recoveredWh = 0;
state.vehicle = struct('speedMps',0,'positionM',0,'motorSpeedRadS',0, ...
    'speedKph',0,'accelerationMps2',0);
state.motor = struct('torqueNm',0,'idA',0,'iqA',0,'currentA',0,'speedRpm',0, ...
    'rsOhm',P.motorResistanceOhm,'fluxWb',P.motorFluxWb,'temperatureC',25, ...
    'ekfHealthy',true);
state.bms = struct('soc',0.68,'temperatureC',25,'voltageV',P.nominalVoltage, ...
    'currentA',0,'maxDischargeA',P.maxDischargeA,'maxChargeA',P.maxChargeA, ...
    'contactorClosed',true);
state.vcu = struct('state',S.OFF,'stateTime',0,'faultLatched',false,'faultCode','OK');
state.network = struct('online',true,'txFrames',0,'rxFrames',0,'lostFrames',0, ...
    'lastRxTimeS',0,'timeout',false,'health','ONLINE','busLoadFraction',0);
state.speedController = struct('integralError',0,'errorKph',0,'rawTorqueNm',0, ...
    'torqueRequestNm',0,'targetSpeedKph',0);
state.log = empty_log();
end

function driver = default_controls()
driver.ignition = true;
driver.accelerator = 0;
driver.brake = 0;
driver.plugged = false;
driver.reset = false;
driver.ecoMode = false;
driver.networkLoss = false;
driver.sensorDropout = false;
driver.emergencyStop = false;
driver.thermalDrift = false;
driver.cellVoltageFault = false;
driver.grade = 0;
driver.injectDtc = 0;
driver.driveMode = 'NORMAL';
driver.speedLimitKph = 90;
driver.driveRequest = true;
end

function sample = make_sample(state,driver,diag,charger,energy,control, ...
    targetSpeedKph,torqueRequest,consumption,rangeEstimateKm)
P = state.P;
sample = empty_log();
sample.time = state.time;
sample.scenarioKey = {'live'};
sample.scenarioDescription = 'Continuous driver-command simulation';
sample.state = state.vcu.state;
sample.faultMask = diag.mask;
sample.faultActive = diag.active || state.vcu.faultLatched;
sample.faultCode = {diag.primaryCode};
if state.vcu.faultLatched, sample.faultCode = {state.vcu.faultCode}; end
sample.accelerator = driver.accelerator; sample.brake = driver.brake;
sample.speedRequestKph = targetSpeedKph; sample.speedLimitKph = driver.speedLimitKph;
sample.speedControllerErrorKph = state.speedController.errorKph;
sample.speedControllerTorqueNm = state.speedController.torqueRequestNm;
sample.vehicleSpeedKph = state.vehicle.speedKph; sample.motorSpeedRpm = state.motor.speedRpm;
sample.torqueRequestNm = torqueRequest; sample.torqueActualNm = state.motor.torqueNm;
sample.idA = state.motor.idA; sample.iqA = state.motor.iqA;
sample.idReferenceA = control.idReferenceA; sample.iqReferenceA = control.iqReferenceA;
sample.idFeedbackA = control.idFeedbackA; sample.iqFeedbackA = control.iqFeedbackA;
sample.motorRsTrueOhm = state.motor.rsOhm; sample.motorRsEstimateOhm = control.rsEstimateOhm;
sample.motorRsControlOhm = control.rsControlOhm; sample.fluxTrueWb = state.motor.fluxWb;
sample.fluxEstimateWb = control.fluxEstimateWb; sample.fluxControlWb = control.fluxControlWb;
sample.ekfMode = true; sample.ekfAdaptationEnabled = control.ekfAdaptationEnabled;
sample.ekfHealthy = control.ekfHealthy; sample.ekfUpdateCount = control.ekfUpdates;
sample.dcBusVoltageV = state.bms.voltageV; sample.batteryCurrentA = state.bms.currentA;
sample.batterySoc = state.bms.soc; sample.batteryTemperatureC = state.bms.temperatureC;
sample.motorTemperatureC = state.motor.temperatureC; sample.chargerPowerKw = charger.powerKw;
sample.chargerCurrentA = charger.currentA; sample.chargerStatus = {charger.status};
sample.chargerProtocol = {P.chargerProtocol}; sample.energyRecoveredWh = ...
    max(0,-state.motor.torqueNm*state.vehicle.motorSpeedRadS*P.dt/3600);
sample.cumulativeEnergyRecoveredWh = state.recoveredWh;
sample.frictionBrakeFraction = energy.frictionBrakeFraction;
sample.gradeFraction = driver.grade; sample.driveMode = {driver.driveMode};
sample.speedSensorKph = state.vehicle.speedKph; sample.sensorValid = true;
sample.networkOnline = state.network.online; sample.networkTxFrames = state.network.txFrames;
sample.networkRxFrames = state.network.rxFrames; sample.networkLostFrames = state.network.lostFrames;
sample.networkBusLoadFraction = state.network.busLoadFraction;
sample.contactorClosed = state.bms.contactorClosed;
sample.isolationLatched = state.bms.isolationLatched;
sample.cellVoltageMinV = state.bms.cellVoltageMinV; sample.cellVoltageMaxV = state.bms.cellVoltageMaxV;
sample.cellVoltageSpreadV = state.bms.cellVoltageSpreadV;
sample.cellTemperatureMaxC = state.bms.temperatureC;
sample.cellTemperatureSensorMaxC = max(state.bms.cellTemperatureMeasurementC);
sample.balanceCellCount = sum(state.bms.balanceActive);
sample.ecoActive = driver.ecoMode; sample.gearDirection = {'D'};
sample.motorPowerKw = state.motor.torqueNm*state.vehicle.motorSpeedRadS/1000;
sample.cumulativeNetEnergyWh = state.energyWh; sample.cumulativeDistanceKm = state.distanceKm;
sample.rangeConsumptionWhPerKm = consumption; sample.rangeEstimateKm = rangeEstimateKm;
sample.batteryLowWarning = state.bms.soc < 0.15;
sample.batteryHotWarning = state.bms.temperatureC >= P.maxBatteryTempC;
sample.motorHotWarning = state.motor.temperatureC >= 100;
sample.interlockOk = ~diag.active && state.bms.contactorClosed;
sample.sampleTimeS = P.dt; sample.motorControlMode = 'ekf';
sample.parameterStatus = P.parameterStatus;
sample.assumptions = 'Continuous software-in-the-loop simulation; illustrative parameters.';
end

function log = empty_log()
numericFields = {'time','state','faultMask','accelerator','brake','speedRequestKph','speedLimitKph', ...
    'speedControllerErrorKph','speedControllerTorqueNm','vehicleSpeedKph','motorSpeedRpm', ...
    'torqueRequestNm','torqueActualNm','idA','iqA','idReferenceA','iqReferenceA','idFeedbackA', ...
    'iqFeedbackA','motorRsTrueOhm','motorRsEstimateOhm','motorRsControlOhm','fluxTrueWb', ...
    'fluxEstimateWb','fluxControlWb','ekfUpdateCount','dcBusVoltageV','batteryCurrentA', ...
    'batterySoc','batteryTemperatureC','motorTemperatureC','chargerPowerKw','chargerCurrentA', ...
    'energyRecoveredWh','cumulativeEnergyRecoveredWh','frictionBrakeFraction','gradeFraction', ...
    'networkTxFrames','networkRxFrames','networkLostFrames','networkBusLoadFraction','motorPowerKw', ...
    'cumulativeNetEnergyWh','cumulativeDistanceKm','rangeConsumptionWhPerKm','rangeEstimateKm', ...
    'cellVoltageMinV','cellVoltageMaxV','cellVoltageSpreadV','cellTemperatureMaxC', ...
    'cellTemperatureSensorMaxC','balanceCellCount'};
for n = 1:numel(numericFields), log.(numericFields{n}) = zeros(0,1); end
logicalFields = {'faultActive','sensorValid','contactorClosed','ecoActive','batteryLowWarning', ...
    'batteryHotWarning','motorHotWarning','interlockOk','ekfMode','ekfAdaptationEnabled', ...
    'ekfHealthy','isolationLatched'};
for n = 1:numel(logicalFields), log.(logicalFields{n}) = false(0,1); end
textFields = {'scenarioKey','faultCode','driveMode','gearDirection','chargerStatus','chargerProtocol'};
for n = 1:numel(textFields), log.(textFields{n}) = cell(0,1); end
log.scenarioDescription = 'Continuous driver-command simulation';
log.sampleTimeS = 0.05; log.motorControlMode = 'ekf';
log.parameterStatus = ''; log.assumptions = '';
end

function log = append_sample(log,sample)
fields = fieldnames(log);
for n = 1:numel(fields)
    field = fields{n};
    if ismember(field,{'scenarioDescription','sampleTimeS','motorControlMode','parameterStatus','assumptions'})
        continue;
    end
    if iscell(log.(field))
        log.(field){end+1,1} = sample.(field){1};
    else
        log.(field)(end+1,1) = sample.(field);
    end
end
maxSamples = 1200;
if numel(log.time) > maxSamples
    fields = fieldnames(log);
    for n = 1:numel(fields)
        field = fields{n};
        if iscell(log.(field))
            log.(field) = log.(field)(end-maxSamples+1:end);
        elseif isnumeric(log.(field)) || islogical(log.(field))
            log.(field) = log.(field)(end-maxSamples+1:end);
        end
    end
end
end
