// ============================================================
// led_bar.sv — Voltage → 10-LED thermometer bar graph
// CrashTech VLSI-2026 — Challenge 5: FPGA Volt-Meter
// ============================================================
// Input : voltage_centi [7:0]
//           Voltage expressed in units of 0.01 V, range 0–249
//           (maps to 0.00 V – 2.49 V, MAX 10 ADC 2.5 V VREF)
//
// Output: led_out [9:0]  — thermometer code for LEDR[9:0]
//           1 = LED ON, 0 = LED OFF
//
// Each LED represents 0.25 V (25 centi-volt step):
//   LEDR[0] on  ≥ 25  (≥ 0.25 V)
//   LEDR[1] on  ≥ 50  (≥ 0.50 V)
//   LEDR[2] on  ≥ 75  (≥ 0.75 V)
//   LEDR[3] on  ≥ 100 (≥ 1.00 V)
//   LEDR[4] on  ≥ 125 (≥ 1.25 V)
//   LEDR[5] on  ≥ 150 (≥ 1.50 V)
//   LEDR[6] on  ≥ 175 (≥ 1.75 V)
//   LEDR[7] on  ≥ 200 (≥ 2.00 V)
//   LEDR[8] on  ≥ 225 (≥ 2.25 V)
//   LEDR[9] on  ≥ 250 (≥ 2.50 V — effectively full-scale)
// ============================================================

module led_bar (
    input  logic [7:0] voltage_centi,   // 0–249
    output logic [9:0] led_out          // thermometer code
);

    always_comb begin
        led_out[0] = (voltage_centi >= 8'd25)  ? 1'b1 : 1'b0;
        led_out[1] = (voltage_centi >= 8'd50)  ? 1'b1 : 1'b0;
        led_out[2] = (voltage_centi >= 8'd75)  ? 1'b1 : 1'b0;
        led_out[3] = (voltage_centi >= 8'd100) ? 1'b1 : 1'b0;
        led_out[4] = (voltage_centi >= 8'd125) ? 1'b1 : 1'b0;
        led_out[5] = (voltage_centi >= 8'd150) ? 1'b1 : 1'b0;
        led_out[6] = (voltage_centi >= 8'd175) ? 1'b1 : 1'b0;
        led_out[7] = (voltage_centi >= 8'd200) ? 1'b1 : 1'b0;
        led_out[8] = (voltage_centi >= 8'd225) ? 1'b1 : 1'b0;
        led_out[9] = (voltage_centi >= 8'd250) ? 1'b1 : 1'b0;
    end

endmodule
