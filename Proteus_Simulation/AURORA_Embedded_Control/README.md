\# AURORA Embedded Control System



\## Overview

AURORA is an embedded electric vehicle control prototype developed in Proteus and STM32 firmware.  

The system is divided into three main control units:



\- \*\*BMS (Battery Management System)\*\*  

\- \*\*VCU (Vehicle Control Unit)\*\*  

\- \*\*Motor Controller\*\*



These three embedded subsystems communicate together to simulate a simplified EV control architecture.



\---



\## System Architecture



<table>

&#x20; <tr>

&#x20;   <td align="center"><b>BMS</b></td>

&#x20;   <td align="center"><b>VCU</b></td>

&#x20;   <td align="center"><b>Motor Controller</b></td>

&#x20; </tr>

&#x20; <tr>

&#x20;   <td><img src="04\_Images/BMS.png" width="300"></td>

&#x20;   <td><img src="04\_Images/VCU.png" width="300"></td>

&#x20;   <td><img src="04\_Images/Motor\_Controller.png" width="300"></td>

&#x20; </tr>

</table>



\---



\## What Each MCU Does



\### 1. Battery Management System (BMS)

The BMS monitors battery-related conditions and sends battery status information to the VCU.  

In the current prototype, the BMS mainly handles:



\- Battery temperature indication

\- BMS state reporting

\- Torque limit reporting

\- Indicator LED outputs

\- Communication to the VCU



\### 2. Vehicle Control Unit (VCU)

The VCU is the central decision-making unit of the prototype.  

It receives driver and system inputs, reads state-of-charge information, interprets BMS status, and sends motor commands to the motor controller.



The VCU handles:



\- Start/ignition input

\- Charge input

\- Accelerator input

\- Brake input

\- State of charge (SOC)

\- Driving mode decision

\- Torque command generation

\- Regenerative braking command

\- Communication with both BMS and Motor Controller



\### 3. Motor Controller

The Motor Controller receives commands from the VCU and translates them into motor action outputs.



It handles:



\- Drive/stop mode response

\- PWM generation

\- Motor command execution

\- Fault state display

\- Communication feedback to the VCU



\---



\## Repository Structure



\- `01\_Proteus/` → Proteus schematic/project files

\- `02\_STM32\_Firmware/` → STM32CubeIDE firmware for all MCUs

\- `03\_Documentation/` → project documentation in Markdown

\- `04\_Images/` → system images and flowchart images



\---



\## Flow Diagrams



\### Overall System Flow

!\[Overall System Flow](04\_Images/Flow\_Overall\_System.png)



\### BMS Flow

!\[BMS Flow](04\_Images/Flow\_BMS.png)



\### VCU Flow

!\[VCU Flow](04\_Images/Flow\_VCU.png)



\### Motor Controller Flow

!\[Motor Controller Flow](04\_Images/Flow\_Motor\_Controller.png)



\---



\## How the Prototype Maps to a Real EV



AURORA is a simplified EV embedded control prototype. The mapping is:



\- \*\*BMS\*\* → Real battery management and battery protection logic

\- \*\*VCU\*\* → Real vehicle supervisory controller

\- \*\*Motor Controller\*\* → Real traction inverter / motor drive controller

\- \*\*Potentiometers / switches in Proteus\*\* → Driver pedals, ignition, and charging inputs

\- \*\*Virtual terminals\*\* → Debug dashboards / serial monitoring

\- \*\*LEDs and indicators\*\* → Simplified status outputs



For more detail, see:

\[Proteus to Real EV Mapping](03\_Documentation/04\_Proteus\_to\_Real\_EV\_Mapping.md)



\---



\## How to Run



1\. Open the Proteus project from `01\_Proteus/`

2\. Open the STM32 firmware projects from `02\_STM32\_Firmware/`

3\. Build the firmware and ensure the correct `.elf` files are linked in Proteus

4\. Run the Proteus simulation

5\. Observe the BMS, VCU, and Motor Controller virtual terminals



\---




