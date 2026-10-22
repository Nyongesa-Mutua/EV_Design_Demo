# AURORA Proteus Run and Test Guide

This guide explains how to run and verify the AURORA embedded-control prototype in Proteus.

---

# 1. Before Starting

Confirm that the Proteus project contains the three STM32 controllers:

- BMS
- VCU
- Motor Controller

Each STM32 must load the latest compiled `.elf` file from its corresponding STM32CubeIDE project.

---

# 2. Firmware Projects

The expected firmware folders are:

```text
02_STM32_Firmware/
├── AURORA_BMS/
├── AURORA_CLEAN_VCU/
└── AURORA_MOTOR_CONTROLLER/
```

Build each project using STM32CubeIDE before running Proteus if firmware changes have been made.

---

# 3. UART Settings

## Debug Virtual Terminals

All human-readable screens use:

```text
115200 baud
8 data bits
No parity
1 stop bit
```

These include:

- BMS SCREEN
- VCU SCREEN
- MTR_CTRL

## Machine Links

Controller-to-controller communication uses:

```text
9600 baud
8 data bits
No parity
1 stop bit
```

---

# 4. Expected Boot Messages

After starting the simulation, the three screens should show:

### BMS

```text
AURORA BMS READY
```

### VCU

```text
AURORA VCU READY
```

### Motor Controller

```text
AURORA MOTOR CTRL READY
```

---

# 5. Normal-Drive Test

Set:

```text
BMS temperature = NORMAL region
Ignition         = ON
Charge           = OFF
Brake            = 0%
Accelerator      ≈ 50%
Motor Fault      = OFF
```

Expected BMS:

```text
STATE: NORMAL
TORQUE LIMIT: 100%
```

Expected VCU:

```text
MODE: DRIVE
ACC: 50%
BRK: 0%
LIMIT: 100%
MTR CMD: 50%
MOTOR: OK
DTC: 0
```

Expected Motor Controller:

```text
MODE: DRIVE
RX MODE: D
RX VALUE: 50
CMD: 50%
PWM: 50%
FAULT: NONE
DTC: 0
```

---

# 6. BMS Temperature Tests

## NORMAL

Temperature:

```text
< 30 °C
```

Expected:

```text
BMS STATE: NORMAL
Torque Limit: 100%
```

## WARNING

Temperature:

```text
30 °C to < 40 °C
```

Expected:

```text
BMS STATE: WARNING
Torque Limit: 80%
```

## DERATE

Temperature:

```text
40 °C to < 80 °C
```

Expected:

```text
BMS STATE: DERATE
Torque Limit: 50%
```

The VCU should reduce the available motor command.

For example:

```text
ACC = 50%
Limit = 50%

Final Motor Command ≈ 25%
```

## SHUTDOWN

Temperature:

```text
≥ 80 °C
```

Expected:

```text
BMS STATE: SHUTDOWN
Torque Limit: 0%
```

The VCU should enter FAULT and command the motor to stop.

---

# 7. Brake / Regeneration Test

Apply the brake input.

Expected VCU behaviour:

```text
MODE: REGEN
```

The VCU calculates a regenerative-braking request.

In the current Proteus motor stage, regeneration is represented logically.

The single-MOSFET motor circuit does **not** physically return energy to the supply, so propulsion PWM is removed during this state.

---

# 8. Charge Test

Activate the VCU charge switch.

Expected:

```text
VCU MODE: CHARGE
```

Propulsion should be disabled while charging.

The current SOC behaviour is a simplified demonstration model.

---

# 9. Motor Fault Test

Activate the Motor Controller fault switch.

Expected Motor Controller:

```text
FAULT: ACTIVE
```

Motor health sent to VCU:

```text
F
```

Expected VCU:

```text
MOTOR: FAULT
DTC: 1
MTR CMD: 0%
```

---

# 10. DTC Meaning

DTC means:

```text
Diagnostic Trouble Code
```

In the current motor-fault demonstration:

```text
DTC 0 = No motor hardware fault
DTC 1 = Motor Controller hardware fault
```

---

# 11. Proteus Simulation Speed

The simulation may run significantly slower than real time.

Proteus is simultaneously simulating:

- Three STM32F401 microcontrollers
- UART communication
- ADC inputs
- GPIO
- Hardware PWM
- MOSFET switching
- Motor load
- Multiple Virtual Terminals

Therefore:

```text
30 seconds of real time
```

may correspond to only a few seconds of Proteus simulation time.

This affects how quickly the simulation progresses but does not change the intended control relationships.

### Optimizations already used

- Hardware PWM instead of software PWM
- Compact machine UART protocols
- Separate machine and debug UARTs
- Reduced status-screen update frequency
- Removal of temporary debug terminals after testing

---

# 12. SPICE Timestep Error

If Proteus reports:

```text
TRAN: Timestep too small
```

the problem is normally in the electrical/motor power stage rather than the STM32 application logic.

Check:

- Flyback diode
- Motor/MOSFET wiring
- Common ground
- Non-ideal series resistance
- Supply connections
- Floating nodes

---

# 13. Known Prototype Limitations

The current Proteus model intentionally simplifies several real-EV systems.

It does not currently include:

- Dedicated battery-current measurement
- Cell balancing
- Full battery-pack voltage monitoring
- Physical regenerative energy return
- Three-phase traction inverter
- Production automotive CAN network

The MATLAB/Simulink portion of the wider project provides the higher-fidelity motor/control investigation.
