function comparison = compare_foc_ekf_modes(scenarioKey)
% COMPARE_FOC_EKF_MODES Matched fixed-parameter and adaptive-EKF vehicle runs.
% Both use the same deterministic scenario, inputs, plant parameters, and sensors.
if nargin < 1
    scenarioKey = 'thermal_drift';
end
comparison.scenarioKey = scenarioKey;
comparison.fixed = run_ev_scenario(scenarioKey,'','fixed');
comparison.ekf = run_ev_scenario(scenarioKey,'','ekf');
comparison.fixedMetrics = calculate_metrics(comparison.fixed);
comparison.ekfMetrics = calculate_metrics(comparison.ekf);
comparison.parameterErrorImprovementPct = relative_improvement( ...
    comparison.fixedMetrics.parameterErrorRms,comparison.ekfMetrics.parameterErrorRms);
comparison.torqueErrorImprovementPct = relative_improvement( ...
    comparison.fixedMetrics.torqueTrackingRms,comparison.ekfMetrics.torqueTrackingRms);
comparison.currentErrorImprovementPct = relative_improvement( ...
    comparison.fixedMetrics.currentTrackingRms,comparison.ekfMetrics.currentTrackingRms);
comparison.speedErrorImprovementPct = relative_improvement( ...
    comparison.fixedMetrics.speedTrackingRmsKph,comparison.ekfMetrics.speedTrackingRmsKph);
comparison.sameInputs = isequal(comparison.fixed.accelerator,comparison.ekf.accelerator) && ...
    isequal(comparison.fixed.brake,comparison.ekf.brake) && ...
    isequal(comparison.fixed.gradeFraction,comparison.ekf.gradeFraction) && ...
    isequal(comparison.fixed.speedRequestKph,comparison.ekf.speedRequestKph);
comparison.conclusion = 'Comparison data only; advantage is not pre-asserted and requires runtime evidence.';
fprintf(['Fixed vs EKF (%s): parameter RMS %.3f%% -> %.3f%%; ' ...
    'torque RMS %.3f -> %.3f Nm; current RMS %.3f -> %.3f A; ' ...
    'speed RMS %.3f -> %.3f km/h.\n'], ...
    scenarioKey,comparison.fixedMetrics.parameterErrorRms,comparison.ekfMetrics.parameterErrorRms, ...
    comparison.fixedMetrics.torqueTrackingRms,comparison.ekfMetrics.torqueTrackingRms, ...
    comparison.fixedMetrics.currentTrackingRms,comparison.ekfMetrics.currentTrackingRms, ...
    comparison.fixedMetrics.speedTrackingRmsKph,comparison.ekfMetrics.speedTrackingRmsKph);
end

function improvementPct = relative_improvement(baseline, adaptive)
improvementPct = 100*(baseline-adaptive)/max(abs(baseline),eps);
end

function metrics = calculate_metrics(log)
metrics.torqueTrackingRms = sqrt(mean((log.torqueRequestNm-log.torqueActualNm).^2));
metrics.currentTrackingRms = sqrt(mean((log.iqReferenceA-log.iqFeedbackA).^2));
metrics.speedTrackingRmsKph = sqrt(mean((log.speedRequestKph-log.vehicleSpeedKph).^2));
rsErrorPct = 100*(log.motorRsEstimateOhm-log.motorRsTrueOhm)./max(abs(log.motorRsTrueOhm),eps);
fluxErrorPct = 100*(log.fluxEstimateWb-log.fluxTrueWb)./max(abs(log.fluxTrueWb),eps);
metrics.rsErrorRmsPct = sqrt(mean(rsErrorPct.^2));
metrics.fluxErrorRmsPct = sqrt(mean(fluxErrorPct.^2));
metrics.parameterErrorRms = sqrt(mean([rsErrorPct(:);fluxErrorPct(:)].^2));
metrics.peakCurrentA = max(hypot(log.idA,log.iqA));
metrics.torqueLimitViolationCount = sum(abs(log.torqueActualNm)>140.01);
metrics.adaptiveUpdates = log.ekfUpdateCount(end);
end
