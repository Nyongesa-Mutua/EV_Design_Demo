function log = run_ev_scenario(scenarioKey, driveModeOverride, motorControlMode)
% RUN_EV_SCENARIO Integrated vehicle software-in-the-loop run.
% Optional overrides: drive mode ('NORMAL'/'ECO'), motor mode ('fixed'/'ekf').
% All numerical parameters are illustrative until calibrated with hardware data.
% Make direct calls work even when the caller has not configured the MATLAB
% path through run_ev_system_demo.
if exist('ev_demo_config','file') ~= 2 || exist('pmsm_foc_ekf_step','file') ~= 2
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(projectRoot));
end
if exist('pmsm_foc_ekf_step','file') ~= 2
    error('The EKF controller pmsm_foc_ekf_step.m could not be linked from the project tree.');
end

P = ev_demo_config();
S = ev_state_definitions();
if nargin < 2, driveModeOverride = ''; end
if nargin < 3 || isempty(motorControlMode), motorControlMode = 'ekf'; end
if ~any(strcmp(motorControlMode,{'fixed','ekf'}))
    error('motorControlMode must be ''fixed'' or ''ekf''.');
end
catalog = ev_scenario_catalog();
match = find(strcmp({catalog.key},scenarioKey),1);
if isempty(match), error('Unknown scenario: %s',scenarioKey); end
scenario = catalog(match);
time = (0:P.dt:scenario.duration)';
N = numel(time);
vehicle = struct('speedMps',0,'positionM',0,'motorSpeedRadS',0, ...
    'speedKph',0,'accelerationMps2',0);
motor = struct('torqueNm',0,'idA',0,'iqA',0,'currentA',0,'speedRpm',0, ...
    'rsOhm',P.motorResistanceOhm,'fluxWb',P.motorFluxWb,'temperatureC',25,'ekfHealthy',true);
bms = struct('soc',0.68,'temperatureC',25,'voltageV',P.nominalVoltage, ...
    'currentA',0,'maxDischargeA',P.maxDischargeA,'maxChargeA',P.maxChargeA, ...
    'contactorClosed',true);
vcu = struct('state',S.OFF,'stateTime',0,'faultLatched',false,'faultCode','OK');
network = struct('online',true,'txFrames',0,'rxFrames',0,'lostFrames',0, ...
    'lastRxTimeS',0,'timeout',false,'health','ONLINE','busLoadFraction',0);
speedController = struct('integralError',0,'errorKph',0,'rawTorqueNm',0, ...
    'torqueRequestNm',0,'targetSpeedKph',0);
log = initialize_log(N);
cumulativeNetEnergyWh = 0;
cumulativeEnergyRecoveredWh = 0;
previousPositionM = 0;

