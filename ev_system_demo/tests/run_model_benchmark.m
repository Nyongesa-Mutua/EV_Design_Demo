function report = run_model_benchmark(scenarioKey)
% RUN_MODEL_BENCHMARK Measures MATLAB host runtime/storage only (not MCU timing).
if nargin < 1, scenarioKey = 'thermal_drift'; end
P = ev_demo_config();
startTime = tic;
log = run_ev_scenario(scenarioKey);
report.hostElapsedSeconds = toc(startTime);
report.samples = numel(log.time);
report.samplePeriodSeconds = P.dt;
report.simulatedDurationSeconds = log.time(end)-log.time(1);
logInfo = whos('log');
report.logBytes = logInfo.bytes;
report.logBytesPerSampleApprox = report.logBytes/max(report.samples,1);
report.target = 'MATLAB host only';
report.embeddedTimingMeasured = false;
report.embeddedMemoryMeasured = false;
fprintf('Host scenario runtime: %.4f s for %.2f simulated s (%d samples).\n', ...
    report.hostElapsedSeconds,report.simulatedDurationSeconds,report.samples);
fprintf('MATLAB log storage: %.1f kB. This is not STM32 RAM/flash/stack usage.\n',report.logBytes/1024);
end
