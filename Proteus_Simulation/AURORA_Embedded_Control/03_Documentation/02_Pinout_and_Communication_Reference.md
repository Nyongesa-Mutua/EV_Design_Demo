# AURORA Pinout and Communication Reference

This document records the important STM32 pins and communication links used by the final Proteus embedded prototype.

---

# 1. BMS STM32F401RE

| Pin | Peripheral / Signal | Function |
|---|---|---|
| PA0 | ADC1_IN0 | Battery-temperature potentiometer input |
| PA2 | USART2_TX | BMS state transmission to VCU |
| PA9 | USART1_TX | BMS Virtual Terminal output |
| PB0 | GPIO Output | Green BMS status LED |
| PB1 | GPIO Output | Red BMS status LED |

### BMS machine communication

```text
BMS PA2 → VCU PA3
```

Baud rate:

```text
9600 baud
8 data bits
No parity
1 stop bit
```

The BMS transmits:

| Byte | Meaning |
|---|---|
| `N` | NORMAL |
| `W` | WARNING |
| `D` | DERATE |
| `S` | SHUTDOWN |

The BMS human-readable screen uses:

```text
115200 baud
```

---

# 2. Vehicle Control Unit STM32F401RE

| Pin | Peripheral / Signal | Function |
|---|---|---|
| PA0 | ADC input | Accelerator input |
| PA1 | ADC input | Brake input |
| PA7 | ADC input | SOC input |
| PA4 | GPIO input | Ignition / start switch |
| PA5 | GPIO input | Charge switch |
| PA3 | USART2_RX | Receives BMS state |
| PA9 | USART1_TX | VCU command to Motor Controller |
| PA10 | USART1_RX | Motor health feedback to VCU |
| PC6 | USART6_TX | VCU Virtual Terminal output |

### BMS to VCU

```text
BMS PA2 TX → VCU PA3 RX
```

### VCU to Motor Controller

```text
VCU PA9 TX → Motor Controller PA3 RX
```

### Motor Controller to VCU

```text
Motor Controller PA2 TX → VCU PA10 RX
```

Machine links:

```text
9600 baud
8 data bits
No parity
1 stop bit
```

VCU debug screen:

```text
115200 baud
```

---

# 3. Motor Controller STM32F401RE

| Pin | Peripheral / Signal | Function |
|---|---|---|
| PA2 | USART2_TX | Motor health feedback to VCU |
| PA3 | USART2_RX | VCU motor-command input |
| PA4 | GPIO input | Motor-fault input |
| PA6 | TIM3_CH1 | Hardware PWM output |
| PA9 | USART1_TX | Motor Controller Virtual Terminal |

Motor debug screen:

```text
115200 baud
```

Machine link:

```text
9600 baud
```

---

# 4. VCU → Motor Controller Protocol

The final motor command uses two bytes.

```text
Byte 1 = Mode
Byte 2 = Value
```

Valid modes:

| Mode | Meaning |
|---|---|
| `D` | DRIVE |
| `R` | REGEN |
| `S` | STOP |

Examples:

```text
D + 50 → DRIVE at 50%
R + 30 → REGEN request at 30%
S + 0  → STOP
```

---

# 5. Motor Controller → VCU Protocol

Motor health is returned as one byte.

| Byte | Meaning |
|---|---|
| `O` | Motor Controller healthy |
| `F` | Motor Controller hardware fault |

---

# 6. Human-Readable Virtual Terminals

The machine UART links and debug screens are intentionally separate.

### Machine communication

```text
9600 baud
```

### Human-readable debug screens

```text
115200 baud
```

This prevents raw machine protocol characters from being mixed with the status information shown during the demonstration.

---

# 7. Grounding

The current Proteus prototype uses a common ground reference.

All STM32 logic sections and the motor-driver stage must reference the same:

```text
GND / 0 V
```

Proteus ground symbols connected to the same global GND net represent the same electrical node, even if a physical wire is not drawn between every section.

---

# 8. Power / Support Components

Each STM32 section includes the required support connections used in the schematic, including:

- 3.3 V logic supply
- VREF / VDDA support
- NRST pull-up
- VCAP decoupling capacitor
- Common ground

The exact schematic should always be treated as the authoritative wiring reference.