for k = 1:N
    t = time(k);
    driver = scenario_driver_input(scenarioKey,t,P);
    if driver.reset && isfield(motor,'ekfHealthy') && ~motor.ekfHealthy && ...
            ~driver.sensorDropout && ~driver.cellVoltageFault && ...
            ~driver.emergencyStop && ~driver.networkLoss
        motor.ekfHealthy = true;
        motor.ekfX = [motor.idA;motor.iqA;P.motorResistanceOhm;P.motorFluxWb];
        motor.ekfCov = diag([4,4,(0.25*P.motorResistanceOhm)^2, ...
            (0.15*P.motorFluxWb)^2]);
        motor.intD = 0; motor.intQ = 0; motor.vdApplied = 0; motor.vqApplied = 0;
    end
    if ~isempty(driveModeOverride)
        if strcmpi(driveModeOverride,'ECO')
            driver.ecoMode = true; driver.driveMode = 'ECO';
            driver.speedLimitKph = P.ecoSpeedLimitKph;
        elseif strcmpi(driveModeOverride,'NORMAL')
            driver.ecoMode = false; driver.driveMode = 'NORMAL';
            driver.speedLimitKph = P.maxSpeedKph;
        else
            error('driveModeOverride must be ''ECO'' or ''NORMAL''.');
        end
    end

    network = communication_step(network,driver,t,P);
    sensors = sensor_step(vehicle,bms,motor,driver.sensorDropout,t,P);
    diag = diagnostics_step(sensors,bms,network,driver,P);
    [vcu,torqueAllowed] = vcu_step(vcu,driver,diag,bms,P.dt,P);
    charger = charger_step(driver.plugged,vcu.state == S.CHARGING, ...
        bms.soc,bms.voltageV,P,bms.maxChargeA,bms.contactorClosed);

    targetSpeedKph = min(driver.speedLimitKph,driver.speedLimitKph*driver.accelerator);
    if any(vcu.state == [S.DRIVE S.ECO]) && torqueAllowed
        [speedController,speedTorqueRequestNm] = speed_controller_step( ...
            speedController,targetSpeedKph,sensors.speedKph,P.dt,P);
    else
        speedController.integralError = 0;
        if isfinite(sensors.speedKph)
            speedController.errorKph = targetSpeedKph-sensors.speedKph;
        else
            speedController.errorKph = 0;
        end
        speedController.torqueRequestNm = 0;
        speedTorqueRequestNm = 0;
    end
    energy = energy_manager_step(driver,vcu,bms,vehicle.speedKph, ...
        speedTorqueRequestNm,P);
    torqueRequest = energy.torqueRequestNm;
    if ~torqueAllowed, torqueRequest = 0; end

    motor.temperatureC = 25;
    if driver.thermalDrift
        motor.temperatureC = 25+90*min(t/max(scenario.duration,P.dt),1);
    end
    [motor,motorBatteryCurrentA,motorControl] = pmsm_foc_ekf_step( ...
        motor,torqueRequest,vehicle.motorSpeedRadS,bms.voltageV, ...
        motor.temperatureC,P.dt,P,motorControlMode);
    motorBatteryCurrentA = min(max(motorBatteryCurrentA,-bms.maxChargeA),bms.maxDischargeA);
    if ~torqueAllowed
        motor.torqueNm = 0; motor.iqA = 0; motor.idA = 0;
        motor.currentA = 0; motorBatteryCurrentA = 0;
        motor.intD = 0; motor.intQ = 0;
        motor.vdApplied = 0; motor.vqApplied = 0;
    end

    vehicle = vehicle_step(vehicle,motor.torqueNm,energy.frictionBrakeFraction, ...
        driver.grade,P.dt,P);
    batteryCurrentA = motorBatteryCurrentA-charger.currentA;
    bms = bms_step(bms,batteryCurrentA,P.dt,P,driver.cellVoltageFault,driver.reset,t);
    cumulativeNetEnergyWh = cumulativeNetEnergyWh+batteryCurrentA*bms.voltageV*P.dt/3600;
    cumulativeEnergyRecoveredWh = cumulativeEnergyRecoveredWh+ ...
        max(0,-motorBatteryCurrentA*bms.voltageV*P.dt/3600);
    previousPositionM = vehicle.positionM; %#ok<NASGU>
    cumulativeDistanceKm = vehicle.positionM/1000;

    if cumulativeDistanceKm >= 0.5 && cumulativeNetEnergyWh > 20
        consumptionWhPerKm = min(max(cumulativeNetEnergyWh/cumulativeDistanceKm,80),500);
    elseif driver.ecoMode
        consumptionWhPerKm = P.ecoConsumptionWhPerKm;
    else
        consumptionWhPerKm = P.normalConsumptionWhPerKm;
    end
    usableEnergyWh = max(0,bms.soc*P.batteryCapacityAh*P.nominalVoltage);
    rangeEstimateKm = usableEnergyWh/max(consumptionWhPerKm,1);

    log.time(k)=t; log.scenarioKey{k}=scenarioKey; log.state(k)=vcu.state;
    log.faultMask(k)=diag.mask; log.faultActive(k)=diag.active||vcu.faultLatched;
    log.faultCode{k}=diag.primaryCode;
    if vcu.faultLatched, log.faultCode{k}=vcu.faultCode; end
    log.accelerator(k)=driver.accelerator; log.brake(k)=driver.brake;
    log.speedRequestKph(k)=targetSpeedKph; log.speedLimitKph(k)=driver.speedLimitKph;
    log.speedControllerErrorKph(k)=speedController.errorKph;
    log.speedControllerTorqueNm(k)=speedTorqueRequestNm;
    log.vehicleSpeedKph(k)=vehicle.speedKph;
    log.motorSpeedRpm(k)=motor.speedRpm;
    log.torqueRequestNm(k)=torqueRequest; log.torqueActualNm(k)=motor.torqueNm;
    log.idA(k)=motor.idA; log.iqA(k)=motor.iqA;
    log.idReferenceA(k)=motorControl.idReferenceA;
    log.iqReferenceA(k)=motorControl.iqReferenceA;
    log.idFeedbackA(k)=motorControl.idFeedbackA;
    log.iqFeedbackA(k)=motorControl.iqFeedbackA;
    log.motorRsTrueOhm(k)=motor.rsOhm;
    log.motorRsEstimateOhm(k)=motorControl.rsEstimateOhm;
    log.motorRsControlOhm(k)=motorControl.rsControlOhm;
    log.fluxTrueWb(k)=motor.fluxWb;
    log.fluxEstimateWb(k)=motorControl.fluxEstimateWb;
    log.fluxControlWb(k)=motorControl.fluxControlWb;
    log.ekfMode(k)=motorControl.ekfEnabled;
    log.ekfHealthy(k)=motorControl.ekfHealthy;
    log.ekfAdaptationEnabled(k)=motorControl.ekfAdaptationEnabled;
    log.ekfUpdateCount(k)=motorControl.ekfUpdates;
    log.dcBusVoltageV(k)=bms.voltageV; log.batteryCurrentA(k)=bms.currentA;
    log.batterySoc(k)=bms.soc; log.batteryTemperatureC(k)=bms.temperatureC;
    log.motorTemperatureC(k)=motor.temperatureC;
    log.chargerPowerKw(k)=charger.powerKw; log.chargerCurrentA(k)=charger.currentA;
    log.chargerStatus{k}=charger.status; log.chargerProtocol{k}=P.chargerProtocol;
    log.energyRecoveredWh(k)=max(0,-motorBatteryCurrentA*bms.voltageV*P.dt/3600);
    log.cumulativeEnergyRecoveredWh(k)=cumulativeEnergyRecoveredWh;
    log.frictionBrakeFraction(k)=energy.frictionBrakeFraction;
    log.gradeFraction(k)=driver.grade; log.driveMode{k}=energy.driveMode;
    log.speedSensorKph(k)=sensors.speedKph; log.sensorValid(k)=sensors.valid;
    log.networkOnline(k)=network.online; log.networkTxFrames(k)=network.txFrames;
    log.networkRxFrames(k)=network.rxFrames; log.networkLostFrames(k)=network.lostFrames;
    log.networkBusLoadFraction(k)=network.busLoadFraction;
    log.contactorClosed(k)=bms.contactorClosed; log.isolationLatched(k)=bms.isolationLatched;
    log.cellVoltageMinV(k)=bms.cellVoltageMinV; log.cellVoltageMaxV(k)=bms.cellVoltageMaxV;
    log.cellVoltageSpreadV(k)=bms.cellVoltageSpreadV; log.cellTemperatureMaxC(k)=bms.temperatureC;
    log.cellTemperatureSensorMaxC(k)=max(bms.cellTemperatureMeasurementC);
    log.balanceCellCount(k)=sum(bms.balanceActive);
    log.ecoActive(k)=vcu.state==S.ECO; log.gearDirection{k}=drive_direction(vcu.state,S);
    log.motorPowerKw(k)=motor.torqueNm*vehicle.motorSpeedRadS/1000;
    log.cumulativeNetEnergyWh(k)=cumulativeNetEnergyWh;
    log.cumulativeDistanceKm(k)=cumulativeDistanceKm;
    log.rangeConsumptionWhPerKm(k)=consumptionWhPerKm; log.rangeEstimateKm(k)=rangeEstimateKm;
    log.batteryLowWarning(k)=bms.soc<0.15;
    log.batteryHotWarning(k)=bms.temperatureC>=P.maxBatteryTempC;
    log.motorHotWarning(k)=motor.temperatureC>=100;
    log.interlockOk(k)=~diag.active&&bms.contactorClosed;
