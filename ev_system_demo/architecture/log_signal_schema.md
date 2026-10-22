# Shared scenario log signal schema

Every time-series member returned by `run_ev_scenario` is a column vector with the same number of samples. The structure also carries scalar `scenarioDescription`, `sampleTimeS`, and `assumptions` metadata. This is the common handoff between model modules, regression checks, dashboard replay, and saved MAT output.

| Field(s) | Unit / type | Meaning |
|---|---|---|
| `time`, `sampleTimeS` | s | Sample time vector and fixed simulation step. |
| `scenarioKey`, `scenarioDescription` | text | Scenario ID repeated per row and human-readable run description. |
| `state` | integer | Shared VCU state: OFF=1, PRECHARGE=2, READY=3, DRIVE=4, REGEN=5, CHARGING=6, FAULT=7, ECO=8. |
| `faultMask`, `faultActive`, `faultCode` | bit mask, logical, text | Active DTC flags, overall indication, and primary reason. Bit weights: sensor=1, BMS=2, network timeout=4, pedal=8, emergency=16, overcurrent=32, cell isolation=64, bus load=128, EKF numerical health=256. |
| `accelerator`, `brake` | fraction [0,1] | Bounded driver demand. |
| `speedRequestKph`, `speedLimitKph`, `vehicleSpeedKph`, `speedSensorKph` | km/h | Pedal-scaled reference for dashboard illustration, active mode speed cap, simulated plant speed, and noisy/dropout sensor output. The current scenario plant does not implement a closed-loop speed controller. |
| `motorSpeedRpm` | rpm | Simulated motor shaft speed. |
| `torqueRequestNm`, `torqueActualNm` | Nm | Energy-manager request (negative for regen) and reduced-order motor torque. |
| `idA`, `iqA`, `idFeedbackA`, `iqFeedbackA`, `idReferenceA`, `iqReferenceA` | A | Simulated dq plant currents, sensor-model feedback (offset/noise/quantized), and references from the substepped current-control loop. Not a switching inverter or physical measurement. |
| `motorRsTrueOhm`, `motorRsEstimateOhm`, `motorRsControlOhm` | ohm | Simulated plant resistance, observer estimate, and parameter actually used by the selected fixed/EKF controller. `motorControlMode` identifies the run mode. |
| `fluxTrueWb`, `fluxEstimateWb`, `fluxControlWb` | Wb | Simulated plant flux, observer estimate, and controller-used flux. Truth is simulation-only. |
| `speedControllerErrorKph`, `speedControllerTorqueNm` | km/h, Nm | Closed-loop speed PI error and unscaled torque demand before energy-manager mode/battery limits. |
| `ekfMode`, `ekfAdaptationEnabled`, `ekfUpdateCount` | logical, logical, count | Selected adaptive mode, current observability gate, and cumulative enabled observer corrections. |
| `ekfHealthy` | logical | Finite/bounds/symmetry health monitor status; an unhealthy observer raises a modeled diagnostic and requires a clear-condition reset. |
| `dcBusVoltageV` | V | Battery terminal voltage approximation. |
| `batteryCurrentA` | A | Positive indicates pack discharge; negative indicates charging/regen into pack. |
| `batterySoc` | fraction [0,1] | Coulomb-counted pack state-of-charge approximation. |
| `batteryTemperatureC`, `motorTemperatureC` | °C | Lumped simulated pack and motor temperatures. |
| `chargerPowerKw`, `chargerCurrentA` | kW, A | Simulated charger output; charger current is positive into the pack. |
| `energyRecoveredWh`, `cumulativeEnergyRecoveredWh` | Wh | Per-sample and accumulated regenerative electrical energy credited by the model. |
| `rangeEstimateKm`, `rangeConsumptionWhPerKm` | km, Wh/km | Estimated remaining range from pack energy divided by modeled consumption. Uses an assumed cycle-consumption fallback before enough distance is accumulated; excludes accessory loads, weather, traffic, battery aging, and detailed efficiency maps. |
| `cellVoltageMinV`, `cellVoltageMaxV`, `cellVoltageSpreadV`, `cellTemperatureMaxC`, `cellTemperatureSensorMaxC`, `balanceCellCount`, `isolationLatched` | V, V, V, °C, °C, count, logical | Synthetic series-cell monitor readings, passive-balancing count and latched isolation request. Cell curve, limits and noise are generic placeholders, not pack data. |
| `networkBusLoadFraction`, `chargerStatus`, `chargerProtocol` | fraction, text, text | Approximate model bus occupancy and simulated charger state/protocol label; neither establishes protocol conformance. |
| `speedLimitKph`, `ecoActive`, `gearDirection` | km/h, logical, text | Active mode cap, VCU ECO-state flag, and simplified P/N/D cockpit indicator. |
| `motorPowerKw`, `cumulativeNetEnergyWh` | kW, Wh | Signed motor mechanical power and net pack-energy change (positive is energy consumed). |
| `batteryLowWarning`, `batteryHotWarning`, `motorHotWarning`, `interlockOk` | logical | Simplified cockpit warning and interlock indications. |
| `frictionBrakeFraction`, `gradeFraction` | fraction | Friction-brake demand and road grade as ratio (0.08 = 8%). |
| `driveMode` | text | NORMAL/ECO/SPORT/CHARGE scenario mode. |
| `sensorValid`, `networkOnline`, `contactorClosed` | logical | Sensor, communication, and BMS permissive status. |
| `networkTxFrames`, `networkRxFrames`, `networkLostFrames` | count | Simulated communication counters; no physical CAN timing is modeled. |

No simulation-only `true` signal should be expected from a real vehicle. The log deliberately distinguishes simplified system integration from hardware acquisition and verified control outputs.
