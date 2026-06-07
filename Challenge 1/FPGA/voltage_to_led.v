// ============================================================
// voltage_to_led.v — Voltage → thermometer LED bar graph
// CrashTech VLSI-2026 — Challenge 1: Volt-Meter
// ============================================================
// Input:  voltage_scaled [8:0]  — value in range 0–330
//         (represents 0.00–3.30 V in units of 0.01 V)
// Output: led_bar [9:0]  — thermometer code driving LEDR[9:0]
//
// Each LED represents 0.33 V (330 / 10 = 33 units):
//   0   units → 0000_0000_00  (all off)
//   33  units → 0000_0000_01  (LEDR[0] on)
//   66  units → 0000_0000_11  (LEDR[1:0] on)
//   ...
//   330 units → 1111_1111_11  (all on)
// ============================================================

module voltage_to_led (
    input      [8:0] voltage_scaled,  // 0–330
    output reg [9:0] led_bar
);

    // Thresholds in units of 0.01 V:
    //   LED n lights when voltage >= (n+1) * 33
    //   LED 0 at >=  33  (0.33 V)
    //   LED 1 at >=  66  (0.66 V)
    //   ...
    //   LED 9 at >= 330  (3.30 V)
    //
    // Use 9-bit comparisons (max value 330 fits in 9 bits).

    always @(*) begin
        led_bar[0] = (voltage_scaled >=  9'd33)  ? 1'b1 : 1'b0;
        led_bar[1] = (voltage_scaled >=  9'd66)  ? 1'b1 : 1'b0;
        led_bar[2] = (voltage_scaled >=  9'd99)  ? 1'b1 : 1'b0;
        led_bar[3] = (voltage_scaled >= 9'd132)  ? 1'b1 : 1'b0;
        led_bar[4] = (voltage_scaled >= 9'd165)  ? 1'b1 : 1'b0;
        led_bar[5] = (voltage_scaled >= 9'd198)  ? 1'b1 : 1'b0;
        led_bar[6] = (voltage_scaled >= 9'd231)  ? 1'b1 : 1'b0;
        led_bar[7] = (voltage_scaled >= 9'd264)  ? 1'b1 : 1'b0;
        led_bar[8] = (voltage_scaled >= 9'd297)  ? 1'b1 : 1'b0;
        led_bar[9] = (voltage_scaled >= 9'd330)  ? 1'b1 : 1'b0;
    end

endmodule
