// ============================================================
// CrashTech VLSI-2026 — Challenge 1: Volt-Meter (ESP32 side)
// ============================================================
// Reads potentiometer on GPIO34, converts to 0.00–3.30 V,
// displays on OLED in large text, and transmits to FPGA over UART.
//
// UART protocol (to FPGA):
//   3 ASCII decimal digits + newline, e.g. "165\n" = 1.65 V
//   Range 000–330 (millivolts / 10, i.e. value × 0.01 = volts)
//   Baud: 9600 8N1
//   FPGA RX pin: ARDUINO_IO[0] = PIN_AB5
//   ESP32 TX pin: GPIO16 (PIN_FPGA_TX)
//
// OLED: 128×64 SSD1306 on I2C (SDA=21, SCL=22)
// ============================================================

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "../../../../projects/common/esp32/pin_config.h"

// ---- ADC averaging ----
static const int   ADC_SAMPLES     = 64;    // samples per reading
static const float ADC_MAX         = 4095.0f;
static const float VREF            = 3.3f;

// ---- UART ----
HardwareSerial FpgaSerial(2);  // UART2: TX=GPIO16, RX=GPIO17

// ---- OLED ----
Adafruit_SSD1306 oled(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);
static bool oledOk = false;

// ---- Timing ----
static const unsigned long DISPLAY_INTERVAL_MS = 100;  // 10 Hz refresh
static const unsigned long UART_INTERVAL_MS    = 100;  // 10 Hz TX
static unsigned long lastDisplay = 0;
static unsigned long lastUart    = 0;

// ---- State ----
static int   lastSentValue = -1;   // avoid redundant UART sends

// ============================================================
// Read averaged ADC, return voltage * 100 as integer (0–330)
// e.g. 1.65 V → 165
// ============================================================
static int readVoltageScaled() {
    long sum = 0;
    for (int i = 0; i < ADC_SAMPLES; i++) {
        sum += analogRead(PIN_ANALOG_IN);
    }
    float avg     = (float)sum / ADC_SAMPLES;
    float voltage = avg * VREF / ADC_MAX;
    // Clamp to [0.00, 3.30]
    if (voltage < 0.0f)  voltage = 0.0f;
    if (voltage > 3.30f) voltage = 3.30f;
    return (int)(voltage * 100.0f + 0.5f);  // round to nearest
}

// ============================================================
// Draw voltage on OLED
// ============================================================
static void updateOled(int scaled) {
    if (!oledOk) return;

    int voltsInt  = scaled / 100;        // integer part  (0–3)
    int voltsFrac = scaled % 100;        // fractional    (0–99)

    char buf[8];
    snprintf(buf, sizeof(buf), "%d.%02dV", voltsInt, voltsFrac);

    oled.clearDisplay();

    // ---- Large voltage value (text size 3) ----
    oled.setTextSize(3);
    oled.setTextColor(SSD1306_WHITE);
    // Centre horizontally: each char is 6*3=18 px wide + 1 px gap = 19 px
    int charW  = 6 * 3;
    int len    = strlen(buf);
    int startX = (OLED_WIDTH - len * charW) / 2;
    if (startX < 0) startX = 0;
    oled.setCursor(startX, 10);
    oled.print(buf);

    // ---- Bar graph (bottom 12 px of screen) ----
    // Fill a rectangle proportional to voltage
    int barWidth = (int)((float)scaled / 330.0f * (OLED_WIDTH - 4) + 0.5f);
    oled.drawRect(2, 48, OLED_WIDTH - 4, 12, SSD1306_WHITE);
    if (barWidth > 0) {
        oled.fillRect(2, 48, barWidth, 12, SSD1306_WHITE);
    }

    // ---- Label ----
    oled.setTextSize(1);
    oled.setCursor(2, 36);
    oled.print("Potentiometer ADC");

    oled.display();
}

// ============================================================
// Send "NNN\n" over UART to FPGA  (e.g. "165\n")
// ============================================================
static void sendToFpga(int scaled) {
    char packet[6];
    snprintf(packet, sizeof(packet), "%03d\n", scaled);
    FpgaSerial.print(packet);
}

// ============================================================
void setup() {
    Serial.begin(115200);
    Serial.println("Volt-Meter Challenge 1 — starting");

    // ADC: GPIO34 is input-only, no pull configuration needed
    analogReadResolution(12);
    analogSetAttenuation(ADC_11db);  // full 0–3.3 V range

    // UART to FPGA
    FpgaSerial.begin(FPGA_BAUD, SERIAL_8N1, PIN_FPGA_RX, PIN_FPGA_TX);

    // OLED
    Wire.begin(PIN_OLED_SDA, PIN_OLED_SCL);
    if (oled.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
        oledOk = true;
        oled.clearDisplay();
        oled.setTextSize(1);
        oled.setTextColor(SSD1306_WHITE);
        oled.setCursor(0, 0);
        oled.print("Volt-Meter Ready");
        oled.display();
        delay(800);
    } else {
        Serial.println("OLED init failed");
    }
}

// ============================================================
void loop() {
    unsigned long now = millis();

    // Sample ADC
    int scaled = readVoltageScaled();

    // Update OLED at ~10 Hz
    if (now - lastDisplay >= DISPLAY_INTERVAL_MS) {
        lastDisplay = now;
        updateOled(scaled);
    }

    // Send to FPGA at ~10 Hz (only when value changed to reduce noise)
    if (now - lastUart >= UART_INTERVAL_MS) {
        lastUart = now;
        if (scaled != lastSentValue) {
            sendToFpga(scaled);
            lastSentValue = scaled;
            Serial.printf("TX → FPGA: %03d  (%.2fV)\n",
                          scaled, scaled / 100.0f);
        }
    }
}
