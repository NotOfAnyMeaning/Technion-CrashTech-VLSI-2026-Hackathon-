// =============================================================
// packet_sender.v  –  Package accel data and send over UART
//
// Frame format (8 bytes):
//   [0] 0xAA         – sync
//   [1] accel_x[7:0] – DATAX0
//   [2] accel_x[15:8]– DATAX1
//   [3] accel_y[7:0] – DATAY0
//   [4] accel_y[15:8]– DATAY1
//   [5] accel_z[7:0] – DATAZ0
//   [6] accel_z[15:8]– DATAZ1
//   [7] XOR(bytes 1..6) – checksum
//
// Transmit rate: ~50 Hz (every 1_000_000 cycles at 50 MHz)
// =============================================================
module packet_sender (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [15:0] accel_x,
    input  wire [15:0] accel_y,
    input  wire [15:0] accel_z,
    input  wire        data_valid,

    output wire        uart_tx
);

// ---- 200 Hz pacing timer (50_000_000 / 200 = 250_000) ----
localparam PACE_CNT = 250_000;
reg [19:0] pace_cnt;
reg        send_trigger;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pace_cnt     <= 0;
        send_trigger <= 0;
    end else begin
        send_trigger <= 0;
        if (pace_cnt == PACE_CNT - 1) begin
            pace_cnt     <= 0;
            send_trigger <= 1;
        end else begin
            pace_cnt <= pace_cnt + 1;
        end
    end
end

// ---- UART byte serialiser ----
reg        uart_start;
reg [7:0]  uart_byte;
wire       uart_busy;

uart_tx u_uart (
    .clk      (clk),
    .rst_n    (rst_n),
    .tx_data  (uart_byte),
    .tx_start (uart_start),
    .tx_busy  (uart_busy),
    .tx_pin   (uart_tx)
);

// ---- Packet state machine ----
// Each byte uses two states:
//   S_SEND:     load byte, assert uart_start (1 clock)
//   S_WAIT_HI:  wait for uart_busy to go HIGH (confirms UART accepted byte)
//   S_WAIT_LO:  wait for uart_busy to go LOW  (byte fully transmitted)
// This prevents the race where uart_busy hasn't risen yet when the next state checks it.

localparam [3:0]
    PS_IDLE     = 4'd0,
    PS_LATCH    = 4'd1,
    PS_SEND     = 4'd2,
    PS_WAIT_HI  = 4'd3,
    PS_WAIT_LO  = 4'd4;

reg [3:0]  ps_state;
reg [3:0]  byte_idx;    // 0-7
reg [7:0]  pkt [0:7];   // packet buffer
reg [15:0] lx, ly, lz;
reg [7:0]  csum;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ps_state  <= PS_IDLE;
        uart_start <= 0;
        uart_byte  <= 0;
        byte_idx   <= 0;
        lx <= 0; ly <= 0; lz <= 0; csum <= 0;
        pkt[0] <= 0; pkt[1] <= 0; pkt[2] <= 0; pkt[3] <= 0;
        pkt[4] <= 0; pkt[5] <= 0; pkt[6] <= 0; pkt[7] <= 0;
    end else begin
        uart_start <= 0; // default

        case (ps_state)

        PS_IDLE: begin
            if (send_trigger)
                ps_state <= PS_LATCH;
        end

        PS_LATCH: begin
            lx = accel_x;
            ly = accel_y;
            lz = accel_z;
            csum = lx[7:0] ^ lx[15:8] ^ ly[7:0] ^ ly[15:8] ^ lz[7:0] ^ lz[15:8];
            pkt[0] <= 8'hAA;
            pkt[1] <= lx[7:0];
            pkt[2] <= lx[15:8];
            pkt[3] <= ly[7:0];
            pkt[4] <= ly[15:8];
            pkt[5] <= lz[7:0];
            pkt[6] <= lz[15:8];
            pkt[7] <= csum;
            byte_idx <= 0;
            ps_state <= PS_SEND;
        end

        // Load byte and fire uart_start (1 clock pulse)
        PS_SEND: begin
            uart_byte  <= pkt[byte_idx];
            uart_start <= 1;
            ps_state   <= PS_WAIT_HI;
        end

        // Wait for UART to accept the byte (busy goes high)
        PS_WAIT_HI: begin
            if (uart_busy)
                ps_state <= PS_WAIT_LO;
        end

        // Wait for byte to finish transmitting (busy goes low)
        PS_WAIT_LO: begin
            if (!uart_busy) begin
                if (byte_idx == 4'd7)
                    ps_state <= PS_IDLE;
                else begin
                    byte_idx <= byte_idx + 1;
                    ps_state <= PS_SEND;
                end
            end
        end

        default: ps_state <= PS_IDLE;

        endcase
    end
end

endmodule
