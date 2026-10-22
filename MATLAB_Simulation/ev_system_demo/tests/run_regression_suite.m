function report = run_regression_suite()
% RUN_REGRESSION_SUITE Run headless checks across every integrated scenario.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(projectRoot));
catalog = ev_scenario_catalog();
S = ev_state_definitions();
report = struct('scenario',{},'pass',{},'maxSpeedKph',{},'finalState',{},'faultSeen',{});
for k = 1:numel(catalog)
    log = run_ev_scenario(catalog(k).key);
    assert(all(isfinite(log.time)) && all(isfinite(log.vehicleSpeedKph)), ...
        sprintf('Non-finite core plant output in %s.',catalog(k).key));
    P = ev_demo_config();
    assert(all(abs(log.torqueActualNm) <= 1.01*max(P.maxDriveTorqueNm,P.maxRegenTorqueNm)), ...
        sprintf('Torque limit exceeded in %s.',catalog(k).key));
    switch catalog(k).key
        case 'startup'
            assert(any(log.state == S.OFF) && any(log.state == S.READY) && any(log.state == S.DRIVE), ...
                'Startup scenario missed OFF/READY/DRIVE state.');
        case 'acceleration'
            assert(max(log.vehicleSpeedKph) <= 47, 'Acceleration scenario violated its demonstration speed cap.');
            assert(any(log.speedControllerTorqueNm > 0) && any(log.speedControllerErrorKph > 0), ...
                'Closed-loop speed controller did not generate a positive drive request.');
        case 'grade'
            assert(any(log.gradeFraction > 0) && any(log.state == S.DRIVE), ...
                'Grade scenario did not combine road load and drive operation.');
        case 'braking'
            assert(any(log.state == S.REGEN) && any(log.frictionBrakeFraction > 0), ...
                'Braking scenario did not exercise regen and friction braking.');
        case 'restart'
            assert(any(log.state == S.OFF) && any(log.state == S.DRIVE), ...
                'Restart scenario did not show shutdown and drive restart.');
        case 'thermal_drift'
            assert(max(log.motorRsTrueOhm)-min(log.motorRsTrueOhm) > 0.003, ...
                'Thermal scenario did not produce winding-resistance drift.');
            assert(log.ekfUpdateCount(end) > 0, ...
                'EKF did not perform an observable parameter update during thermal drift.');
        case 'sensor_fault'
            assert(any(log.faultActive) && any(strcmp(log.faultCode,'SENSOR_RANGE_OR_DROPOUT')), ...
                'Sensor fault was not detected and surfaced.');
        case 'emergency_fault'
            assert(any(strcmp(log.faultCode,'EMERGENCY_STOP')) && any(log.state == S.FAULT), ...
                'Emergency stop did not cause a latched VCU fault.');
        case 'charging'
            assert(any(log.chargerCurrentA > 0) && any(log.state == S.CHARGING), ...
                'Charging scenario did not enable the charger.');
            assert(any(log.balanceCellCount > 0), ...
                'Cell imbalance did not exercise the simulated passive balancing logic.');
        case 'network_loss'
            assert(any(log.networkLostFrames > 0) && any(log.state == S.FAULT), ...
                'Communication loss did not lead to a safe fault state.');
        case 'eco_range'
            assert(any(log.state == S.ECO) && ...
                all(log.speedLimitKph(log.ecoActive) == P.ecoSpeedLimitKph), ...
                'ECO state or its configured speed limit was not applied.');
            normalLog = run_ev_scenario('eco_range','NORMAL');
            ecoLog = run_ev_scenario('eco_range','ECO');
            assert(max(ecoLog.vehicleSpeedKph) <= P.ecoSpeedLimitKph + 1, ...
                'ECO scenario exceeded its capped speed.');
            assert(ecoLog.rangeEstimateKm(end) > normalLog.rangeEstimateKm(end), ...
                'Matched-cycle model did not project greater range in ECO mode.');
        case 'cell_fault'
            assert(any(log.isolationLatched) && any(log.state == S.FAULT), ...
                'Cell voltage fault did not latch pack isolation and VCU fault.');
    end
    assert(all(isfinite(log.torqueActualNm)) && all(isfinite(log.iqA)) && ...
        all(isfinite(log.motorRsEstimateOhm)), ...
        sprintf('Non-finite motor-control signal in %s.',catalog(k).key));
    report(k).scenario = catalog(k).key;
    report(k).pass = true;
    report(k).maxSpeedKph = max(log.vehicleSpeedKph);
    report(k).finalState = log.state(end);
    report(k).faultSeen = any(log.faultActive);
    fprintf('PASS %-18s max speed %6.1f km/h | final state %d | fault %d\n', ...
        report(k).scenario,report(k).maxSpeedKph,report(k).finalState,report(k).faultSeen);
end
ab = compare_foc_ekf_modes('thermal_drift');
assert(ab.sameInputs,'Fixed/EKF A/B runs did not use identical scenario inputs.');
assert(all(isfinite([ab.fixedMetrics.torqueTrackingRms,ab.ekfMetrics.torqueTrackingRms, ...
    ab.fixedMetrics.parameterErrorRms,ab.ekfMetrics.parameterErrorRms])), ...
    'FOC/EKF comparison metrics are not finite.');
fprintf('Integrated EV regression suite: %d/%d scenarios passed.\n',numel(report),numel(report));
end
