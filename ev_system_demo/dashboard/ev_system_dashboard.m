function ev_system_dashboard()
% EV_SYSTEM_DASHBOARD Integrated HMI for subsystem navigation and scenario replay.
% Start with run_ev_system_demo from this folder. Values are illustrative
% software-in-the-loop signals, not measured vehicle telemetry.
P = ev_demo_config(); %#ok<NASGU>
S = ev_state_definitions();
catalog = ev_scenario_catalog();
fig = figure('Name','Integrated EV Systems Dashboard','NumberTitle','off', ...
    'Color',[0.055 0.075 0.11],'Position',[60 60 1500 930], ...
    'MenuBar','none','ToolBar','none','Resize','on', ...
    'CloseRequestFcn',@on_close);

uicontrol(fig,'Style','text','String','EV SYSTEMS  /  INTEGRATED SOFTWARE-IN-THE-LOOP', ...
    'Units','normalized','Position',[0.02 0.945 0.58 0.04], ...
    'BackgroundColor',[0.055 0.075 0.11],'ForegroundColor',[0.40 0.91 0.78], ...
    'FontSize',15,'FontWeight','bold','HorizontalAlignment','left');
uicontrol(fig,'Style','text','String','SIMULATION DEMO  |  ASSUMED PARAMETERS  |  NOT HARDWARE VALIDATED', ...
    'Units','normalized','Position',[0.60 0.945 0.38 0.04], ...
    'BackgroundColor',[0.055 0.075 0.11],'ForegroundColor',[0.72 0.78 0.87], ...
    'FontSize',9,'HorizontalAlignment','right');

scenarioPopup = uicontrol(fig,'Style','popupmenu','String',{catalog.name}, ...
    'Units','normalized','Position',[0.02 0.895 0.23 0.042], ...
    'BackgroundColor',[0.13 0.17 0.24],'ForegroundColor',[0.95 0.97 1], ...
    'FontSize',10,'Callback',@on_scenario_selected);
make_button(fig,'RUN SCENARIO',[0.265 0.895 0.12 0.042],@on_run,[0.12 0.55 0.48]);
make_button(fig,'PLAY REPLAY',[0.395 0.895 0.12 0.042],@on_play,[0.12 0.40 0.35]);
make_button(fig,'PAUSE',[0.525 0.895 0.09 0.042],@on_pause,[0.25 0.30 0.40]);
make_button(fig,'RESET',[0.625 0.895 0.08 0.042],@on_reset,[0.25 0.30 0.40]);
make_button(fig,'SAVE LOG',[0.715 0.895 0.10 0.042],@on_save,[0.55 0.36 0.18]);
make_button(fig,'RUN MOTOR STUDIES',[0.825 0.895 0.15 0.042],@on_foc_reference,[0.22 0.32 0.45]);
make_button(fig,'DRIVER COCKPIT',[0.265 0.835 0.17 0.032],@on_open_cockpit,[0.10 0.43 0.39]);
make_button(fig,'COMPARE NORMAL / ECO',[0.455 0.835 0.19 0.032],@on_compare_eco,[0.12 0.40 0.35]);
make_button(fig,'FOC / EKF A-B',[0.665 0.835 0.15 0.032],@on_ekf_evidence,[0.32 0.28 0.52]);
make_button(fig,'START LIVE',[0.02 0.835 0.11 0.032],@on_live_start,[0.10 0.43 0.39]);
make_button(fig,'ACCELERATE',[0.14 0.835 0.11 0.032],@on_accelerate,[0.12 0.55 0.48]);
make_button(fig,'DECELERATE',[0.02 0.795 0.11 0.032],@on_decelerate,[0.85 0.42 0.20]);
make_button(fig,'STOP LIVE',[0.14 0.795 0.11 0.032],@on_live_stop,[0.55 0.28 0.25]);

metricNames = {'VCU STATE','PACK SOC','VEHICLE SPEED','DC BUS','FAULT / DTC'};
metricPositions = [0.02 0.765 0.175 0.068; 0.205 0.765 0.175 0.068; ...
    0.390 0.765 0.175 0.068; 0.575 0.765 0.175 0.068; 0.760 0.765 0.22 0.068];
