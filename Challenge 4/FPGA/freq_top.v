// =============================================================
// freq_top.v  –  Challenge 6: Frequency Detector
// DE10-Lite (Intel MAX 10, 50 MHz clock)
//
// Protocol:
//   ESP32 generates 256 signed 8-bit sine wave samples at 8000 Hz
//   sample rate and streams them over UART (115200 8N1) to the FPGA.
//   Frames are separated by a ~50 ms silence gap.
//
// Detection:
//   Zero-crossing method.
//   zc = number of sign changes in the 256-byte window
//   freq_hz = zc * Fs / (2 * N) = zc * 8000 / 512 = zc * 125 / 8
//
//   Theoretical max error at the boundaries (100 / 2000 Hz) is < 20 Hz,
//   well within the ±35 Hz acceptance window.
//
// Outputs:
//   HEX3..0  – detected frequency in Hz (decimal, up to 9999)
//   HEX5..4  – off normally; "dE bG" in debug mode
//   LEDR[9:0] – bar graph: more LEDs = higher frequency
//   SW[9]    – debug mode: HEX1=raw zero-crossing count (hex)
//
// UART pin:
//   ARDUINO_IO[0] (PIN_AB5) = FPGA UART RX ← ESP32 TX (GPIO16)
// =============================================================

module freq_top (
    input        MAX10_CLK1_50,
    input  [9:0] SW,
    input  [1:0] KEY,
    output [9:0] LEDR,
    output [7:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    inout  [0:0] ARDUINO_IO
);

    wire clk   = MAX10_CLK1_50;
    wire rst_n = KEY[0];       // KEY[0] active-low reset

    // ------------------------------------------------------------------
    // UART RX: 115200 baud, receive signed 8-bit samples from ESP32
    // ------------------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ(50_000_000),
        .BAUD(115200)
    ) u_rx (
        .clk    (clk),
        .rst_n  (rst_n),
        .rx_in  (ARDUINO_IO[0]),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    assign ARDUINO_IO[0] = 1'bz;   // input only

    // ------------------------------------------------------------------
    // Frame sync: gap timeout
    //   At 115200 baud each byte takes ~87 us → 256 bytes ≈ 22 ms.
    //   ESP32 waits 50 ms between frames.
    //   A 30 ms (1,500,000 cycle) timeout reliably ends the frame.
    // ------------------------------------------------------------------
    localparam GAP_TIMEOUT = 1_500_000;  // 30 ms at 50 MHz

    reg [20:0] gap_cnt;        // 21 bits covers up to ~42 ms
    reg        in_frame;

    // ------------------------------------------------------------------
    // Zero-crossing accumulator
    //   A sign change occurs when consecutive non-zero samples have
    //   opposite MSBs (MSB=1 → negative in two's complement).
    // ------------------------------------------------------------------
    reg        prev_sign;      // sign of last non-zero sample
    reg        prev_valid;     // set once we have a first valid sign
    reg [7:0]  zc_cnt;         // zero-crossing count for current frame

    // Latched results (updated at end of each complete frame)
    reg [7:0]  zc_latch;       // zero crossings from last frame
    reg [15:0] freq_hz;        // detected frequency in Hz

    // Current sample sign (MSB = 1 means negative)
    wire curr_sign = rx_data[7];
    // Treat 0x00 and 0x80 as "zero-valued" and skip for crossing purposes
    wire sample_nonzero = (rx_data != 8'h00) && (rx_data != 8'h80);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gap_cnt    <= 0;
            in_frame   <= 0;
            prev_sign  <= 0;
            prev_valid <= 0;
            zc_cnt     <= 0;
            zc_latch   <= 0;
            freq_hz    <= 0;
        end else begin

            if (rx_valid) begin
                // ---- Byte arrived: reset gap, accumulate crossing ----
                gap_cnt    <= 0;
                in_frame   <= 1;

                if (sample_nonzero) begin
                    if (prev_valid && (curr_sign != prev_sign))
                        zc_cnt <= zc_cnt + 1;
                    prev_sign  <= curr_sign;
                    prev_valid <= 1;
                end

            end else if (in_frame) begin
                // ---- No byte: count gap ----
                if (gap_cnt < GAP_TIMEOUT) begin
                    gap_cnt <= gap_cnt + 1;
                end else begin
                    // ---- Frame complete: compute frequency ----
                    // freq_hz = zc_cnt * Fs / (2 * N)
                    //         = zc_cnt * 8000 / 512
                    //         = zc_cnt * 125 / 8
                    //         = (zc_cnt * 125) >> 3
                    in_frame   <= 0;
                    prev_valid <= 0;
                    zc_latch   <= zc_cnt;
                    freq_hz    <= ({8'h00, zc_cnt} * 16'd125) >> 3;
                    zc_cnt     <= 0;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Binary → 4-digit BCD (for values 0–9999)
    //   Uses iterative subtraction to avoid multi-cycle division.
    //   freq_hz max = 2000, so the range fits easily.
    // ------------------------------------------------------------------
    reg [3:0] d3, d2, d1, d0;  // thousands, hundreds, tens, units
    reg [15:0] tmp;

    always @(*) begin
        tmp = freq_hz;
        d3 = 0; d2 = 0; d1 = 0; d0 = 0;
        // Thousands
        if (tmp >= 16'd9000) begin d3 = 4'd9; tmp = tmp - 16'd9000; end
        else if (tmp >= 16'd8000) begin d3 = 4'd8; tmp = tmp - 16'd8000; end
        else if (tmp >= 16'd7000) begin d3 = 4'd7; tmp = tmp - 16'd7000; end
        else if (tmp >= 16'd6000) begin d3 = 4'd6; tmp = tmp - 16'd6000; end
        else if (tmp >= 16'd5000) begin d3 = 4'd5; tmp = tmp - 16'd5000; end
        else if (tmp >= 16'd4000) begin d3 = 4'd4; tmp = tmp - 16'd4000; end
        else if (tmp >= 16'd3000) begin d3 = 4'd3; tmp = tmp - 16'd3000; end
        else if (tmp >= 16'd2000) begin d3 = 4'd2; tmp = tmp - 16'd2000; end
        else if (tmp >= 16'd1000) begin d3 = 4'd1; tmp = tmp - 16'd1000; end
        else                       d3 = 4'd0;
        // Hundreds
        if      (tmp >= 16'd900) begin d2 = 4'd9; tmp = tmp - 16'd900; end
        else if (tmp >= 16'd800) begin d2 = 4'd8; tmp = tmp - 16'd800; end
        else if (tmp >= 16'd700) begin d2 = 4'd7; tmp = tmp - 16'd700; end
        else if (tmp >= 16'd600) begin d2 = 4'd6; tmp = tmp - 16'd600; end
        else if (tmp >= 16'd500) begin d2 = 4'd5; tmp = tmp - 16'd500; end
        else if (tmp >= 16'd400) begin d2 = 4'd4; tmp = tmp - 16'd400; end
        else if (tmp >= 16'd300) begin d2 = 4'd3; tmp = tmp - 16'd300; end
        else if (tmp >= 16'd200) begin d2 = 4'd2; tmp = tmp - 16'd200; end
        else if (tmp >= 16'd100) begin d2 = 4'd1; tmp = tmp - 16'd100; end
        else                      d2 = 4'd0;
        // Tens
        if      (tmp >= 16'd90) begin d1 = 4'd9; tmp = tmp - 16'd90; end
        else if (tmp >= 16'd80) begin d1 = 4'd8; tmp = tmp - 16'd80; end
        else if (tmp >= 16'd70) begin d1 = 4'd7; tmp = tmp - 16'd70; end
        else if (tmp >= 16'd60) begin d1 = 4'd6; tmp = tmp - 16'd60; end
        else if (tmp >= 16'd50) begin d1 = 4'd5; tmp = tmp - 16'd50; end
        else if (tmp >= 16'd40) begin d1 = 4'd4; tmp = tmp - 16'd40; end
        else if (tmp >= 16'd30) begin d1 = 4'd3; tmp = tmp - 16'd30; end
        else if (tmp >= 16'd20) begin d1 = 4'd2; tmp = tmp - 16'd20; end
        else if (tmp >= 16'd10) begin d1 = 4'd1; tmp = tmp - 16'd10; end
        else                     d1 = 4'd0;
        // Units
        d0 = tmp[3:0];
    end

    // ------------------------------------------------------------------
    // Seven-segment display
    //   Normal mode  (SW[9]=0): HEX3..0 = detected frequency in Hz
    //   Debug mode   (SW[9]=1): HEX3..0 = frequency (same),
    //                           HEX1    = raw zero-crossing count (hex, lo)
    //                           HEX0    = raw zero-crossing count (hex, hi)
    // ------------------------------------------------------------------
    wire [7:0] seg0_normal, seg1_normal, seg2_normal, seg3_normal;

    seven_segment seg_u0 (.value(d0), .segments(seg0_normal));
    seven_segment seg_u1 (.value(d1), .segments(seg1_normal));
    seven_segment seg_u2 (.value(d2), .segments(seg2_normal));
    seven_segment seg_u3 (.value(d3), .segments(seg3_normal));

    // Debug: show zc_latch as two hex digits on HEX1..0
    wire [7:0] seg0_debug, seg1_debug;
    seven_segment seg_d0 (.value(zc_latch[3:0]), .segments(seg0_debug));
    seven_segment seg_d1 (.value(zc_latch[7:4]), .segments(seg1_debug));

    assign HEX0 = SW[9] ? seg0_debug   : seg0_normal;
    assign HEX1 = SW[9] ? seg1_debug   : seg1_normal;
    assign HEX2 = seg2_normal;
    assign HEX3 = seg3_normal;
    assign HEX4 = 8'hFF;   // blank
    assign HEX5 = 8'hFF;   // blank

    // ------------------------------------------------------------------
    // LED bar graph: LEDR[9:0] proportional to frequency
    //   freq range 100-2000 Hz mapped to 1-10 LEDs
    //   Each step ≈ 190 Hz
    // ------------------------------------------------------------------
    wire [3:0] led_level =
        (freq_hz == 0)         ? 4'd0  :
        (freq_hz < 16'd295)    ? 4'd1  :
        (freq_hz < 16'd485)    ? 4'd2  :
        (freq_hz < 16'd675)    ? 4'd3  :
        (freq_hz < 16'd865)    ? 4'd4  :
        (freq_hz < 16'd1055)   ? 4'd5  :
        (freq_hz < 16'd1245)   ? 4'd6  :
        (freq_hz < 16'd1435)   ? 4'd7  :
        (freq_hz < 16'd1625)   ? 4'd8  :
        (freq_hz < 16'd1815)   ? 4'd9  :
                                 4'd10;

    assign LEDR[0] = (led_level >= 4'd1);
    assign LEDR[1] = (led_level >= 4'd2);
    assign LEDR[2] = (led_level >= 4'd3);
    assign LEDR[3] = (led_level >= 4'd4);
    assign LEDR[4] = (led_level >= 4'd5);
    assign LEDR[5] = (led_level >= 4'd6);
    assign LEDR[6] = (led_level >= 4'd7);
    assign LEDR[7] = (led_level >= 4'd8);
    assign LEDR[8] = (led_level >= 4'd9);
    assign LEDR[9] = (led_level >= 4'd10);

endmodule
