# Charger and communication contracts (unselected hardware)

## Charging

The model can represent plug detect, permission, current/power limit, SOC cutoff, and stop/fault state. `chargerProtocol = 'UNSPECIFIED_DEMO'` is intentionally not a standard. A real standards-compliant charger interface cannot be selected until the charger, connector, vehicle class, and applicable standard are known. Implement future protocol negotiation and safety interlocks in a separate adapter; keep pack current/voltage/temperature limits authoritative in the BMS.

## Communications

The MATLAB network module simulates periodic telemetry, dropped-message counts, timeout detection, and an approximate classic-CAN bus-load figure. The present 500 kbit/s and approximate frame occupancy are illustrative placeholders. This is not CAN/CAN-FD conformance, arbitration, timing, EMC, diagnostic-protocol, or production network validation.

Before production CAN code, freeze a signal database: identifier, source/destination, data layout, scale/offset, units, update period, timeout action, counter/CRC policy, and safe defaults. Confirm arbitration priorities and measured bus utilization against the chosen network and transceiver.

## Hardware-adapter message proposal (not assigned IDs)

| Logical message | Suggested contents | Required receiver behavior |
|---|---|---|
| VCU status | state, drive mode, direction, ready/fault summary | Timeout inhibits torque request and signals communication DTC. |
| Driver request | bounded accelerator/brake, target speed, mode | Range/plausibility checks; reject stale/invalid requests. |
| BMS limits | SOC, pack voltage/current/temp, allowed charge/discharge current, contactor permit | Invalid/stale limits cause a safe torque inhibit and charge stop. |
| Inverter feedback | measured phase/dq currents, rotor speed/angle, temperatures, gate-driver fault | Hardware fault input has priority over bus status. |
| Charger status | connector state, protocol state, requested/actual current/voltage, fault | Charger must not enable from an unspecified or invalid negotiation. |

Do not assign real identifiers or claim standards compliance until the project network database and target are approved.
