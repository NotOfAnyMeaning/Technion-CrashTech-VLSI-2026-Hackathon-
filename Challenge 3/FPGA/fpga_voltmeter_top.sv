// ============================================================
// fpga_voltmeter_top.sv — Top Level, Challenge 5: FPGA Volt-Meter
// CrashTech VLSI-2026 — DE10-Lite (Intel MAX 10)
// ============================================================
//
// SYSTEM OVERVIEW
// ───────────────
//  MAX 10 internal ADC reads Arduino header A0 (ADCIN1).
//  Internal 2.5 V VREF → 12-bit result, range 0–4095.
//  Voltage (0.00 V – 2.49 V) displayed on HEX2..HEX0 as X.XX.
//  Voltage sent to ESP32 as ASCII string "X.XX\n" at 115200 baud.
//  LEDR[9:0] shows a proportional thermometer bar graph.
//
// PIN USAGE
// ─────────
//  ARDUINO_IO[0] — tied to Z  (unused; keep as high-Z input)
//  ARDUINO_IO[1] — UART TX to ESP32 RX (GPIO17, PIN_AB6)
//  ARDUINO_IO[15:2] — tied to Z
//  ARDUINO_RESET_N  — tied to Z
//  A0 (ADCIN1)     — routed internally via Modular ADC Core IP
//
// DISPLAY MAPPING
// ───────────────
//  HEX2 = integer digit  (0–2), decimal point ON
//  HEX1 = tenths digit   (0–9)
//  HEX0 = hundredths digit (0–9)
//  HEX5..HEX3 = blank
//
// UART PROTOCOL
// ─────────────
//  Format   : "X.XX\n"  (5 bytes, ASCII, newline-terminated)
//  Example  : "1.65\n" = 1.65 V
//  Baud rate: 115200, 8N1
//  Rate     : ~10 Hz (one packet every 100 ms)
//
// KEY ASSIGNMENT
// ──────────────
//  KEY[0] = active-low async reset
// ============================================================

