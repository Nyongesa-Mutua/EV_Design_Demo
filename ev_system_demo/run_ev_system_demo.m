function run_ev_system_demo()
% RUN_EV_SYSTEM_DEMO Launch the integrated EV software dashboard.
% Add the project folders to the MATLAB path, then open the HMI.
projectRoot = fileparts(mfilename('fullpath'));
workspaceRoot = fileparts(projectRoot);
addpath(genpath(workspaceRoot));
ev_system_dashboard();
end
