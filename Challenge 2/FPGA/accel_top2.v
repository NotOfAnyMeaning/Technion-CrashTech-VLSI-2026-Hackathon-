// =============================================================
// accel_top2.v  –  Top-level for 3D Cube Accelerometer (2nd try)
//
// DE10-Lite (Intel MAX 10, 10M50DAF484C7G)
//
// Checkpoint 1: SPI reads ADXL345, X/Y mapped to LEDs
// Checkpoint 2: UART transmits 8-byte packet at 50 Hz
// =============================================================
module accel_top2 (
    input  wire        clk,       // 50 MHz (PIN_P11)
    input  wire        rst_n,     // KEY[0] active-low

    // ADXL345 SPI
    output wire        spi_sclk,
    output wire        spi_cs_n,
    output wire        spi_mosi,
    input  wire        spi_miso,

    // UART to ESP32
    output wire        uart_tx,

    // LEDs
    output wire [9:0]  led
);

// ---- Accelerometer data ----
wire [15:0] ax, ay, az;
wire        dv;

adxl345_spi u_spi (
    .clk        (clk),
    .rst_n      (rst_n),
    .spi_sclk   (spi_sclk),
    .spi_cs_n   (spi_cs_n),
    .spi_mosi   (spi_mosi),
    .spi_miso   (spi_miso),
    .accel_x    (ax),
    .accel_y    (ay),
    .accel_z    (az),
    .data_valid (dv)
);

// ---- UART packet sender ----
packet_sender u_pkt (
    .clk        (clk),
    .rst_n      (rst_n),
    .accel_x    (ax),
    .accel_y    (ay),
    .accel_z    (az),
    .data_valid (dv),
    .uart_tx    (uart_tx)
);

// ---- LED display: tilt feedback ----
// ax/ay are sign-extended 10-bit values in a 16-bit container.
// ADXL345 in ±2g mode: ~256 counts ≈ 1g.
// Typical full-tilt range: abs value 0..~512.
//
// Show only X axis (roll) across the full 10-LED row.
// This avoids conflicting center indications when trying to render
// both pitch and roll on a single linear LED strip.
//
// Magnitude is computed via a proper 16-bit two's-complement negate
// so that values like -256 (= 0xFF00) yield 256, not 0.
reg [9:0] led_reg;

// 16-bit absolute value, then take lower 10 bits (covers 0..512)
wire [15:0] ax_abs16 = ax[15] ? (~ax + 16'd1) : ax;
wire [9:0]  ax_abs   = ax_abs16[9:0];

// Thresholds (256 ≈ 1g):
//   25  counts → dead zone / nearly flat
//   50  counts → slight tilt   (~11°)
//   100 counts → moderate tilt (~23°)
//   180 counts → strong tilt   (~45°)
always @(*) begin
    // X axis: LEDs [9:0]  (right = LED[9], left = LED[0])
    if (ax_abs < 10'd25) begin
        led_reg = 10'b0000110000;          // flat: two center LEDs
    end else if (!ax[15]) begin             // tilt right (positive)
        led_reg = (ax_abs >= 10'd180) ? 10'b1111110000 :
                  (ax_abs >= 10'd100) ? 10'b0111110000 :
                  (ax_abs >= 10'd50)  ? 10'b0011110000 :
                                        10'b0001110000;
    end else begin                          // tilt left (negative)
        led_reg = (ax_abs >= 10'd180) ? 10'b0000111111 :
                  (ax_abs >= 10'd100) ? 10'b0000111110 :
                  (ax_abs >= 10'd50)  ? 10'b0000111100 :
                                        10'b0000111000;
    end
end

assign led = led_reg;

endmodule