end
log.scenarioDescription=scenario.name;
log.sampleTimeS=P.dt;
log.motorControlMode=motorControlMode;
log.parameterStatus=P.parameterStatus;
log.assumptions='Simulation only: generic PMSM, generic pack-cell curve, unspecified charger protocol and illustrative CAN timing.';
end

function direction = drive_direction(state,S)
if any(state == [S.DRIVE S.ECO S.REGEN]), direction='D';
elseif any(state == [S.OFF S.CHARGING S.FAULT]), direction='P';
else, direction='N'; end
end

function log = initialize_log(N)
numericFields={'time','state','faultMask','accelerator','brake','speedRequestKph','speedLimitKph', ...
    'speedControllerErrorKph','speedControllerTorqueNm','vehicleSpeedKph','motorSpeedRpm', ...
    'torqueRequestNm','torqueActualNm','idA','iqA','idReferenceA','iqReferenceA', ...
    'idFeedbackA','iqFeedbackA', ...
    'motorRsTrueOhm','motorRsEstimateOhm','motorRsControlOhm','fluxTrueWb','fluxEstimateWb', ...
    'fluxControlWb','ekfUpdateCount','dcBusVoltageV','batteryCurrentA','batterySoc', ...
    'batteryTemperatureC','motorTemperatureC','chargerPowerKw','chargerCurrentA', ...
    'energyRecoveredWh','cumulativeEnergyRecoveredWh','frictionBrakeFraction','gradeFraction', ...
    'networkTxFrames','networkRxFrames','networkLostFrames','networkBusLoadFraction', ...
    'motorPowerKw','cumulativeNetEnergyWh','cumulativeDistanceKm','rangeConsumptionWhPerKm', ...
    'rangeEstimateKm','cellVoltageMinV','cellVoltageMaxV','cellVoltageSpreadV', ...
    'cellTemperatureMaxC','cellTemperatureSensorMaxC','balanceCellCount'};
for n=1:numel(numericFields), log.(numericFields{n})=zeros(N,1); end
logicalFields={'faultActive','sensorValid','contactorClosed','ecoActive','batteryLowWarning', ...
    'batteryHotWarning','motorHotWarning','interlockOk','ekfMode','ekfAdaptationEnabled', ...
    'ekfHealthy','isolationLatched','networkOnline'};
for n=1:numel(logicalFields), log.(logicalFields{n})=false(N,1); end
textFields={'scenarioKey','faultCode','driveMode','gearDirection','chargerStatus','chargerProtocol'};
for n=1:numel(textFields), log.(textFields{n})=cell(N,1); end
end
