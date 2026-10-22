# AURORA Embedded Control Overview

## 1. Purpose

This document describes the embedded-control portion of the AURORA Software-Defined Vehicle (SDV) prototype implemented in Proteus using three STM32F401RE microcontrollers.

The embedded prototype demonstrates the control chain from:

**Battery protection → Vehicle-level decision making → Motor command → PWM actuation → Fault feedback**

The three main controllers are:

- Battery Management System (BMS)
- Vehicle Control Unit (VCU)
- Motor Controller

---

## 2. Embedded Architecture

![BMS](../04_Images/BMS.png)

![VCU](../04_Images/VCU.png)

![Motor Controller](../04_Images/Motor_Controller.png)

The functional architecture is:

**BMS → VCU → Motor Controller → PWM / Motor Stage**

The Motor Controller also sends health and fault feedback back to the VCU.

---

## 3. Battery Management System (BMS)

The BMS STM32 is responsible for the battery-protection demonstration.

In the current Proteus model, the BMS handles:

- Battery-temperature input
- BMS operating-state determination
- Torque-limit generation
- Green and red status LEDs
- Communication of BMS state to the VCU
- Human-readable status output through the BMS Virtual Terminal

The current BMS prototype does **not** contain:

- A dedicated current sensor
- Cell-by-cell voltage measurement
- Cell balancing
- SOC calculation

SOC is represented separately as an input to the VCU in the current Proteus prototype.

### BMS states

| Temperature | BMS State | Torque Limit |
|---|---|---:|
| Below 30 °C | NORMAL | 100% |
| 30 °C to below 40 °C | WARNING | 80% |
| 40 °C to below 80 °C | DERATE | 50% |
| 80 °C and above | SHUTDOWN | 0% |

These temperature thresholds are demonstration values chosen so that the different states can be reached easily during a Proteus demonstration. They are not intended to represent validated production EV battery limits.

---

## 4. Vehicle Control Unit (VCU)

The VCU is the main supervisory controller.

It receives and processes:

- Accelerator input
- Brake input
- SOC input
- Ignition/start switch
- Charge switch
- BMS state
- Motor Controller health feedback

The VCU determines the current vehicle state:

- `OFF`
- `READY`
- `DRIVE`
- `REGEN`
- `CHARGE`
- `FAULT`

It then calculates the final motor command and sends it to the Motor Controller.

### Torque arbitration

The VCU uses the active protection limits when calculating the motor request.

The simplified relationship is:

```text
Final Motor Command =
Accelerator Request × Effective Torque Limit / 100
```

Example:

```text
Accelerator = 50%
BMS Limit   = 100%

Final Motor Command = 50%
```

If the BMS enters DERATE:

```text
Accelerator = 50%
BMS Limit   = 50%

Final Motor Command = 25%
```

Safety-related conditions take priority over normal drive requests.

---

## 5. Motor Controller

The Motor Controller receives the motor request from the VCU.

The final simplified communication protocol is:

```text
Byte 1 = Operating Mode
Byte 2 = Command Value
```

Modes:

- `D` = DRIVE
- `R` = REGEN
- `S` = STOP

Example:

```text
D + 50
```

means:

```text
DRIVE at 50% command
```

During DRIVE, the Motor Controller converts the received value into a hardware-PWM duty cycle using TIM3 Channel 1.

The PWM output is generated on:

```text
PA6 → TIM3_CH1
```

The Motor Controller also monitors the motor-fault input and reports health back to the VCU.

Health messages:

- `O` = Motor Controller OK
- `F` = Motor Controller fault

---

## 6. Normal-Drive Example

A verified normal operating condition is:

### BMS

```text
STATE: NORMAL
TORQUE LIMIT: 100%
```

### VCU

```text
MODE: DRIVE
ACC: 50%
BRK: 0%
LIMIT: 100%
MTR CMD: 50%
MOTOR: OK
DTC: 0
```

### Motor Controller

```text
MODE: DRIVE
RX MODE: D
RX VALUE: 50
CMD: 50%
PWM: 50%
FAULT: NONE
DTC: 0
```

This verifies the complete control path:

```text
Driver request
      ↓
VCU decision
      ↓
Motor command
      ↓
Motor Controller
      ↓
Hardware PWM
```

---

## 7. Prototype Scope

The Proteus motor power stage is deliberately simplified.

The current implementation demonstrates:

- ECU separation
- ECU-to-ECU communication
- Battery-protection influence on torque
- Driver-input processing
- Vehicle-state management
- Motor-command generation
- Hardware PWM
- Fault propagation
- Diagnostic outputs

The detailed PMSM, Field-Oriented Control (FOC), and Extended Kalman Filter (EKF) work belongs to the MATLAB/Simulink portion of the overall project.

The Proteus motor stage should therefore be treated as an embedded-integration proof of concept rather than a complete EV traction inverter.

---

## 8. Software Used

| Software | Purpose |
|---|---|
| Proteus | Embedded and electrical co-simulation |
| STM32CubeMX | STM32 peripheral configuration |
| STM32CubeIDE | Firmware development and ELF generation |
| MATLAB / Simulink | Higher-fidelity motor and control modelling |
| Python | Backend integration and vehicle-state handling |
| VS Code | Python/backend and dashboard development |
