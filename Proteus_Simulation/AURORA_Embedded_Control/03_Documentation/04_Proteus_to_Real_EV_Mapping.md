# AURORA Proteus-to-Real-EV Mapping

This document explains what the components in the AURORA Proteus prototype represent in an actual electric vehicle.

---

# 1. Overall Architecture

The Proteus prototype is a simplified representation of the same high-level control structure used in an electric vehicle:

```text
Battery / BMS
      ↓
Vehicle Control Unit
      ↓
Motor Controller
      ↓
Traction Power Stage
      ↓
Motor / Drivetrain
```

The goal is not to reproduce every physical EV component in Proteus.

The goal is to demonstrate:

- Control responsibility
- Signal flow
- Safety response
- Torque limiting
- ECU communication
- Actuation
- Fault propagation

---

# 2. Battery Management System

![AURORA BMS](../04_Images/BMS.png)

| Proteus Element | Function in Prototype | Real EV Equivalent |
|---|---|---|
| Battery-temperature potentiometer | Generates battery-temperature input | Pack/module thermistor or battery temperature sensor |
| BMS STM32F401RE | Determines battery state and torque limit | Battery Management System ECU |
| Green / Red LEDs | Visual status indication | Diagnostic/status indication |
| BMS → VCU UART | Sends battery state | Vehicle communication network, commonly CAN |
| BMS Virtual Terminal | Displays BMS data | Service tool / diagnostic interface |

### Current prototype scope

The BMS currently focuses on:

- Temperature protection
- BMS state
- Torque limiting
- Status indication

The BMS does **not** currently include a dedicated current sensor.

SOC is not calculated inside the current Proteus BMS; it is represented as an input to the VCU.

---

# 3. Vehicle Control Unit

![AURORA VCU](../04_Images/VCU.png)

| Proteus Element | Function in Prototype | Real EV Equivalent |
|---|---|---|
| ACC input | Driver acceleration request | Accelerator Pedal Position Sensor |
| BRK input | Braking request | Brake pedal position / brake request sensor |
| SOC input | Battery state-of-charge information | SOC normally estimated by BMS and transmitted to VCU |
| Ignition/start switch | Enables vehicle operation | Ignition / vehicle enable request |
| Charge switch | Indicates charging state | Charge-port / EVSE / charging interlock signal |
| VCU STM32F401RE | Supervisory decision making | Vehicle Control Unit |
| BMS link | Receives battery protection status | CAN or other vehicle-network message |
| Motor link | Sends motor command and receives health | Torque-command / inverter communication |
| VCU Virtual Terminal | Displays vehicle state | Dashboard / service diagnostic tool |

The VCU is responsible for determining whether the vehicle should be:

- OFF
- READY
- DRIVE
- REGEN
- CHARGE
- FAULT

---

# 4. Motor Controller

![AURORA Motor Controller](../04_Images/Motor_Controller.png)

| Proteus Element | Function in Prototype | Real EV Equivalent |
|---|---|---|
| Motor Controller STM32F401RE | Receives vehicle torque command | Inverter / Motor Control Unit controller |
| TIM3 hardware PWM | Generates duty-cycle command | Inverter gate-control command |
| MOSFET | Simplified motor power switching | Traction inverter switching device |
| DC motor model | Simplified traction load | PMSM / BLDC traction motor |
| Flyback diode | Protects switching stage from inductive voltage | Power-stage protection / freewheel path |
| Motor fault switch | Injects motor-side hardware fault | Inverter/motor diagnostic fault |
| Motor → VCU UART | Sends health status | CAN/inverter status message |
| Motor Virtual Terminal | Displays motor state | Engineering/service diagnostic interface |

The current motor stage is deliberately simplified.

A real EV normally uses a three-phase traction inverter controlling a PMSM or BLDC motor.

---

# 5. Communication

The prototype uses UART because it is simple and reliable for the Proteus proof of concept.

### Prototype

```text
BMS ↔ VCU ↔ Motor Controller
        UART
```

### Typical production EV

```text
BMS ↔ VCU ↔ Inverter
        CAN / automotive network
```

The control responsibilities remain similar even though the communication technology changes.

---

# 6. Regenerative Braking

The VCU includes a regenerative-braking state.

In the current Proteus prototype:

- Brake input creates a REGEN request
- VCU calculates regen percentage
- Motor Controller receives the REGEN command
- Propulsion PWM is removed

However, the current single-MOSFET/DC-motor stage is not bidirectional.

Therefore the prototype demonstrates the **control logic** of regenerative braking but does not physically recover energy into the battery.

---

# 7. MATLAB vs Proteus

The project deliberately uses different tools for different levels of fidelity.

## MATLAB / Simulink

Used for:

- PMSM modelling
- Field-Oriented Control
- Extended Kalman Filter work
- Higher-fidelity control development
- Mathematical validation

## Proteus / STM32

Used for:

- Embedded firmware execution
- ECU communication
- State-machine verification
- Fault response
- Driver-input processing
- Torque limiting
- PWM output
- Electrical co-simulation

The simplified Proteus motor stage should therefore not be interpreted as the complete traction-control model.

---

# 8. What the Prototype Demonstrates

The strongest feature of the Proteus prototype is the complete cause-and-effect chain:

```text
Battery temperature changes
        ↓
BMS state changes
        ↓
VCU torque limit changes
        ↓
Final motor command changes
        ↓
Motor Controller PWM changes
```

Fault feedback also travels in the opposite direction:

```text
Motor hardware fault
        ↓
Motor Controller
        ↓
VCU
        ↓
FAULT state
        ↓
Motor command = 0
```

This demonstrates the fundamental architecture of a distributed EV control system even though the physical plant is simplified.
