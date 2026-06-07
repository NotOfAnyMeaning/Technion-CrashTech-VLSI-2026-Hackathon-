# Technion-CrashTech-VLSI-2026-Hackathon-
A selected collection of challenges and their solutions from the 2026 Hackathon at the Technion utilizing FPGA, ESP32 and AI tools for rapid development. 

This repository contains my partenr's and mine solutions for a selected collection of the CrashTech VLSI-2026 Hackathon challenges. The projects focus on hardware-software integration, communication methods, and embedded systems design.

## 🚀 Project Overview

The core objective of these challenges was to build responsive, integrated systems under strict time constraints. To achieve this, the development workflow heavily utilized AI-assisted coding (e.g., GitHub Copilot) for rapid prototyping, allowing the primary focus to remain on system architecture, hardware integration, and peripheral communication.

### 🛠️ Hardware Stack
* **Microcontroller:** ESP32
* **Programmable Logic:** FPGA, DE10-Lite FPGA
* **Peripherals:** OLED Display, Potentiometer, Buzzer, Buttons. 

### 💻 Software & Languages
* C++ 
* Verilog
* AI Development Tools

## 📂 Repository Structure

| Challenge | Description | Key Components Used | Link For Video |
| :--- | :--- | :--- | :--- |
| `challenge-01/` | Volt-Meter- a digital volt-meter that reads the potentiometer voltage and displays it on both the OLED screen and the FPGA 7-segment displays | ESP32, FPGA, OLED, Potentiometer | https://youtube.com/shorts/7uv6hr2h9Yo?feature=share |
| `challenge-02/` | Accelerometer 3D Cube- Reads the onboard ADXL345 accelerometer on the FPGA, sends the raw acceleration data over UART to the ESP32, and draws a wireframe 3D cube on the OLED that rotates in real-time as you tilt the board. | FPGA, ESP32, OLED | https://youtube.com/shorts/vhNnYFWAIdo?feature=share |
| `challenge-03/` | FPGA Volt-Meter- Reads an analog voltage using the FPGA's internal ADC (MAX 10 ADC), displays it on the 7-segment displays, and sends the value to the ESP32 to show on the OLED screen. This is the reverse direction of Challenge 1: the FPGA does the analog reading, not the ESP32. | ESP32, FPGA, OLED, Potentiometer | https://youtube.com/shorts/mVZMf6iuaYw?feature=share |
| `challenge-04/` | Frequency Detector- The ESP32 reads a potentiometer and generates a digital sine wave at the corresponding frequency (100-2000 Hz). It sends 256 raw signed samples over UART to the FPGA. The FPGA detects the frequency of the signal and displays it on the 7-segment displays. | ESP32, FPGA, OLED, Potentiometer | https://youtube.com/shorts/4hM4eMXpIl4?feature=share |

## ⚙️ System Architecture & Integration
The FPGA and the ESP32 communicated using UART (with the following config: 9600 baud, 8N1, 3.3V logic) for most of the challenges. One of the challenges that's not included here utilized SPI communication and another used higher baud. Wiring for the UART:
| ESP32 Pin | Direction | FPGA Pin | Function |
|-----------|-----------|----------|----------|
| GPIO 16 | → | ARDUINO_IO[0] | ESP32 TX → FPGA RX |
| GPIO 17 | ← | ARDUINO_IO[1] | FPGA TX → ESP32 RX |
| GND | — | GND (Arduino header) | Common ground |
