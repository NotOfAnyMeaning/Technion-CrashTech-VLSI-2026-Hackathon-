// =============================================================
// main.cpp  –  3D Cube Accelerometer Renderer
//
// Checkpoint 3: UART parser (115200 8N1, 8-byte framed packets)
// Checkpoint 4: Pitch/Roll calculation + 3D rotation math
// Checkpoint 5: OLED wireframe cube rendering
//
// Hardware:
//   ESP32 DevKit (30/38-pin)
//   UART2: RX=GPIO17, TX=GPIO16 (receive from FPGA)
//   OLED SSD1306 128x64 on I2C: SDA=GPIO21, SCL=GPIO22
// =============================================================

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <math.h>

// ---- Pin / UART config ----
#define FPGA_RX_PIN   17      // ESP32 receives on GPIO17 (FPGA TX → ESP32 RX)
#define FPGA_TX_PIN   16      // unused in this direction but defined for completeness
#define FPGA_BAUD     115200

// ---- OLED config ----
#define OLED_WIDTH    128
#define OLED_HEIGHT   64
#define OLED_I2C_ADDR 0x3C

// ---- Packet definition ----
#define PKT_SYNC   0xAA
#define PKT_LEN    8          // sync + 6 data bytes + checksum

// ---- Cube geometry ----
// 8 vertices of a unit cube centred at origin, side length 1.0
#define CUBE_HALF  20.0f   // half-size of cube on screen in pixels
#define CAM_DIST    4.0f   // virtual camera distance in cube-units
                           // cube z ranges -1..1, so dz = 3..5, scl = 0.8..1.33

// ---- ADXL345 sensitivity at ±2g: 256 LSB/g ----
#define LSB_PER_G  256.0f

// ---- Smoothing: exponential moving average (0 < ALPHA <= 1) ----
// Lower = smoother but more lag; 0.55 balances responsiveness and smoothness.
#define EMA_ALPHA  0.55f

// =============================================================
// Global state
// =============================================================
HardwareSerial FpgaSerial(2);  // UART2
Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);

float pitch = 0.0f;
float roll  = 0.0f;

// =============================================================
// Checkpoint 3: UART parser state machine
// =============================================================
static uint8_t  rx_buf[PKT_LEN];
static uint8_t  rx_idx = 0;
static bool     synced = false;

// Returns true and fills x,y,z when a valid packet is parsed
bool try_parse_packet(int16_t &x, int16_t &y, int16_t &z) {
    while (FpgaSerial.available()) {
        uint8_t b = (uint8_t)FpgaSerial.read();

        if (!synced) {
            if (b == PKT_SYNC) {
                rx_buf[0] = b;
                rx_idx    = 1;
                synced    = true;
            }
            continue;
        }

        rx_buf[rx_idx++] = b;

        if (rx_idx == PKT_LEN) {
            synced = false;
            rx_idx = 0;

            // Verify checksum: XOR of bytes 1..6
            uint8_t csum = 0;
            for (int i = 1; i <= 6; i++) csum ^= rx_buf[i];

            if (csum != rx_buf[7]) {
                // Bad packet – discard and wait for next sync
                Serial.println("[WARN] Checksum mismatch");
                return false;
            }

            x = (int16_t)((rx_buf[2] << 8) | rx_buf[1]);
            y = (int16_t)((rx_buf[4] << 8) | rx_buf[3]);
            z = (int16_t)((rx_buf[6] << 8) | rx_buf[5]);
            return true;
        }
    }
    return false;
}

// =============================================================
// Checkpoint 4: angle calculation and 3D math
// =============================================================

void compute_angles(int16_t ax, int16_t ay, int16_t az,
                    float &out_pitch, float &out_roll) {
    float gx = ax / LSB_PER_G;
    float gy = ay / LSB_PER_G;
    float gz = az / LSB_PER_G;

    out_roll  = atan2f(gy, sqrtf(gx*gx + gz*gz)) * (180.0f / M_PI);
    out_pitch = atan2f(gx, sqrtf(gy*gy + gz*gz)) * (180.0f / M_PI);
}

