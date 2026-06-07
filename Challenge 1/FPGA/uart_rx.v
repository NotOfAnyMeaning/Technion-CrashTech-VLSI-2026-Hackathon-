// ============================================================
// uart_rx.v — UART Receiver, 9600 baud, 50 MHz clock, 8N1
// CrashTech VLSI-2026 — Challenge 1: Volt-Meter
// ============================================================
// Oversamples at 16× baud rate using a mid-bit sample strategy.
// Double-flop synchroniser on the RX input prevents metastability.
// rx_valid pulses HIGH for exactly one clock cycle when a byte is ready.
// ============================================================

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 9600
)(
    input            clk,
    input            rst_n,   // active-low async reset
    input            rx,      // serial input (ARDUINO_IO[0])
    output reg [7:0] rx_data,
    output reg       rx_valid  // 1-cycle pulse when byte ready
);

    // Cycles per bit at the given baud rate
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD;   // 5208
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;  // 2604

    // State encoding
    localparam ST_IDLE  = 2'd0;
    localparam ST_START = 2'd1;
    localparam ST_DATA  = 2'd2;
    localparam ST_STOP  = 2'd3;

    // ---- Two-flop synchroniser ----
    reg rx_s1, rx_s2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_s1 <= 1'b1;
            rx_s2 <= 1'b1;
        end else begin
            rx_s1 <= rx;
            rx_s2 <= rx_s1;
        end
    end

    // ---- Main receive FSM ----
    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            clk_cnt   <= 16'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;  // default: not valid

            case (state)

                ST_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_s2 == 1'b0)     // falling edge = start bit
                        state <= ST_START;
                end

                ST_START: begin
                    // Wait to the midpoint of the start bit to verify it
                    if (clk_cnt == HALF_BIT - 1) begin
                        if (rx_s2 == 1'b0) begin
                            clk_cnt <= 16'd0;
                            state   <= ST_DATA;
                        end else begin
                            state <= ST_IDLE;  // glitch, abort
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                ST_DATA: begin
                    // Sample at the centre of each data bit
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt            <= 16'd0;
                        shift_reg[bit_idx] <= rx_s2;  // LSB first
                        if (bit_idx == 3'd7)
                            state <= ST_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                ST_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_data  <= shift_reg;
                        rx_valid <= 1'b1;
                        state    <= ST_IDLE;
                        clk_cnt  <= 16'd0;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= ST_IDLE;

            endcase
        end
    end

endmodule
