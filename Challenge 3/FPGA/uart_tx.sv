// ============================================================
// uart_tx.sv — UART Transmitter, parameterised baud, 8N1
// CrashTech VLSI-2026 — Challenge 5: FPGA Volt-Meter
// ============================================================
// Single-byte, start-stop UART transmitter.
// Pull tx_start HIGH for exactly ONE clock cycle while
// providing tx_byte; the module will latch both and begin
// transmitting. Do NOT assert tx_start while tx_busy is HIGH.
//
// Idle line state: tx = 1 (UART mark / idle).
// Frame format  : 1 start bit (0), 8 data bits (LSB first), 1 stop bit (1).
// ============================================================

module uart_tx #(
    parameter int CLK_FREQ = 50_000_000,
    parameter int BAUD     = 115_200
) (
    input  logic       clk,
    input  logic       rst_n,      // async active-low reset
    input  logic       tx_start,   // 1-cycle pulse: begin transmit
    input  logic [7:0] tx_byte,    // byte to send (latched on tx_start)
    output logic       tx,         // serial output (active-high idle)
    output logic       tx_busy     // HIGH while a byte is in flight
);

    // Bit period in clock cycles (434 at 50 MHz / 115200)
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD;

    typedef enum logic [1:0] {
        ST_IDLE  = 2'd0,
        ST_START = 2'd1,
        ST_DATA  = 2'd2,
        ST_STOP  = 2'd3
    } state_t;

    state_t                          state;
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_cnt;
    logic [2:0]                      bit_idx;
    logic [7:0]                      data_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= ST_IDLE;
            tx      <= 1'b1;
            tx_busy <= 1'b0;
            clk_cnt <= '0;
            bit_idx <= '0;
            data_reg<= '0;
        end else begin
            case (state)

                ST_IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        data_reg <= tx_byte;
                        clk_cnt  <= '0;
                        tx_busy  <= 1'b1;   // immediately mark busy
                        state    <= ST_START;
                    end
                end

                ST_START: begin
                    tx <= 1'b0;             // start bit (space)
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= '0;
                        bit_idx <= '0;
                        state   <= ST_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                ST_DATA: begin
                    tx <= data_reg[bit_idx];  // LSB first
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= '0;
                        if (bit_idx == 3'd7) begin
                            state <= ST_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                ST_STOP: begin
                    tx <= 1'b1;             // stop bit (mark)
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= '0;
                        state   <= ST_IDLE;
                        // tx_busy is cleared in the next ST_IDLE entry
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

            endcase
        end
    end

endmodule