module fpga_voltmeter_top (
    input           MAX10_CLK1_50,
    input   [9:0]   SW,
    input   [1:0]   KEY,
    output  [9:0]   LEDR,
    output  [7:0]   HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    inout   [15:0]  ARDUINO_IO,
    inout           ARDUINO_RESET_N
);

    // =========================================================
    // Clock & Reset
    // =========================================================
    wire clk   = MAX10_CLK1_50;     // 50 MHz
    wire rst_n = KEY[0];            // active-low; KEY[0] pulled high normally

    // =========================================================
    // Arduino Header Tristate
    // =========================================================
    // IO[1] driven by UART TX; everything else is high-Z.
    logic uart_tx_pin;
    assign ARDUINO_IO[15:2] = 14'bz;
    assign ARDUINO_IO[1]    = uart_tx_pin;  // FPGA TX → ESP32 RX (GPIO17)
    assign ARDUINO_IO[0]    = 1'bz;         // unused
    assign ARDUINO_RESET_N  = 1'bz;

    // =========================================================
    // PLL: 50 MHz → 10 MHz for ADC clock
    // =========================================================
    logic clk_adc;
    logic pll_locked;

    pll_10m u_pll (
        .inclk0  (clk),
        .clk10m  (clk_adc),
        .locked  (pll_locked)
    );

    // =========================================================
    // ADC Reader
    // Wraps modular_adc_0 IP (must be generated — see adc_reader.sv)
    // =========================================================
    logic [11:0] adc_raw;
    logic        adc_valid;     // 1-cycle pulse per new 12-bit sample

    adc_reader u_adc_reader (
        .clk        (clk),
        .rst_n      (rst_n),
        .clk_adc    (clk_adc),
        .pll_locked (pll_locked),
        .adc_raw    (adc_raw),
        .adc_valid  (adc_valid)
    );

    // =========================================================
    // Voltage Conversion
    // voltage_centi = adc_raw * 250 / 4096  (integer centi-volts)
    //
    // Derivation:
    //   ADC full-scale = 4095 → 2.5 V (internal 2.5 V VREF)
    //   voltage_centi (0.01 V units) = raw * 2500 / 4095 / 10
    //                                ≈ raw * 250 >> 12       (÷4096)
    //   Max error: ~0.006% — imperceptible on a 2-decimal display
    //
    // Combinational multiply, single register stage for timing closure.
    // Both operands sign-extended to 20 bits; product fits in 20 bits
    // (max: 4095 × 250 = 1 023 750 < 2^20 = 1 048 576).
    // =========================================================
    logic [19:0] raw_x250_comb;    // combinational product
    logic [7:0]  voltage_centi;    // 0–249, updated on every valid ADC sample

    assign raw_x250_comb = {8'd0, adc_raw} * 20'd250;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            voltage_centi <= '0;
        else if (adc_valid)
            voltage_centi <= raw_x250_comb[19:12];  // >> 12 = ÷ 4096
    end

    // BCD decomposition (combinational; Quartus synthesises ÷100, ÷10 cleanly)
    logic [3:0] d2, d1, d0;    // integer, tenths, hundredths
    always_comb begin
        d2 = voltage_centi / 100;
        d1 = (voltage_centi % 100) / 10;
        d0 = voltage_centi % 10;
    end

    // =========================================================
    // 7-Segment Display
    // =========================================================
    seven_seg_decoder u_hex2 (
        .digit  (d2),
        .blank  (1'b0),
        .dp     (1'b1),         // decimal point ON for the integer digit
        .seg    (HEX2)
    );

    seven_seg_decoder u_hex1 (
        .digit  (d1),
        .blank  (1'b0),
        .dp     (1'b0),
        .seg    (HEX1)
    );

    seven_seg_decoder u_hex0 (
        .digit  (d0),
        .blank  (1'b0),
        .dp     (1'b0),
        .seg    (HEX0)
    );

    // Blank upper digits
    assign HEX3 = 8'hFF;
    assign HEX4 = 8'hFF;
    assign HEX5 = 8'hFF;

    // =========================================================
    // LED Bar Graph
    // =========================================================
    led_bar u_led (
        .voltage_centi (voltage_centi),
        .led_out       (LEDR)
    );

    // =========================================================
    // UART TX — sends "X.XX\n" at 10 Hz
    // =========================================================
    localparam int SEND_PERIOD = 5_000_000;     // 100 ms @ 50 MHz

    logic [22:0] send_timer;
    logic        trigger_send;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            send_timer   <= '0;
            trigger_send <= 1'b0;
        end else begin
            trigger_send <= 1'b0;
            if (send_timer == SEND_PERIOD - 1) begin
                send_timer   <= '0;
                trigger_send <= 1'b1;
            end else begin
                send_timer <= send_timer + 1;
            end
        end
    end

    // ---- UART byte-level transmitter ----
    logic       tx_start;
    logic [7:0] tx_byte;
    logic       tx_busy;

    uart_tx #(
        .CLK_FREQ (50_000_000),
        .BAUD     (115_200)
    ) u_uart_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_start (tx_start),
        .tx_byte  (tx_byte),
        .tx       (uart_tx_pin),
        .tx_busy  (tx_busy)
    );

    // ---- String send state machine ----
    // Sends: d2_lat, '.', d1_lat, d0_lat, '\n'   (5 bytes)
    typedef enum logic [2:0] {
        STR_IDLE = 3'd0,
        STR_B0   = 3'd1,   // waiting for integer-digit byte to finish
        STR_B1   = 3'd2,   // waiting for '.' to finish
        STR_B2   = 3'd3,   // waiting for tenths to finish
        STR_B3   = 3'd4,   // waiting for hundredths to finish
        STR_B4   = 3'd5    // waiting for '\n' to finish
    } str_state_t;

    str_state_t str_state;
    logic [3:0] d2_lat, d1_lat, d0_lat;    // digits latched at send time

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            str_state <= STR_IDLE;
            tx_start  <= 1'b0;
            tx_byte   <= 8'd0;
            d2_lat    <= 4'd0;
            d1_lat    <= 4'd0;
            d0_lat    <= 4'd0;
        end else begin
            tx_start <= 1'b0;   // default: no start pulse this cycle

            case (str_state)

                STR_IDLE: begin
                    // Wait for rate-limit trigger; only launch if TX is free.
                    if (trigger_send && !tx_busy) begin
                        d2_lat    <= d2;
                        d1_lat    <= d1;
                        d0_lat    <= d0;
                        // Send byte 0: integer digit ('0'=0x30 + d2)
                        tx_byte   <= 8'h30 + {4'h0, d2};
                        tx_start  <= 1'b1;
                        str_state <= STR_B0;
                    end
                end

                // After launching byte 0, wait for TX to go idle,
                // then send the decimal point.
                STR_B0: begin
                    if (!tx_busy) begin
                        tx_byte   <= 8'h2E;     // '.'
                        tx_start  <= 1'b1;
                        str_state <= STR_B1;
                    end
                end

                // After '.', send tenths digit.
                STR_B1: begin
                    if (!tx_busy) begin
                        tx_byte   <= 8'h30 + {4'h0, d1_lat};
                        tx_start  <= 1'b1;
                        str_state <= STR_B2;
                    end
                end

                // After tenths, send hundredths digit.
                STR_B2: begin
                    if (!tx_busy) begin
                        tx_byte   <= 8'h30 + {4'h0, d0_lat};
                        tx_start  <= 1'b1;
                        str_state <= STR_B3;
                    end
                end

                // After hundredths, send newline terminator.
                STR_B3: begin
                    if (!tx_busy) begin
                        tx_byte   <= 8'h0A;     // '\n' LF
                        tx_start  <= 1'b1;
                        str_state <= STR_B4;
                    end
                end

                // Wait for '\n' to finish, then return to idle.
                STR_B4: begin
                    if (!tx_busy) begin
                        str_state <= STR_IDLE;
                    end
                end

                default: str_state <= STR_IDLE;

            endcase
        end
    end

endmodule