// Cube vertices: ±1 on each axis (8 corners)
static const float cube_v[8][3] = {
    {-1, -1, -1}, { 1, -1, -1}, { 1,  1, -1}, {-1,  1, -1},  // back face
    {-1, -1,  1}, { 1, -1,  1}, { 1,  1,  1}, {-1,  1,  1}   // front face
};

// 12 edges (pairs of vertex indices)
static const uint8_t cube_e[12][2] = {
    {0,1},{1,2},{2,3},{3,0},   // back face
    {4,5},{5,6},{6,7},{7,4},   // front face
    {0,4},{1,5},{2,6},{3,7}    // connecting edges
};

// Rotate and project cube vertices into 2D screen space
// pitch = rotation around Y, roll = rotation around X (in degrees)
void project_cube(float pitch_deg, float roll_deg,
                  int16_t pts2d[8][2]) {
    float pr = pitch_deg * M_PI / 180.0f;
    float rr = roll_deg  * M_PI / 180.0f;

    float cp = cosf(pr), sp = sinf(pr);
    float cr = cosf(rr), sr = sinf(rr);

    for (int i = 0; i < 8; i++) {
        float x = cube_v[i][0];
        float y = cube_v[i][1];
        float z = cube_v[i][2];

        // Rotate around Y (pitch)
        float x1 =  cp * x + sp * z;
        float y1 =  y;
        float z1 = -sp * x + cp * z;

        // Rotate around X (roll)
        float x2 = x1;
        float y2 =  cr * y1 - sr * z1;
        float z2 =  sr * y1 + cr * z1;

        // Perspective projection:
        //   camera sits at z = -CAM_DIST, cube vertices at z ≈ 0 ± 1
        //   dz = z2 + CAM_DIST  (always positive, ranges 3..5)
        //   scl = CAM_DIST / dz (0.8..1.33 — mild perspective)
        float dz  = z2 + CAM_DIST;
        float scl = CAM_DIST / dz;

        pts2d[i][0] = (int16_t)(OLED_WIDTH  / 2 + x2 * CUBE_HALF * scl);
        pts2d[i][1] = (int16_t)(OLED_HEIGHT / 2 + y2 * CUBE_HALF * scl);
    }
}

// =============================================================
// Checkpoint 5: OLED draw
// =============================================================
void draw_cube(float pitch_deg, float roll_deg) {
    int16_t pts[8][2];
    project_cube(pitch_deg, roll_deg, pts);

    display.clearDisplay();

    for (int e = 0; e < 12; e++) {
        uint8_t a = cube_e[e][0];
        uint8_t b = cube_e[e][1];
        display.drawLine(pts[a][0], pts[a][1],
                         pts[b][0], pts[b][1],
                         SSD1306_WHITE);
    }

    display.display();
}

// =============================================================
// Arduino setup / loop
// =============================================================
void setup() {
    Serial.begin(115200);   // USB debug
    FpgaSerial.begin(FPGA_BAUD, SERIAL_8N1, FPGA_RX_PIN, FPGA_TX_PIN);

    Wire.begin(21, 22);
    Wire.setClock(400000);   // Fast-mode I2C: ~4× faster display flush
    if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
        Serial.println("[ERROR] SSD1306 not found");
        while (true) delay(100);
    }
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(10, 28);
    display.println("Waiting for FPGA...");
    display.display();

    Serial.println("[INFO] 3D Cube ready. Waiting for packets...");
}

void loop() {
    int16_t ax, ay, az;
    bool got_packet = false;

    // Drain ALL buffered packets — use only the most recent one.
    // This prevents stale data accumulating while the display is rendering.
    while (try_parse_packet(ax, ay, az)) {
        got_packet = true;
    }

    if (got_packet) {
        float new_pitch, new_roll;
        compute_angles(ax, ay, az, new_pitch, new_roll);

        // Exponential moving average – smooths jitter without much lag
        pitch = EMA_ALPHA * new_pitch + (1.0f - EMA_ALPHA) * pitch;
        roll  = EMA_ALPHA * new_roll  + (1.0f - EMA_ALPHA) * roll;

        draw_cube(pitch, roll);
    }
}
