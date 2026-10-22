# STM32 / CubeIDE adapter and validation plan

## Known target information

The project target is STM32 with STM32CubeIDE. The exact MCU part/board, clock tree, ADC/PWM timer mapping, current-sense topology, CAN peripheral/transceiver, charger, battery cell chemistry/monitor IC, and test equipment have not yet been selected. Accordingly, this document is an adapter contract and evidence plan—not a claim of built or hardware-validated firmware.

## Portable algorithm / hardware boundary

Keep these operations portable and independently unit-testable:

- speed PI controller, torque/current/speed limits, and ECO mode;
- FOC transforms, current PI/anti-windup, voltage vector limiting;
- EKF prediction/correction, adaptation gating, parameter bounds;
- VCU state machine and fault-latch policy;
- BMS pack/cell decision logic and charger/network state machines.

The STM32-specific adapter must later supply: timer/ADC synchronized current acquisition, rotor electrical angle/speed, DC bus and temperature samples, PWM compare values with dead time, hardware break/fault input, contactor/precharge outputs, watchdog service, and CAN/UART transport. Do not connect the illustrative MATLAB adapter directly to power hardware.

## Required target decisions before CubeIDE peripheral code

1. Exact STM32 part number, board/revision, clock source, and Cube firmware package version.
2. Inverter topology, gate-driver protections, current-sensor type/location, rotor-position source, PWM frequency, dead time, and ADC sampling point.
3. Pack chemistry, series/parallel configuration, cell-monitor IC, isolation/contactor design, fuse and precharge circuit, and safe voltage/current/temperature limits.
4. Charger make/model, connector, and applicable charging communication standard.
5. CAN/CAN-FD choice, transceiver, bitrate/data phase, identifiers, network schedule, bus-off recovery, and diagnostic protocol.
6. Debug probe and available oscilloscope/current probes, isolated differential probes, HIL/Proteus version or safe low-voltage test plant.

## Validation stages and evidence

| Stage | Procedure | Evidence to retain | Status |
|---|---|---|---|
| MATLAB simulation | Run regression and fixed-vs-EKF A/B scenarios; verify same inputs, bounded currents/torque, state transitions, and finite/symmetric/bounded EKF estimates. | MAT logs, regression transcript, parameter file, comparison plots/metrics. | Implemented as checks; execution still requires MATLAB. |
| Desktop C tests | Port portable algorithms after MATLAB interface is frozen; compare outputs against saved traces with tolerances. | Compiler/version/flags, test report, map/size output. | Not implemented/verified. |
| CubeIDE build | Compile for the confirmed part with warnings enabled; record linker map, stack usage, and float library. | ELF/map, compiler flags/version, static analysis report. | Deferred: exact part is unknown. |
| Peripheral bench | First test ADC/PWM with safe isolated low-voltage sources and dummy load; verify break input and safe gate-disable behavior before motor connection. | Oscilloscope captures, ADC calibration, PWM/dead-time measurements, fault reaction trace. | Deferred: bench/inverter details unknown. |
| Timing/resource | Use cycle counter/DWT or timer instrumentation around ISR/control tasks; repeat under worst-case interrupt/network load. Measure flash/RAM/map and stack high-water mark. | Per-task worst-case cycles/jitter, stack watermark, map/size reports. | No MCU measurements exist. MATLAB host timings are not MCU timings. |
| HIL/Proteus | Confirm exact model support and compare signals against software reference; never infer unsupported power-stage behavior from visual simulation alone. | Circuit/project version, stimulus, probes/screenshots, expected/actual table. | Deferred: model/equipment unknown. |
| Vehicle validation | Risk review and staged low-energy test plan, calibrated sensors, independent shutdown and current limits, qualified supervision. | Approved procedure, calibrated instrument records, raw logs, incident/abort criteria. | Not performed. |

## Safety evidence prerequisites

Before powered hardware tests, obtain a reviewed hazard analysis, independent hardware overcurrent/overvoltage/desaturation protections, isolation and precharge verification, emergency-stop design, safe discharge process, and a controlled test area. Software torque-off is not a substitute for gate-driver/hardware protection. No production safety or standards-compliance claim is made by this repository.
