// ============================================================
// CrashTech VLSI-2026 — Challenge 5: FPGA Volt-Meter (ESP32 side)
// ============================================================
// The FPGA (MAX 10) reads an analog voltage via its internal ADC,
// then sends the result as an ASCII string over UART.
// This firmware receives that string and displays it on the OLED.
//
// UART from FPGA:
//   Format  : "X.XX\n"  (newline-terminated ASCII)
//   Example : "1.65\n" = 1.65 V
//   Baud    : 115200, 8N1
//   ESP32 RX: GPIO17  (pin_config PIN_FPGA_RX)
//   ESP32 TX: GPIO16  (not used in this direction — FPGA does not receive)
//
// OLED: SSD1306 128×64, I2C on SDA=GPIO21, SCL=GPIO22 (Adafruit_SSD1306)
//
// Display layout:
//   Row 0 (y=0):  label "FPGA ADC" in size-1 text
//   Row 1 (y=18): voltage e.g. "1.65V" in size-3 text (centred)
//   Row 2 (y=50): proportional bar graph (0 V – 2.5 V)
// ============================================================

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "../../../../projects/common/esp32/pin_config.h"

// ---- UART from FPGA ----
// The FPGA sends at 115200; override pin_config's default FPGA_BAUD (9600).
static const int    FPGA_UART_BAUD  = 115200;
static const int    UART_TIMEOUT_MS = 120;   // > one full 115200-baud packet

// ---- OLED ----
Adafruit_SSD1306 oled(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);
static bool oledOk = false;

// ---- UART2 instance (FPGA → ESP32 direction) ----
HardwareSerial FpgaSerial(2);   // UART2: RX=GPIO17, TX=GPIO16

// ============================================================
// Draw voltage string (e.g. "1.65") on the OLED.
// voltage_str must be null-terminated, max 4 chars + null.
// voltage_f is the parsed float used for the bar graph.
// ============================================================
static void updateOled(const char* voltage_str, float voltage_f) {
    if (!oledOk) return;

    oled.clearDisplay();

    // ---- Label ----
    oled.setTextSize(1);
    oled.setTextColor(SSD1306_WHITE);
    oled.setCursor(2, 0);
    oled.print("FPGA ADC  (0-2.5V)");

    // ---- Large voltage value (text size 3 = 18 px tall) ----
    // Build display string with 'V' unit appended
    char buf[8];
    snprintf(buf, sizeof(buf), "%sV", voltage_str);

    oled.setTextSize(3);
    // Each character is 6*3=18 px wide
    int charW  = 6 * 3;
    int len    = (int)strlen(buf);
    int startX = (OLED_WIDTH - len * charW) / 2;
    if (startX < 0) startX = 0;
    oled.setCursor(startX, 16);
    oled.print(buf);

    // ---- Bar graph (bottom 10 px, range 0–2.5 V) ----
    // Clamp float to [0.0, 2.5]
    if (voltage_f < 0.0f)  voltage_f = 0.0f;
    if (voltage_f > 2.5f)  voltage_f = 2.5f;
    int barWidth = (int)(voltage_f / 2.5f * (OLED_WIDTH - 4) + 0.5f);
    oled.drawRect(2, 52, OLED_WIDTH - 4, 10, SSD1306_WHITE);
    if (barWidth > 0)
        oled.fillRect(2, 52, barWidth, 10, SSD1306_WHITE);

    oled.display();
}

// ============================================================
// Parse "X.XX" or "X.X" format; returns voltage in volts,
// or -1.0f if the string is not a valid decimal number.
// ============================================================
static float parseVoltage(const String& s) {
    // Must contain exactly one '.', digits only otherwise
    int dotIdx = -1;
    for (int i = 0; i < (int)s.length(); i++) {
        if (s[i] == '.') {
            if (dotIdx >= 0) return -1.0f;   // two dots — invalid
            dotIdx = i;
        } else if (s[i] < '0' || s[i] > '9') {
            return -1.0f;                    // non-digit — invalid
        }
    }
    if (dotIdx < 0) return -1.0f;           // no dot — invalid
    return s.toFloat();
}

// ============================================================
// setup
// ============================================================
void setup() {
    // Debug serial (USB)
    Serial.begin(115200);

    // FPGA UART (RX only in this direction)
    FpgaSerial.begin(FPGA_UART_BAUD, SERIAL_8N1, PIN_FPGA_RX, PIN_FPGA_TX);
    FpgaSerial.setTimeout(UART_TIMEOUT_MS);

    // OLED init
    Wire.begin(PIN_OLED_SDA, PIN_OLED_SCL);
    oledOk = oled.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR);
    if (!oledOk) {
        Serial.println("[WARN] OLED not found — check wiring");
    } else {
        oled.clearDisplay();
        oled.setTextSize(1);
        oled.setTextColor(SSD1306_WHITE);
        oled.setCursor(0, 24);
        oled.print("  Waiting for FPGA...");
        oled.display();
    }

    Serial.println("[INFO] Challenge 5 ESP32 ready");
}

// ============================================================
// loop — non-blocking UART receive + OLED update
// ============================================================
void loop() {
    // readStringUntil blocks for up to UART_TIMEOUT_MS if no '\n' arrives.
    // At 115200 baud, a 5-byte "X.XX\n" takes < 0.5 ms — well within timeout.
    if (FpgaSerial.available()) {
        String line = FpgaSerial.readStringUntil('\n');
        line.trim();    // strip any trailing '\r' or whitespace

        if (line.length() == 0) return;    // empty line — skip

        float v = parseVoltage(line);
        if (v < 0.0f) {
            // Malformed packet — log and skip
            Serial.print("[WARN] bad packet: '");
            Serial.print(line);
            Serial.println("'");
            return;
        }

        // Valid reading — update display
        updateOled(line.c_str(), v);

        Serial.print("[ADC] ");
        Serial.print(line);
        Serial.println(" V");
    }
}
