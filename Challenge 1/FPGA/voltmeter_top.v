// ============================================================
// voltmeter_top.v — Top-level, Challenge 1: Volt-Meter
// CrashTech VLSI-2026 — DE10-Lite (Intel MAX 10)
// ============================================================
// UART RX: ARDUINO_IO[0]  (PIN_AB5)  ← ESP32 GPIO16 TX
// UART TX: ARDUINO_IO[1]  (PIN_AB6)  — driven high-Z (unused)
// All other ARDUINO_IO pins: high-Z
//
// Protocol: ESP32 sends "NNN\n" where NNN = voltage × 100
//   e.g. "165\n" → 1.65 V
//   Valid range: 000–330
//
// Display mapping:
//   HEX2 = integer digit  (X)    — decimal point ON
//   HEX1 = tenths digit   (.X)
//   HEX0 = hundredths digit (X)
//   HEX5..HEX3 = blanked
//
// Reset: KEY[0] (active-low, held high by default)
// ============================================================

module voltmeter_top (
    input           MAX10_CLK1_50,
    input   [9:0]   SW,
    input   [1:0]   KEY,
    output  [9:0]   LEDR,
    output  [7:0]   HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    inout   [15:0]  ARDUINO_IO,
    inout           ARDUINO_RESET_N
);

    // ---- Clock / Reset ----
    wire clk   = MAX10_CLK1_50;
    wire rst_n = KEY[0];               // KEY[0] is active-low reset

    // ---- Arduino header tristate ----
    // IO[0] = UART RX input from ESP32
    // IO[1] = UART TX (not used here, drive Z)
    // IO[15:2] = high-Z
    assign ARDUINO_IO[15:1] = 15'bz;
    // IO[0] is input — leave inout undriven so it reads externally
    assign ARDUINO_IO[0]    = 1'bz;
    assign ARDUINO_RESET_N  = 1'bz;

    wire uart_rx_pin = ARDUINO_IO[0];

    // ---- UART Receiver ----
    wire [7:0] rx_byte;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ(50_000_000),
        .BAUD    (9600)
    ) u_uart_rx (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx      (uart_rx_pin),
        .rx_data (rx_byte),
        .rx_valid(rx_valid)
    );

    // ---- Packet Parser ----
    // Receives "NNN\n" (3 ASCII digits then newline/CR).
    // Accumulates digits and commits on '\n' or '\r'.
    // Rejects packets with non-digit characters.

    reg [8:0]  voltage_reg;   // 0–330, committed value shown on display
    reg [8:0]  accum;         // running accumulator during reception
    reg [1:0]  digit_count;   // how many digits received so far
    reg        packet_ok;     // flag: current packet has only digits

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voltage_reg <= 9'd0;
            accum       <= 9'd0;
            digit_count <= 2'd0;
            packet_ok   <= 1'b1;
        end else if (rx_valid) begin
            if (rx_byte == 8'h0A || rx_byte == 8'h0D) begin
                // End of packet
                if (packet_ok && digit_count == 2'd3 && accum <= 9'd330)
                    voltage_reg <= accum;
                // Reset for next packet
                accum       <= 9'd0;
                digit_count <= 2'd0;
                packet_ok   <= 1'b1;
            end else if (rx_byte >= 8'h30 && rx_byte <= 8'h39 && digit_count < 2'd3) begin
                // ASCII digit '0'–'9'
                accum       <= accum * 9'd10 + {5'd0, rx_byte[3:0]};
                digit_count <= digit_count + 2'd1;
            end else begin
                // Unexpected character — invalidate this packet
                packet_ok <= 1'b0;
            end
        end
    end

    // ---- Split voltage into three BCD digits ----
    // voltage_reg = 0–330
    wire [3:0] d_hundreds = voltage_reg / 100;          // 0–3
    wire [3:0] d_tens     = (voltage_reg % 100) / 10;   // 0–9
    wire [3:0] d_ones     = voltage_reg % 10;           // 0–9

    // ---- 7-Segment Decoders ----
    // HEX2 = integer part (hundreds), decimal point ON
    // HEX1 = tenths
    // HEX0 = hundredths
    // HEX5..3 = blank

    seven_seg_decoder u_hex2 (
        .digit(d_hundreds),
        .blank(1'b0),
        .dp   (1'b1),   // decimal point after the integer digit
        .seg  (HEX2)
    );

    seven_seg_decoder u_hex1 (
        .digit(d_tens),
        .blank(1'b0),
        .dp   (1'b0),
        .seg  (HEX1)
    );

    seven_seg_decoder u_hex0 (
        .digit(d_ones),
        .blank(1'b0),
        .dp   (1'b0),
        .seg  (HEX0)
    );

    // Blank the unused displays
    seven_seg_decoder u_hex3 (.digit(4'd0), .blank(1'b1), .dp(1'b0), .seg(HEX3));
    seven_seg_decoder u_hex4 (.digit(4'd0), .blank(1'b1), .dp(1'b0), .seg(HEX4));
    seven_seg_decoder u_hex5 (.digit(4'd0), .blank(1'b1), .dp(1'b0), .seg(HEX5));

    // ---- LED Bar Graph ----
    voltage_to_led u_led (
        .voltage_scaled(voltage_reg),
        .led_bar       (LEDR)
    );

endmodule