metricValues = gobjects(1,5);
for m = 1:5
    uipanel(fig,'Units','normalized','Position',metricPositions(m,:), ...
        'BackgroundColor',[0.10 0.14 0.20],'BorderType','line','HighlightColor',[0.20 0.28 0.38]);
    uicontrol(fig,'Style','text','String',metricNames{m},'Units','normalized', ...
        'Position',[metricPositions(m,1)+0.01 metricPositions(m,2)+0.040 metricPositions(m,3)-0.02 0.020], ...
        'BackgroundColor',[0.10 0.14 0.20],'ForegroundColor',[0.60 0.69 0.80], ...
        'FontSize',8,'FontWeight','bold','HorizontalAlignment','left');
    metricValues(m) = uicontrol(fig,'Style','text','String','--','Units','normalized', ...
        'Position',[metricPositions(m,1)+0.01 metricPositions(m,2)+0.008 metricPositions(m,3)-0.02 0.032], ...
        'BackgroundColor',[0.10 0.14 0.20],'ForegroundColor',[0.95 0.97 1], ...
        'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
end

uipanel(fig,'Units','normalized','Position',[0.02 0.075 0.205 0.675], ...
    'BackgroundColor',[0.085 0.11 0.16],'BorderType','line','HighlightColor',[0.20 0.28 0.38]);
uicontrol(fig,'Style','text','String','SYSTEM AREAS','Units','normalized', ...
    'Position',[0.035 0.735 0.17 0.028],'BackgroundColor',[0.085 0.11 0.16], ...
    'ForegroundColor',[0.40 0.91 0.78],'FontSize',10,'FontWeight','bold', ...
    'HorizontalAlignment','left');
moduleNames = {'System architecture','Vehicle control & safety','PMSM / motor control', ...
    'Battery management (BMS)','Charging system','Energy management', ...
    'Sensors & signal conditioning','Diagnostics & fault handling', ...
    'Communication network','Vehicle & road plant','Scenario runner & logger'};
moduleList = uicontrol(fig,'Style','listbox','String',moduleNames,'Value',1, ...
    'Units','normalized','Position',[0.035 0.48 0.175 0.245], ...
    'BackgroundColor',[0.12 0.16 0.22],'ForegroundColor',[0.92 0.95 0.99], ...
    'FontSize',9,'Callback',@on_module_selected);
uicontrol(fig,'Style','text','String','SELECTED AREA / LIVE SIGNALS','Units','normalized', ...
    'Position',[0.035 0.435 0.175 0.03],'BackgroundColor',[0.085 0.11 0.16], ...
    'ForegroundColor',[0.40 0.91 0.78],'FontSize',8,'FontWeight','bold', ...
    'HorizontalAlignment','left');
detailBox = uicontrol(fig,'Style','text','String','','Units','normalized', ...
    'Position',[0.035 0.10 0.175 0.33],'BackgroundColor',[0.085 0.11 0.16], ...
    'ForegroundColor',[0.84 0.88 0.94],'FontSize',9,'HorizontalAlignment','left');

ax1 = axes('Parent',fig,'Position',[0.265 0.56 0.33 0.19],'Color',[0.08 0.11 0.16], ...
    'XColor',[0.75 0.80 0.87],'YColor',[0.75 0.80 0.87]);
ax2 = axes('Parent',fig,'Position',[0.635 0.56 0.33 0.19],'Color',[0.08 0.11 0.16], ...
    'XColor',[0.75 0.80 0.87],'YColor',[0.75 0.80 0.87]);
ax3 = axes('Parent',fig,'Position',[0.265 0.335 0.33 0.19],'Color',[0.08 0.11 0.16], ...
    'XColor',[0.75 0.80 0.87],'YColor',[0.75 0.80 0.87]);
ax4 = axes('Parent',fig,'Position',[0.635 0.335 0.33 0.19],'Color',[0.08 0.11 0.16], ...
    'XColor',[0.75 0.80 0.87],'YColor',[0.75 0.80 0.87]);
ax5 = axes('Parent',fig,'Position',[0.265 0.11 0.33 0.19],'Color',[0.08 0.11 0.16], ...
    'XColor',[0.75 0.80 0.87],'YColor',[0.75 0.80 0.87]);
uipanel(fig,'Units','normalized','Position',[0.635 0.11 0.33 0.19], ...
    'BackgroundColor',[0.08 0.11 0.16],'BorderType','line','HighlightColor',[0.25 0.32 0.42]);
summaryBox = uicontrol(fig,'Style','text','String','','Units','normalized', ...
    'Position',[0.655 0.125 0.29 0.16],'BackgroundColor',[0.08 0.11 0.16], ...
    'ForegroundColor',[0.84 0.88 0.94],'FontSize',10,'HorizontalAlignment','left');

state = struct('catalog',catalog,'states',S,'log',run_ev_scenario(catalog(1).key), ...
    'scenarioIndex',1,'index',1,'playing',false,'timer',[], ...
    'liveMode',false,'liveState',[],'liveControls',struct( ...
    'ignition',true,'accelerator',0,'brake',0,'ecoMode',false,'plugged',false,'reset',false), ...
    'modules',{moduleNames});
setappdata(fig,'evState',state);
setappdata(fig,'scenarioPopup',scenarioPopup);
setappdata(fig,'moduleList',moduleList);
setappdata(fig,'detailBox',detailBox);
setappdata(fig,'summaryBox',summaryBox);
setappdata(fig,'metricValues',metricValues);
setappdata(fig,'axes',[ax1 ax2 ax3 ax4 ax5]);
render_dashboard(fig,1);

    function on_scenario_selected(src,~)
        gui = getappdata(fig,'evState');
        gui.scenarioIndex = get(src,'Value');
        gui.index = 1;
        setappdata(fig,'evState',gui);
        run_selected_scenario(fig);
    end
    function on_run(~,~), run_selected_scenario(fig); end
    function on_live_start(~,~)
        gui = getappdata(fig,'evState');
        gui.liveMode = true;
        gui.liveState = ev_live_simulation('reset');
        gui.log = gui.liveState.log;
        gui.index = 0;
        gui.playing = true;
        gui.liveControls.reset = false;
        setappdata(fig,'evState',gui);
        start_live_timer(fig);
    end
    function on_accelerate(~,~)
        gui = getappdata(fig,'evState');
        gui.liveMode = true;
        if isempty(gui.liveState), gui.liveState = ev_live_simulation('reset'); end
        gui.liveControls.ignition = true;
        gui.liveControls.brake = 0;
        gui.liveControls.accelerator = min(1,gui.liveControls.accelerator+0.10);
        gui.playing = true;
        setappdata(fig,'evState',gui);
        start_live_timer(fig);
    end
    function on_decelerate(~,~)
        gui = getappdata(fig,'evState');
        gui.liveMode = true;
        if isempty(gui.liveState), gui.liveState = ev_live_simulation('reset'); end
        gui.liveControls.accelerator = 0;
        gui.liveControls.brake = min(1,gui.liveControls.brake+0.15);
        gui.playing = true;
        setappdata(fig,'evState',gui);
        start_live_timer(fig);
    end
    function on_live_stop(~,~)
        gui = getappdata(fig,'evState');
        gui.liveMode = true;
        gui.liveControls.accelerator = 0;
        gui.liveControls.brake = 0;
        gui.playing = false;
        if ~isempty(gui.timer) && isvalid(gui.timer) && strcmp(gui.timer.Running,'on'), stop(gui.timer); end
        setappdata(fig,'evState',gui);
    end
    function start_live_timer(targetFig)
        gui = getappdata(targetFig,'evState');
        if isempty(gui.timer) || ~isvalid(gui.timer)
            gui.timer = timer('ExecutionMode','fixedRate','Period',0.05, ...
                'TimerFcn',@(~,~) advance_replay(targetFig));
            setappdata(targetFig,'evState',gui);
        end
        if strcmp(gui.timer.Running,'off'), start(gui.timer); end
    end
    function on_play(~,~)
        gui = getappdata(fig,'evState');
        if gui.index >= numel(gui.log.time), gui.index = 1; end
        gui.playing = true;
        if isempty(gui.timer) || ~isvalid(gui.timer)
            gui.timer = timer('ExecutionMode','fixedRate','Period',0.05, ...
                'TimerFcn',@(~,~) advance_replay(fig));
        end
        setappdata(fig,'evState',gui);
        if strcmp(gui.timer.Running,'off'), start(gui.timer); end
    end
    function on_pause(~,~)
        gui = getappdata(fig,'evState'); gui.playing = false;
        if ~isempty(gui.timer) && isvalid(gui.timer) && strcmp(gui.timer.Running,'on'), stop(gui.timer); end
        setappdata(fig,'evState',gui);
    end
    function on_reset(~,~)
        gui = getappdata(fig,'evState'); gui.index = 1; gui.playing = false;
        if ~isempty(gui.timer) && isvalid(gui.timer) && strcmp(gui.timer.Running,'on'), stop(gui.timer); end
        if gui.liveMode
            gui.liveState = ev_live_simulation('reset');
            gui.log = gui.liveState.log;
            gui.index = 0;
            gui.liveControls.accelerator = 0;
            gui.liveControls.brake = 0;
            gui.liveControls.reset = true;
        end
        setappdata(fig,'evState',gui); render_dashboard(fig,1);
    end
    function on_save(~,~)
        gui = getappdata(fig,'evState');
        root = fileparts(fileparts(mfilename('fullpath')));
        resultFolder = fullfile(root,'results');
        if ~exist(resultFolder,'dir'), mkdir(resultFolder); end
        key = gui.catalog(gui.scenarioIndex).key;
        stamp = datestr(now,'yyyymmdd_HHMMSS');
        log = gui.log; %#ok<NASGU>
        save(fullfile(resultFolder,['scenario_' key '_' stamp '.mat']),'log');
        set(metricValues(5),'String','LOG SAVED','ForegroundColor',[0.40 0.91 0.78]);
    end
    function on_foc_reference(~,~)
        if exist('baseline_foc_pmsm','file') == 2 && exist('phase3_foc_ekf','file') == 2
            baseline_foc_pmsm(true);
            phase3_foc_ekf(true);
        else
            errordlg('The baseline and FOC/EKF reference scripts were not found on the MATLAB path.', ...
                'Motor studies unavailable');
        end
    end
    function on_open_cockpit(~,~)
        open_driver_cockpit(fig);
    end
    function on_compare_eco(~,~)
        show_eco_comparison();
    end
    function on_ekf_evidence(~,~)
        show_ekf_evidence();
    end
    function on_module_selected(~,~)
        render_module_detail(fig);
    end
    function on_close(~,~)
        gui = getappdata(fig,'evState');
        if ~isempty(gui.timer) && isvalid(gui.timer)
            stop(gui.timer); delete(gui.timer);
        end
        if isappdata(fig,'driverCockpit')
            cockpit = getappdata(fig,'driverCockpit');
            if isfield(cockpit,'figure') && isgraphics(cockpit.figure)
                delete(cockpit.figure);
            end
        end
        delete(fig);
    end
end

function run_selected_scenario(fig)
gui = getappdata(fig,'evState');
if ~isempty(gui.timer) && isvalid(gui.timer) && strcmp(gui.timer.Running,'on'), stop(gui.timer); end
gui.playing = false;
gui.liveMode = false;
gui.log = run_ev_scenario(gui.catalog(gui.scenarioIndex).key);
gui.index = numel(gui.log.time);
setappdata(fig,'evState',gui);
render_dashboard(fig,gui.index);
end

function advance_replay(fig)
if ~isgraphics(fig), return; end
gui = getappdata(fig,'evState');
if ~gui.playing, return; end
if gui.liveMode
    [gui.liveState,~] = ev_live_simulation('step',gui.liveState,gui.liveControls);
    gui.log = gui.liveState.log;
    gui.index = numel(gui.log.time);
    gui.liveControls.brake = 0;
    gui.liveControls.reset = false;
    setappdata(fig,'evState',gui);
    render_dashboard(fig,gui.index);
    return;
end
gui.index = min(gui.index + 1,numel(gui.log.time));
if gui.index >= numel(gui.log.time)
    gui.playing = false;
    if ~isempty(gui.timer) && isvalid(gui.timer), stop(gui.timer); end
end
setappdata(fig,'evState',gui);
render_dashboard(fig,gui.index);
end

function render_dashboard(fig,idx)
gui = getappdata(fig,'evState');
log = gui.log;
if isempty(log.time)
    axesHandles = getappdata(fig,'axes');
    for n = 1:numel(axesHandles), cla(axesHandles(n)); end
    set(getappdata(fig,'summaryBox'),'String',{'SIMULATION RESET'; ...
        'Press START LIVE or select RUN SCENARIO.'});
    setappdata(fig,'evState',gui);
    drawnow limitrate;
    return;
end
idx = min(max(1,idx),numel(log.time));
ix = 1:idx;
axesHandles = getappdata(fig,'axes');
ax1 = axesHandles(1); ax2 = axesHandles(2); ax3 = axesHandles(3); ax4 = axesHandles(4); ax5 = axesHandles(5);

cla(ax1); hold(ax1,'on');
plot(ax1,log.time(ix),log.vehicleSpeedKph(ix),'Color',[0.20 0.72 1.0],'LineWidth',1.8);
plot(ax1,log.time(ix),log.speedRequestKph(ix),'--','Color',[0.35 0.88 0.61],'LineWidth',1.2);
plot(ax1,log.time(ix),log.speedLimitKph(ix),':','Color',[0.95 0.73 0.31],'LineWidth',1.1);
yyaxis(ax1,'right');
plot(ax1,log.time(ix),log.torqueRequestNm(ix),'--','Color',[1.0 0.73 0.30],'LineWidth',1.1);
plot(ax1,log.time(ix),log.torqueActualNm(ix),'Color',[1.0 0.55 0.32],'LineWidth',1.5);
ylabel(ax1,'Torque [Nm]'); yyaxis(ax1,'left'); ylabel(ax1,'Speed [km/h]');
xlabel(ax1,'Time [s]'); title(ax1,'Road response  |  speed and motor torque','Color',[0.93 0.95 0.98]);
legend(ax1,{'Vehicle speed','Pedal-scaled reference','Active speed limit','Torque request','Torque actual'}, ...
    'Location','northwest','FontSize',7,'TextColor',[0.85 0.89 0.95], ...
    'Color',[0.08 0.11 0.16],'EdgeColor',[0.25 0.32 0.42]);
grid(ax1,'on'); ax1.GridColor = [0.30 0.37 0.47];

cla(ax2); hold(ax2,'on');
plot(ax2,log.time(ix),100*log.batterySoc(ix),'Color',[0.35 0.88 0.61],'LineWidth',1.8);
yyaxis(ax2,'right');
plot(ax2,log.time(ix),log.dcBusVoltageV(ix),'Color',[0.78 0.62 1.0],'LineWidth',1.5);
ylabel(ax2,'DC bus [V]'); yyaxis(ax2,'left'); ylabel(ax2,'SOC [%]');
xlabel(ax2,'Time [s]'); title(ax2,'Battery and charging','Color',[0.93 0.95 0.98]);
grid(ax2,'on'); ax2.GridColor = [0.30 0.37 0.47];

cla(ax3); hold(ax3,'on');
plot(ax3,log.time(ix),log.motorRsTrueOhm(ix),'Color',[0.35 0.88 0.61],'LineWidth',1.6);
plot(ax3,log.time(ix),log.motorRsEstimateOhm(ix),'--','Color',[0.35 0.88 0.61],'LineWidth',1.2);
yyaxis(ax3,'right');
plot(ax3,log.time(ix),log.fluxTrueWb(ix),'Color',[0.78 0.62 1.0],'LineWidth',1.6);
plot(ax3,log.time(ix),log.fluxEstimateWb(ix),'--','Color',[0.78 0.62 1.0],'LineWidth',1.2);
ylabel(ax3,'Flux [Wb]'); yyaxis(ax3,'left'); ylabel(ax3,'R_s [ohm]');
xlabel(ax3,'Time [s]');
title(ax3,'Motor drift / nominal reference (not EKF)','Color',[0.93 0.95 0.98]);
legend(ax3,{'R_s true (sim only)','R_s nominal ref','Flux true (sim only)','Flux nominal ref'}, ...
    'Location','northwest','FontSize',7,'TextColor',[0.85 0.89 0.95], ...
    'Color',[0.08 0.11 0.16],'EdgeColor',[0.25 0.32 0.42]);
grid(ax3,'on'); ax3.GridColor = [0.30 0.37 0.47];

cla(ax4); hold(ax4,'on');
plot(ax4,log.time(ix),log.iqFeedbackA(ix),'Color',[0.20 0.72 1.0],'LineWidth',1.5);
plot(ax4,log.time(ix),log.iqReferenceA(ix),'--','Color',[0.20 0.72 1.0],'LineWidth',1.2);
plot(ax4,log.time(ix),log.idFeedbackA(ix),'Color',[1.0 0.55 0.32],'LineWidth',1.3);
plot(ax4,log.time(ix),log.idReferenceA(ix),'--','Color',[1.0 0.55 0.32],'LineWidth',1.1);
ylabel(ax4,'Current [A]'); xlabel(ax4,'Time [s]');
title(ax4,'FOC dq current tracking (sensor feedback)','Color',[0.93 0.95 0.98]);
legend(ax4,{'i_q','i_q ref','i_d','i_d ref'},'Location','northwest', ...
    'FontSize',7,'TextColor',[0.85 0.89 0.95],'Color',[0.08 0.11 0.16], ...
    'EdgeColor',[0.25 0.32 0.42]);
grid(ax4,'on'); ax4.GridColor = [0.30 0.37 0.47];

cla(ax5); yyaxis(ax5,'left'); hold(ax5,'on');
stairs(ax5,log.time(ix),log.state(ix),'Color',[0.42 0.79 0.95],'LineWidth',1.8);
ylim(ax5,[0.5 8.5]); yticks(ax5,1:8);
yticklabels(ax5,{'OFF','PRECHARGE','READY','DRIVE','REGEN','CHARGING','FAULT','ECO'});
yyaxis(ax5,'right');
plot(ax5,log.time(ix),double(log.faultActive(ix)),'Color',[1.0 0.35 0.38],'LineWidth',1.5);
ylabel(ax5,'Fault active'); ylim(ax5,[-0.1 1.2]);
xlabel(ax5,'Time [s]'); title(ax5,'Vehicle state and fault supervision','Color',[0.93 0.95 0.98]);
grid(ax5,'on'); ax5.GridColor = [0.30 0.37 0.47];

summary = {'INTEGRATED TELEMETRY'; ...
    sprintf('Pack: %.1f%% SOC | %+0.1f A | cell spread %.3f V (%d balancing)', ...
        100*log.batterySoc(idx),log.batteryCurrentA(idx),log.cellVoltageSpreadV(idx), ...
        log.balanceCellCount(idx)); ...
    sprintf('Charger: %.2f kW | %.1f A | %s',log.chargerPowerKw(idx), ...
        log.chargerCurrentA(idx),log.chargerStatus{idx}); ...
    sprintf('Battery / motor temp: %.1f / %.1f deg C',log.batteryTemperatureC(idx),log.motorTemperatureC(idx)); ...
    sprintf('Regen: %.3f kWh | friction brake: %.0f %%', ...
        log.cumulativeEnergyRecoveredWh(idx)/1000,100*log.frictionBrakeFraction(idx)); ...
    sprintf('Range estimate: %.0f km  |  %.0f Wh/km modeled', ...
        log.rangeEstimateKm(idx),log.rangeConsumptionWhPerKm(idx)); ...
    sprintf('Network frames: TX %d / RX %d / lost %d', ...
        log.networkTxFrames(idx),log.networkRxFrames(idx),log.networkLostFrames(idx))};
set(getappdata(fig,'summaryBox'),'String',summary);

metrics = getappdata(fig,'metricValues');
stateName = state_label(log.state(idx));
set(metrics(1),'String',stateName,'ForegroundColor',state_color(log.state(idx)));
set(metrics(2),'String',sprintf('%.1f %%',100*log.batterySoc(idx)));
set(metrics(3),'String',sprintf('%.1f km/h',log.vehicleSpeedKph(idx)));
set(metrics(4),'String',sprintf('%.1f V',log.dcBusVoltageV(idx)));
if log.faultActive(idx)
    set(metrics(5),'String',log.faultCode{idx},'ForegroundColor',[1.0 0.48 0.45]);
else
    set(metrics(5),'String','CLEAR','ForegroundColor',[0.40 0.91 0.78]);
end
setappdata(fig,'evState',gui);
render_module_detail(fig);
update_driver_cockpit(fig,idx);
drawnow limitrate;
end

function render_module_detail(fig)
if ~isgraphics(fig) || ~isappdata(fig,'evState') || ~isappdata(fig,'moduleList') || ...
        ~isappdata(fig,'detailBox')
    return;
end
gui = getappdata(fig,'evState');
if ~isstruct(gui) || ~isfield(gui,'log') || ~isfield(gui,'index') || ...
        ~isfield(gui,'modules')
    return;
end
list = getappdata(fig,'moduleList');
idx = min(gui.index,numel(gui.log.time));
log = gui.log;
moduleIndex = get(list,'Value');
name = gui.modules{moduleIndex};
summary = module_description(moduleIndex);
telemetry = {''; sprintf('Scenario: %s',log.scenarioDescription); ...
    sprintf('t = %.2f s',log.time(idx)); sprintf('VCU: %s',state_label(log.state(idx))); ...
    sprintf('DTC: %s',log.faultCode{idx}); ...
    sprintf('Cell range: %.3f..%.3f V (spread %.3f V)', ...
        log.cellVoltageMinV(idx),log.cellVoltageMaxV(idx),log.cellVoltageSpreadV(idx)); ...
    sprintf('Balancing cells: %d | isolation: %s',log.balanceCellCount(idx), ...
        isolation_label(log.isolationLatched(idx))); ...
    sprintf('Network: %s',online_label(log.networkOnline(idx))); ...
    sprintf('Contactor: %s',onoff_label(log.contactorClosed(idx)))};
box = getappdata(fig,'detailBox');
set(box,'String',[{name;'';summary;'';'CURRENT RUN'};telemetry]);
end

function open_driver_cockpit(mainFig)
if isappdata(mainFig,'driverCockpit')
    cockpit = getappdata(mainFig,'driverCockpit');
    if isfield(cockpit,'figure') && isgraphics(cockpit.figure)
        figure(cockpit.figure);
        return;
    end
end
cockpitFig = figure('Name','Driver View | EV Cockpit','NumberTitle','off', ...
    'Color',[0.055 0.075 0.11],'Position',[180 120 900 620], ...
    'MenuBar','none','ToolBar','none','Resize','on');
uicontrol(cockpitFig,'Style','text','String','DRIVER DISPLAY  /  SIMULATED VEHICLE', ...
    'Units','normalized','Position',[0.04 0.93 0.92 0.045], ...
    'BackgroundColor',[0.055 0.075 0.11],'ForegroundColor',[0.40 0.91 0.78], ...
    'FontSize',16,'FontWeight','bold','HorizontalAlignment','left');
cockpit.figure = cockpitFig;
cockpit.speed = cockpit_value(cockpitFig,'SPEED',[0.05 0.70 0.25 0.19],24);
cockpit.range = cockpit_value(cockpitFig,'ESTIMATED RANGE',[0.34 0.70 0.25 0.19],22);
cockpit.soc = cockpit_value(cockpitFig,'BATTERY SOC',[0.63 0.70 0.30 0.19],22);
cockpit.state = cockpit_value(cockpitFig,'VCU STATE',[0.05 0.48 0.25 0.16],20);
cockpit.mode = cockpit_value(cockpitFig,'DRIVE MODE',[0.34 0.48 0.25 0.16],20);
cockpit.gear = cockpit_value(cockpitFig,'DIRECTION',[0.63 0.48 0.13 0.16],20);
cockpit.power = cockpit_value(cockpitFig,'POWER / REGEN',[0.79 0.48 0.14 0.16],16);
cockpit.pedalAxes = gobjects(1,2);
cockpit.pedalAxes(1) = axes('Parent',cockpitFig,'Position',[0.12 0.28 0.76 0.055], ...
    'Color',[0.10 0.14 0.20],'XColor',[0.75 0.80 0.87],'YColor',[0.75 0.80 0.87]);
cockpit.pedalAxes(2) = axes('Parent',cockpitFig,'Position',[0.12 0.19 0.76 0.055], ...
    'Color',[0.10 0.14 0.20],'XColor',[0.75 0.80 0.87],'YColor',[0.75 0.80 0.87]);
cockpit.warning = uicontrol(cockpitFig,'Style','text','String','WARNINGS: NONE', ...
    'Units','normalized','Position',[0.05 0.08 0.90 0.075], ...
    'BackgroundColor',[0.10 0.14 0.20],'ForegroundColor',[0.40 0.91 0.78], ...
    'FontSize',11,'FontWeight','bold','HorizontalAlignment','left');
uicontrol(cockpitFig,'Style','text','String','Range is estimated from assumed/modelled energy use; not a certified vehicle prediction.', ...
    'Units','normalized','Position',[0.05 0.025 0.90 0.035], ...
    'BackgroundColor',[0.055 0.075 0.11],'ForegroundColor',[0.72 0.78 0.87], ...
    'FontSize',9,'HorizontalAlignment','left');
setappdata(mainFig,'driverCockpit',cockpit);
gui = getappdata(mainFig,'evState');
update_driver_cockpit(mainFig,min(gui.index,numel(gui.log.time)));
end

function handle = cockpit_value(parent,label,position,fontSize)
uipanel(parent,'Units','normalized','Position',position, ...
    'BackgroundColor',[0.10 0.14 0.20],'BorderType','line','HighlightColor',[0.20 0.28 0.38]);
uicontrol(parent,'Style','text','String',label,'Units','normalized', ...
    'Position',[position(1)+0.018 position(2)+position(4)-0.045 position(3)-0.036 0.027], ...
    'BackgroundColor',[0.10 0.14 0.20],'ForegroundColor',[0.60 0.69 0.80], ...
    'FontSize',9,'FontWeight','bold','HorizontalAlignment','left');
handle = uicontrol(parent,'Style','text','String','--','Units','normalized', ...
    'Position',[position(1)+0.018 position(2)+0.025 position(3)-0.036 position(4)-0.075], ...
    'BackgroundColor',[0.10 0.14 0.20],'ForegroundColor',[0.95 0.97 1], ...
    'FontSize',fontSize,'FontWeight','bold','HorizontalAlignment','left');
end

function update_driver_cockpit(mainFig,idx)
if ~isgraphics(mainFig) || ~isappdata(mainFig,'driverCockpit'), return; end
cockpit = getappdata(mainFig,'driverCockpit');
if ~isgraphics(cockpit.figure), return; end
gui = getappdata(mainFig,'evState');
log = gui.log;
idx = min(max(1,idx),numel(log.time));
set(cockpit.speed,'String',sprintf('%.0f km/h\nLIMIT %.0f', ...
    log.vehicleSpeedKph(idx),log.speedLimitKph(idx)));
set(cockpit.range,'String',sprintf('%.0f km',log.rangeEstimateKm(idx)));
set(cockpit.soc,'String',sprintf('%.1f %%',100*log.batterySoc(idx)));
set(cockpit.state,'String',state_label(log.state(idx)), ...
    'ForegroundColor',state_color(log.state(idx)));
set(cockpit.mode,'String',log.driveMode{idx});
set(cockpit.gear,'String',log.gearDirection{idx});
powerKw = log.motorPowerKw(idx);
if powerKw < -0.05
    powerText = sprintf('REGEN\n%.1f kW',abs(powerKw));
    powerColor = [0.35 0.88 0.61];
else
    powerText = sprintf('DRIVE\n%.1f kW',max(0,powerKw));
    powerColor = [0.95 0.97 1.0];
end
set(cockpit.power,'String',powerText,'ForegroundColor',powerColor);
barColors = {[0.20 0.72 1.0],[1.0 0.55 0.32]};
pedalValues = [log.accelerator(idx),log.brake(idx)];
pedalLabels = {'ACCELERATOR','BRAKE'};
for k = 1:2
    ax = cockpit.pedalAxes(k);
    cla(ax);
    barh(ax,1,pedalValues(k),'FaceColor',barColors{k},'EdgeColor','none');
    xlim(ax,[0 1]); ylim(ax,[0.5 1.5]); yticks(ax,1);
    yticklabels(ax,{pedalLabels{k}}); xticks(ax,[0 0.5 1]);
    xticklabels(ax,{'0%','50%','100%'}); grid(ax,'on');
end
warnings = {};
if log.faultActive(idx), warnings{end+1} = ['FAULT ' log.faultCode{idx}]; end %#ok<AGROW>
if log.batteryLowWarning(idx), warnings{end+1} = 'BATTERY LOW'; end %#ok<AGROW>
if log.batteryHotWarning(idx), warnings{end+1} = 'BATTERY OVER-TEMP'; end %#ok<AGROW>
if log.motorHotWarning(idx), warnings{end+1} = 'MOTOR OVER-TEMP'; end %#ok<AGROW>
if ~log.networkOnline(idx), warnings{end+1} = 'NETWORK LOST'; end %#ok<AGROW>
if ~log.interlockOk(idx), warnings{end+1} = 'INTERLOCK NOT READY'; end %#ok<AGROW>
if ~log.ekfHealthy(idx), warnings{end+1} = 'EKF HEALTH'; end %#ok<AGROW>
if strcmp(log.driveMode{idx},'CHARGE') && log.chargerCurrentA(idx) > 0
    warnings{end+1} = 'CHARGING'; %#ok<AGROW>
end
if isempty(warnings)
    warningText = 'WARNINGS: NONE';
    warningColor = [0.40 0.91 0.78];
else
    warningText = ['WARNINGS: ' strjoin(warnings,'  |  ')];
    warningColor = [1.0 0.48 0.45];
end
set(cockpit.warning,'String',warningText,'ForegroundColor',warningColor);
drawnow limitrate;
end

function show_eco_comparison()
normalLog = run_ev_scenario('eco_range','NORMAL');
ecoLog = run_ev_scenario('eco_range','ECO');
P = ev_demo_config();
comparison = figure('Name','Matched-cycle ECO comparison','NumberTitle','off', ...
    'Color','w','Position',[120 100 1050 620]);
labels = {'Normal','ECO'};
subplot(2,2,1);
bar([normalLog.rangeEstimateKm(end),ecoLog.rangeEstimateKm(end)],0.55);
set(gca,'XTickLabel',labels); ylabel('Projected range [km]'); grid on;
title('Range estimate at matched-cycle end');
subplot(2,2,2);
bar([normalLog.rangeConsumptionWhPerKm(end),ecoLog.rangeConsumptionWhPerKm(end)],0.55);
set(gca,'XTickLabel',labels); ylabel('Modeled energy use [Wh/km]'); grid on;
title('Energy per distance');
subplot(2,2,3);
plot(normalLog.time,normalLog.vehicleSpeedKph,'LineWidth',1.5); hold on;
plot(ecoLog.time,ecoLog.vehicleSpeedKph,'LineWidth',1.5); grid on;
ylabel('Speed [km/h]'); xlabel('Time [s]'); legend(labels,'Location','best');
title('Same driver cycle, different mode caps');
subplot(2,2,4);
plot(normalLog.time,normalLog.cumulativeNetEnergyWh,'LineWidth',1.5); hold on;
plot(ecoLog.time,ecoLog.cumulativeNetEnergyWh,'LineWidth',1.5); grid on;
ylabel('Net pack energy [Wh]'); xlabel('Time [s]'); legend(labels,'Location','best');
title('Net battery energy on the matched cycle');
ecoGainPct = 100*(ecoLog.rangeEstimateKm(end)/max(normalLog.rangeEstimateKm(end),eps)-1);
annotation(comparison,'textbox',[0.05 0.94 0.90 0.04], ...
    'String',sprintf('Illustrative model: ECO projected range change %+0.1f%% | SOC %.1f%% | distance %.2f km | assumed pack %.1f kWh', ...
    ecoGainPct,100*ecoLog.batterySoc(end),ecoLog.cumulativeDistanceKm(end), ...
    P.batteryCapacityAh*P.nominalVoltage/1000), ...
    'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
end

function show_ekf_evidence()
comparison = compare_foc_ekf_modes('thermal_drift');
fixedLog = comparison.fixed;
ekfLog = comparison.ekf;
proof = figure('Name','Matched vehicle cycle | fixed parameters vs EKF','NumberTitle','off', ...
    'Color','w','Position',[80 55 1300 800]);
subplot(2,3,1);
plot(fixedLog.time,fixedLog.vehicleSpeedKph,'--',ekfLog.time,ekfLog.vehicleSpeedKph,'LineWidth',1.2);
grid on; xlabel('Time [s]'); ylabel('Speed [km/h]'); legend('Fixed','EKF'); title('Same speed-control scenario');
subplot(2,3,2);
plot(fixedLog.time,fixedLog.torqueRequestNm,'k:',fixedLog.time,fixedLog.torqueActualNm,'--', ...
    ekfLog.time,ekfLog.torqueActualNm,'LineWidth',1.2);
grid on; xlabel('Time [s]'); ylabel('Torque [Nm]');
legend('Request','Fixed actual','EKF actual'); title('Torque tracking');
subplot(2,3,3);
plot(fixedLog.time,fixedLog.iqFeedbackA,'--',fixedLog.time,fixedLog.iqReferenceA,':', ...
    ekfLog.time,ekfLog.iqFeedbackA,'LineWidth',1.2);
grid on; xlabel('Time [s]'); ylabel('i_q [A]');
legend('Fixed i_q','Reference','EKF i_q'); title('Torque-producing current');
subplot(2,3,4);
plot(ekfLog.time,ekfLog.motorRsTrueOhm,'k--',fixedLog.time,fixedLog.motorRsControlOhm, ...
    ekfLog.time,ekfLog.motorRsControlOhm,'LineWidth',1.2);
grid on; xlabel('Time [s]'); ylabel('R_s [ohm]');
legend('Plant truth (sim only)','Fixed control value','EKF control estimate'); title('Thermal Rs adaptation');
subplot(2,3,5);
plot(ekfLog.time,ekfLog.fluxTrueWb,'k--',fixedLog.time,fixedLog.fluxControlWb, ...
    ekfLog.time,ekfLog.fluxControlWb,'LineWidth',1.2);
grid on; xlabel('Time [s]'); ylabel('Flux [Wb]');
legend('Plant truth (sim only)','Fixed control value','EKF control estimate'); title('Flux adaptation');
subplot(2,3,6);
fixedNormalized = [100,100,100,100];
ekfNormalized = [100-comparison.torqueErrorImprovementPct, ...
    100-comparison.currentErrorImprovementPct, ...
    100-comparison.speedErrorImprovementPct, ...
    100-comparison.parameterErrorImprovementPct];
bar([fixedNormalized;ekfNormalized]');
set(gca,'XTickLabel',{'Torque','Current','Speed','Parameter'});
ylabel('Error relative to fixed mode [%]');
legend('Fixed baseline','EKF adaptive','Location','best'); grid on;
title('Matched-run errors (lower is better; not pre-asserted)');
annotation(proof,'textbox',[0.04 0.94 0.92 0.04], ...
    'String',sprintf('Same inputs: %d | EKF updates: %d | parameter %+0.1f%% | torque %+0.1f%% | current %+0.1f%% | speed %+0.1f%% | model only', ...
    comparison.sameInputs,comparison.ekfMetrics.adaptiveUpdates, ...
    comparison.parameterErrorImprovementPct,comparison.torqueErrorImprovementPct, ...
    comparison.currentErrorImprovementPct,comparison.speedErrorImprovementPct), ...
    'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
end

function text = module_description(index)
descriptions = {
    'Driver demand flows through safety supervision into energy allocation, motor actuation, battery limits, and the road plant. Every subsystem shares a common scenario log.';
    'Ignition, precharge, ready-to-drive, normal drive, ECO drive, regenerative braking, charging, and latched fault states. Diagnostics and BMS interlocks inhibit torque.';
    'Substepped dq current PI controller, voltage-vector saturation, PMSM current equations, fixed or EKF parameter feed-forward. It remains a switching-inverter-free simulation.';
    'Generic per-series-cell voltage/SOC/temperature, imbalance detection, passive bleed balancing, pack limits, and latched isolation model. Chemistry and monitor hardware are not selected.';
    'Plug-in power/current/SOC-limit simulation. Charger communication protocol is intentionally unspecified; no standards-compliance claim.';
    'Applies drive-mode scaling, battery discharge limits, speed cap, regen acceptance, and friction-brake blending.';
    'Deterministic sensor perturbation plus an injected speed-sensor dropout. Sensor validity is passed into fault supervision.';
    'Combines sensor range, battery, pedal plausibility, overcurrent, emergency-stop, and network-timeout fault flags into a DTC and VCU shutdown.';
    'Simulated periodic telemetry, approximate bus load, receive/loss counts, and timeout fault. No production CAN arbitration or timing claim.';
    'Longitudinal force balance includes motor wheel force, rolling resistance, aerodynamic drag, grade, and friction braking.';
    'Repeatable startup, acceleration, grade, braking, restart, thermal drift, sensor fault, emergency, charging, and network-loss runs; column-oriented log vectors.'};
text = descriptions{index};
end

function make_button(parent,label,pos,callback,color)
uicontrol(parent,'Style','pushbutton','String',label,'Units','normalized', ...
    'Position',pos,'Callback',callback,'BackgroundColor',color, ...
    'ForegroundColor',[0.97 0.98 1],'FontSize',9,'FontWeight','bold');
end

function label = state_label(state)
S = ev_state_definitions();
if state >= 1 && state <= numel(S.names), label = S.names{state}; else, label = 'UNKNOWN'; end
end

function color = state_color(state)
colors = [0.75 0.80 0.88; 0.95 0.73 0.31; 0.38 0.88 0.62; ...
    0.32 0.76 1.0; 0.77 0.65 1.0; 0.38 0.88 0.62; ...
    1.0 0.43 0.42; 0.40 0.91 0.78];
color = colors(min(max(1,state),8),:);
end

function label = online_label(value)
if value, label = 'ONLINE'; else, label = 'TIMEOUT'; end
end

function label = onoff_label(value)
if value, label = 'CLOSED'; else, label = 'OPEN'; end
end

function label = isolation_label(value)
if value, label = 'LATCHED'; else, label = 'CLEAR'; end
end
