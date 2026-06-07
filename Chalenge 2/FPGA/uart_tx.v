// =============================================================
// uart_tx.v  –  UART Transmitter, 115200 8N1
//
// clk = 50 MHz → baud divisor = 50_000_000 / 115200 ≈ 434
//
// Interface:
//   tx_data   – byte to send
//   tx_start  – 1-cycle pulse to begin transmission
//   tx_busy   – high while transmitting
//   tx_pin    – serial output (idle HIGH)
// =============================================================
module uart_tx (
    input  wire       clk,
    input  wire       rst_n,

    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_busy,
    output reg        tx_pin
);

localparam BAUD_DIV = 434;  // 50_000_000 / 115200

reg [8:0]  baud_cnt;
reg [3:0]  bit_idx;   // 0=start, 1-8=data, 9=stop
reg [9:0]  frame;     // {stop, data[7:0], start}

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_pin   <= 1;
        tx_busy  <= 0;
        baud_cnt <= 0;
        bit_idx  <= 0;
        frame    <= 0;
    end else begin
        if (!tx_busy) begin
            tx_pin <= 1;
            if (tx_start) begin
                // {stop=1, data, start=0}
                frame    <= {1'b1, tx_data, 1'b0};
                bit_idx  <= 0;
                baud_cnt <= 0;
                tx_busy  <= 1;
            end
        end else begin
            if (baud_cnt == BAUD_DIV - 1) begin
                baud_cnt <= 0;
                tx_pin   <= frame[bit_idx];
                if (bit_idx == 4'd9) begin
                    tx_busy <= 0;
                end else begin
                    bit_idx <= bit_idx + 1;
                end
            end else begin
                baud_cnt <= baud_cnt + 1;
            end
        end
    end
end

endmodule
