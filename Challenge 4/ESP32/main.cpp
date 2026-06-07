// =============================================================
// main.cpp  –  Challenge 6: Frequency Detector (ESP32 side)
//
// What this does:
//   1. Reads potentiometer on GPIO34 (ADC1_CH6, 0–4095)
//   2. Maps ADC value to a frequency in the range 100–2000 Hz
//   3. Generates 256 signed 8-bit sine wave samples at 8000 Hz
//      sample rate  →  samples[i] = round(sin(2π·f·i/8000) × 127)
//   4. Sends all 256 raw bytes over UART2 TX (GPIO16) at 115200 baud
//      to the FPGA UART RX (ARDUINO_IO[0] / PIN_AB5)
//   5. Waits 50 ms (creates the inter-frame silence gap the FPGA uses
//      for frame synchronisation)
//   6. Displays the current frequency on the OLED in large text
//
// Hardware wiring:
//   ESP32 GPIO16 (UART2 TX) → DE10-Lite ARDUINO_IO[0] (PIN_AB5)
//   OLED SSD1306 128×64: SDA=GPIO21, SCL=GPIO22
//   Potentiometer wiper   → GPIO34
// =============================================================

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <math.h>

// ---- Pin / UART configuration ----
#define POT_PIN        34       // ADC input (potentiometer wiper)
#define FPGA_TX_PIN    16       // ESP32 UART2 TX → FPGA RX
#define FPGA_RX_PIN    17       // ESP32 UART2 RX (unused but required by begin())
#define FPGA_BAUD      115200

// ---- Sine wave parameters ----
#define SAMPLE_RATE    8000     // Hz
#define FRAME_SIZE     256      // samples per frame
#define FRAME_GAP_MS   50       // silence gap between frames (ms)

// ---- Frequency mapping ----
#define FREQ_MIN       100      // Hz
#define FREQ_MAX       2000     // Hz

// ---- OLED configuration ----
#define OLED_WIDTH     128
#define OLED_HEIGHT    64
#define OLED_ADDR      0x3C

// =============================================================
// Globals
// =============================================================
HardwareSerial FpgaSerial(2);  // UART2
Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);

static int8_t  samples[FRAME_SIZE];
static uint32_t last_oled_update = 0;
static int      last_freq_shown  = -1;

// =============================================================
// setup()
// =============================================================
void setup() {
    // Debug serial (USB)
    Serial.begin(115200);

    // UART2 to FPGA
    FpgaSerial.begin(FPGA_BAUD, SERIAL_8N1, FPGA_RX_PIN, FPGA_TX_PIN);

    // OLED
    Wire.begin(21, 22);
    if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
        // If OLED not found, continue anyway – FPGA still works
        Serial.println("SSD1306 not found");
    }
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("Freq Detector");
    display.println("Challenge 6");
    display.display();
    delay(500);

    // Use ADC 12-bit (default on ESP32)
    analogReadResolution(12);
    analogSetAttenuation(ADC_11db);  // full 0–3.3 V range on GPIO34
}

// =============================================================
// updateOLED()  –  only redraws when frequency actually changes
// =============================================================
static void updateOLED(int freq_hz) {
    if (freq_hz == last_freq_shown) return;
    last_freq_shown = freq_hz;

    display.clearDisplay();

    // Title
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("Frequency:");

    // Large frequency value
    display.setTextSize(3);
    display.setCursor(0, 18);
    display.print(freq_hz);
    display.print(" Hz");

    // Small bar at the bottom proportional to frequency
    int bar_w = (int)((long)(freq_hz - FREQ_MIN) * (OLED_WIDTH - 2) /
                      (FREQ_MAX - FREQ_MIN));
    if (bar_w < 0) bar_w = 0;
    if (bar_w > OLED_WIDTH - 2) bar_w = OLED_WIDTH - 2;
    display.drawRect(0, OLED_HEIGHT - 8, OLED_WIDTH, 8, SSD1306_WHITE);
    display.fillRect(1, OLED_HEIGHT - 7, bar_w, 6, SSD1306_WHITE);

    display.display();
}

// =============================================================
// loop()
// =============================================================
void loop() {
    // 1. Read potentiometer (0–4095)
    int adc = analogRead(POT_PIN);

    // 2. Map ADC value → frequency  (linear: 0→100 Hz, 4095→2000 Hz)
    int freq_hz = FREQ_MIN + (int)((long)adc * (FREQ_MAX - FREQ_MIN) / 4095);
    // Clamp to valid range
    if (freq_hz < FREQ_MIN) freq_hz = FREQ_MIN;
    if (freq_hz > FREQ_MAX) freq_hz = FREQ_MAX;

    // 3. Generate 256 signed 8-bit sine wave samples
    //    sample[i] = sin(2π · freq_hz · i / SAMPLE_RATE) × 127
    float phase_inc = 2.0f * (float)M_PI * (float)freq_hz / (float)SAMPLE_RATE;
    for (int i = 0; i < FRAME_SIZE; i++) {
        float val = sinf(phase_inc * (float)i) * 127.0f;
        // Round and clamp to [-127, 127] to avoid 0x80 (-128 ambiguity)
        int iv = (int)(val >= 0.0f ? val + 0.5f : val - 0.5f);
        if (iv >  127) iv =  127;
        if (iv < -127) iv = -127;
        samples[i] = (int8_t)iv;
    }

    // 4. Send all 256 bytes to FPGA over UART2
    FpgaSerial.write((const uint8_t*)samples, FRAME_SIZE);
    FpgaSerial.flush();   // wait until all bytes are in the shift register

    // 5. Update OLED (non-blocking; only redraws on change)
    updateOLED(freq_hz);

    // Optional debug output to USB serial
    Serial.print("freq=");
    Serial.print(freq_hz);
    Serial.print(" Hz  adc=");
    Serial.println(adc);

    // 6. Inter-frame gap: let the FPGA detect end-of-frame
    delay(FRAME_GAP_MS);
}
