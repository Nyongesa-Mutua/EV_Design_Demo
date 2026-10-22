# Integrated EV Systems Demo

This is the unified MATLAB software-in-the-loop workspace for the project's vehicle behavior and subsystem demonstrations. Functional folders are named for the system responsibility—not roadmap phase numbers. Existing experimental phase scripts in the parent workspace are left unchanged and can still be run independently.

## Launch

1. Open MATLAB and set the current folder to `ev_system_demo`.
2. Run `run_ev_system_demo` to open the dashboard.
3. Choose a scenario and select **Run Scenario** to calculate and display the complete run. Select **Play Replay** to animate it from the beginning. Use **System Areas** to inspect responsibilities and live signals.
4. **Save Log** stores the currently selected run as a MAT file under `results/`.
5. **Run Motor Studies** opens the existing detailed baseline FOC study followed by its separate FOC/EKF reference plots.
6. For an open-ended driver-command run, select **Start Live**. The live simulation advances until **Stop Live** is pressed; **Accelerate** raises the accelerator command and **Decelerate** releases it and applies braking. **Reset** returns the live simulation to its initial state.

For the browser bridge, first run `matlab.engine.shareEngine('EVSystem')` in the open MATLAB session, then start `server.py` with Python 3.12. The bridge connects only to that named session and reports a clear error instead of hanging when MATLAB is not shared. For headless checks, add `ev_system_demo` and its subfolders to the MATLAB path, then run `run_regression_suite`. The direct `run_ev_scenario(...)` and `ev_live_simulation(...)` entry points also add the project tree automatically, so the integrated EKF controller is linked even when they are called without first launching the dashboard. For host-only runtime/log-size data, run `run_model_benchmark`; it is not MCU performance evidence.

## Project areas

- `architecture/` — system interaction diagram, interfaces, and evidence limits.
- `config/` — centralized illustrative vehicle, motor, pack, charger, and sensor assumptions.
- `modules/vehicle_control/` — supervisory VCU and safety states.
- `modules/motor_control/` — substepped dq-current PI/PMSM simulation with selectable fixed or EKF parameter adaptation; no switching inverter.
- `modules/bms/` — generic per-cell SOC/voltage/temperature, imbalance, passive balancing, contactor, and isolation simulation.
- `modules/charging/` — plug-in charger limits and charge-state behavior.
- `modules/energy_management/` — torque allocation, mode scaling, speed limiting, regen, and friction-brake blending.
- `modules/sensors/`, `modules/diagnostics/`, `modules/communications/` — sensing, fault supervision, DTCs, and network-health model.
- `modules/vehicle_plant/` — longitudinal road-load model.
- `scenarios/` — common scenario catalog; signal profiles are in `simulation/`.
- `simulation/` — scenario orchestration and stable shared signal schema.
- `dashboard/` — MATLAB HMI and replay.
- `tests/` — headless scenario regression checks.
- `results/` — generated MAT logs.

## Demonstration scenarios

Startup/drive-off; acceleration with closed-loop speed tracking and a visible 45 km/h demonstration cap; grade/load cruise; service braking with regen and friction contribution; shutdown/restart; motor thermal resistance drift; speed-sensor dropout; emergency stop and reset; plug-in charging; communication-network loss; a matched Normal/ECO drive; and cell-overvoltage isolation.

The **Driver Cockpit** opens a synchronized driver-facing view with speed and active limit, mode/state, estimated range/SOC, power versus regen, pedal bars, direction, and warning summary. **Compare Normal / ECO** runs the same drive cycle twice. In this model, aerodynamic power grows approximately with speed cubed, so lower cruising speed can reduce aerodynamic energy per distance (approximately with speed squared); ECO also limits torque demand. Range gains depend on the cycle and are not guaranteed in real driving. The current estimate excludes accessory power, weather, traffic, aging, and detailed motor/battery efficiency maps.

The live dashboard uses the same subsystem functions as the finite scenarios. Its plots are updated from the live state rather than mock data: acceleration increases torque/current and reduces SOC over time, braking produces regenerative and friction-braking signals, and ECO uses lower torque and consumption assumptions so its modeled range estimate is higher for a matched operating cycle. A rolling live-log window is used to keep perpetual operation bounded in memory.

**FOC / EKF A-B** runs the same integrated thermal-drift drive scenario in fixed-parameter and adaptive-EKF modes. It plots speed, torque, `i_q`, and plant truth versus the controller's fixed or adaptive resistance/flux values, then reports torque-tracking and parameter-estimation errors. The UI does not force the EKF result to be better. **Run Motor Studies** retains access to the original baseline and standalone 10 kHz/1 kHz reference studies.

The integrated current loop is substepped at an illustrative 2 kHz and the observer corrects at 1 kHz while the vehicle/log step is 20 Hz. This is MATLAB simulation timing, not STM32 execution-time evidence. The BMS now has a generic 96-series/2-parallel illustrative cell model and an overvoltage/isolation scenario; chemistry, cell-monitor IC, per-cell calibration, contactor hardware, and validated behavior remain unselected. Charger protocol and CAN identifiers/bitrate are marked unspecified/placeholders; their simulation is not standards-compliant charging or a production CAN stack. See `architecture/stm32_cubeide_validation.md` and `architecture/network_and_charger_contract.md` for required decisions and evidence.

## Shared log

`run_ev_scenario(key)` returns a structure whose time-series fields are equal-length column vectors, including VCU/fault, accelerator/brake, speed/torque/current, motor parameter truth/estimate, pack SOC/voltage/current/temperature, charging power, regen/friction braking, grade, sensor validity, network counters, and contactor state. Simulation-only truth signals are not available from a real vehicle.

## Calibration and evidence boundaries

`ev_demo_config()` supplies explicitly illustrative defaults. Prepare measured overrides using [ev_calibration_template.m](config/ev_calibration_template.m), pass the resulting struct to `ev_demo_config(calibration)`, and record instruments, test conditions, uncertainty and provenance separately. Sensor offsets, noise, and quantization can also be overridden.

FOC/EKF, closed-loop speed control, per-cell sensing/balancing/isolation, and charger/network behavior are software models. Cell chemistry/monitor IC, charger standard, CAN IDs/transceiver, and exact STM32 part remain unselected. The host benchmark does not measure STM32 resources or timing. See [stm32_cubeide_validation.md](architecture/stm32_cubeide_validation.md) and [network_and_charger_contract.md](architecture/network_and_charger_contract.md). No HIL, Proteus, physical-vehicle, standards-compliance, or target resource/timing evidence is claimed.

## Assumptions and cautions

The numerical values are examples for software integration, not a calibrated vehicle. The BMS, charging, communication, sensors, motor and road plant are low-order demonstrations. Do not connect this model directly to power hardware or use it as a safety controller. Hardware and standards validation remain separate work.
