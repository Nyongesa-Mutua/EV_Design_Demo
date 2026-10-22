# Phase 1–6 project integration and interfaces

The original roadmap labels phases as project activities. The MATLAB application instead organizes runtime areas by function. Each area below has one owner module and exchanges explicit structs/signals with its neighbors.

## Functional mapping

| Roadmap work | Functional area in this project | Main artifact / evidence |
|---|---|---|
| Requirements and assumptions | Configuration and architecture | `config/ev_demo_config.m`, `architecture/system_architecture.md`; model constants are marked illustrative. |
| Architecture and interfaces | System architecture | `architecture/system_architecture.md`; this interface document describes run-time contracts. |
| FOC/EKF algorithm proof | PMSM / motor control | Integrated runner uses `modules/motor_control/pmsm_foc_ekf_step.m` with fixed or EKF-adaptive Rs/flux feed-forward and a matched-cycle A/B harness. The separate `phase3/phase3_foc_ekf.m` remains accessible as a reference study. |
| VCU and driver controls | Vehicle control & safety | `modules/vehicle_control/vcu_step.m`, shared state IDs in `config/ev_state_definitions.m`. |
| Plant, sensors, scenarios | Vehicle & road plant, sensors, scenario runner | `modules/vehicle_plant/vehicle_step.m`, `modules/sensors/sensor_step.m`, `simulation/run_ev_scenario.m`. |
| Log/replay HMI | Scenario runner & logger, dashboard | `simulation/run_ev_scenario.m`, `dashboard/ev_system_dashboard.m`; MAT output under `results/`. |
| Robustness/regression | Scenario regression | `tests/run_regression_suite.m`; run each named scenario and its core pass/fail assertions. |

## Interfaces

| Producer | Consumer | Contract |
|---|---|---|
| `scenario_driver_input` | VCU, charger, energy manager, sensors, diagnostics, plant | `driver` has bounded accelerator/brake in [0,1], ignition/drive/plug/reset/fault booleans, `ecoMode`, drive mode, speed limit, grade, and injection flags. |
| BMS state | VCU, energy manager, charger, diagnostics | `bms.soc` [0,1], voltage [V], current [A] (positive discharge), temperature [°C], current limits [A], contactor permission. |
| Sensors + network | Diagnostics | Sensor valid/range values and network timeout state produce bit-mask diagnostics, active flag, primary diagnostic code. |
| Diagnostics + driver + BMS | VCU | Active diagnostics inhibit torque and latch FAULT; reset is accepted after active diagnostics clear. |
| VCU + driver + BMS | Energy management | VCU state gates drive/regen demand; energy manager bounds torque and computes friction-brake share. |
| Speed controller + energy manager | Motor control | Speed PI output torque request [Nm], bounded with anti-windup; energy manager applies mode, battery, speed, and regen limits. |
| PMSM FOC/EKF | Vehicle plant | Substepped dq PI and PMSM current equations use rotor speed, DC voltage, torque demand and motor estimates; outputs dq currents, shaft torque and DC current. This remains an averaged software plant, not a PWM switching simulation. |
| BMS cell model | VCU, energy manager, charger, diagnostics | Generic cell SOC/voltage/temp arrays, spread, balancing requests and isolation latch drive current limits and fault handling. Chemistry/monitor IC remain unselected. |
| Motor + charger | BMS | Motor discharge current is positive; charger current is subtracted to represent current into the pack as negative. |
| All subsystems | HMI/logger | Equal-length column vectors. Time [s], speed [km/h], torque [Nm], current [A], voltage [V], SOC [0–1], temperature [°C], grade as ratio, state as shared integer ID. |

## State map

`ev_state_definitions` is authoritative: 1 OFF, 2 PRECHARGE, 3 READY, 4 DRIVE, 5 REGEN, 6 CHARGING, 7 FAULT, 8 ECO. ECO is a torque-limited VCU driving state selected by the scenario input and uses a lower illustrative speed cap. The dashboard labels and tests read the same IDs.

## Safety/evidence boundaries

The simulation protects against modeled faults, but it is not an automotive safety controller. Cell behavior uses a generic configurable curve, charger protocol is unspecified, CAN is only a traffic/timeout abstraction, controller/observer timing is MATLAB model timing, and the plant has no PWM switching or hardware scheduling. Treat it only as a software integration/demo model until separately calibrated and validated.
