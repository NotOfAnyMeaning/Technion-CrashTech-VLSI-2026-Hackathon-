// =============================================================
// adxl345_spi.v  –  ADXL345 SPI Master for DE10-Lite
//
// SPI Mode 3 (CPOL=1, CPHA=1), clock = 1 MHz (50-cycle / half-period).
// Init sequence: POWER_CTL=0x08, DATA_FORMAT=0x00
// Then continuously burst-reads 6 bytes from register 0x32.
// =============================================================
module adxl345_spi (
    input  wire        clk,
    input  wire        rst_n,

    output reg         spi_sclk,
    output reg         spi_cs_n,
    output reg         spi_mosi,
    input  wire        spi_miso,

    output reg [15:0]  accel_x,
    output reg [15:0]  accel_y,
    output reg [15:0]  accel_z,
    output reg         data_valid
);

// ---- 1 MHz SPI tick: one pulse per 25 system clocks ----
localparam CLK_DIV = 25;
reg [4:0]  clk_cnt;
reg        tick;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt <= 0; tick <= 0;
    end else if (clk_cnt == CLK_DIV-1) begin
        clk_cnt <= 0; tick <= 1;
    end else begin
        clk_cnt <= clk_cnt + 1; tick <= 0;
    end
end

// ---- State definitions ----
localparam [3:0]
    S_STARTUP   = 4'd0,
    S_CFG1_PRE  = 4'd1,
    S_CFG1_TX   = 4'd2,
    S_CFG1_POST = 4'd3,
    S_CFG2_PRE  = 4'd4,
    S_CFG2_TX   = 4'd5,
    S_CFG2_POST = 4'd6,
    S_RD_PRE    = 4'd7,
    S_RD_CMD    = 4'd8,
    S_RD_DATA   = 4'd9,
    S_COMMIT    = 4'd10,
    S_RD_POST   = 4'd11;

reg [3:0]  state;
reg [9:0]  wait_cnt;

reg [15:0] shift_tx;
reg [7:0]  shift_rx;
reg [3:0]  bit_cnt;
reg        phase;

reg [7:0]  raw [0:5];
reg [2:0]  byte_idx;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        spi_sclk   <= 1;
        spi_cs_n   <= 1;
        spi_mosi   <= 0;
        accel_x    <= 0;
        accel_y    <= 0;
        accel_z    <= 0;
        data_valid <= 0;
        state      <= S_STARTUP;
        wait_cnt   <= 0;
        bit_cnt    <= 0;
        phase      <= 0;
        byte_idx   <= 0;
        shift_tx   <= 0;
        shift_rx   <= 0;
    end else begin
        data_valid <= 0;

        case (state)

        S_STARTUP: begin
            spi_cs_n <= 1; spi_sclk <= 1;
            if (tick) begin
                wait_cnt <= wait_cnt + 1;
                if (wait_cnt == 10'd999) begin
                    wait_cnt <= 0;
                    state    <= S_CFG1_PRE;
                end
            end
        end

        // Write POWER_CTL (0x2D) = 0x08
        S_CFG1_PRE: begin
            shift_tx <= 16'h2D08;
            bit_cnt  <= 0;
            phase    <= 0;
            spi_cs_n <= 0;
            state    <= S_CFG1_TX;
        end

        S_CFG1_TX: if (tick) begin
            if (phase == 0) begin
                spi_sclk  <= 0;
                spi_mosi  <= shift_tx[15];
                shift_tx  <= {shift_tx[14:0], 1'b0};
                phase     <= 1;
            end else begin
                spi_sclk <= 1;
                bit_cnt  <= bit_cnt + 1;
                phase    <= 0;
                if (bit_cnt == 4'd15) begin
                    spi_cs_n <= 1;
                    state    <= S_CFG1_POST;
                    wait_cnt <= 0;
                end
            end
        end

        S_CFG1_POST: if (tick) begin
            wait_cnt <= wait_cnt + 1;
            if (wait_cnt == 10'd49) begin
                wait_cnt <= 0;
                state    <= S_CFG2_PRE;
            end
        end

        // Write DATA_FORMAT (0x31) = 0x00
        S_CFG2_PRE: begin
            shift_tx <= 16'h3100;
            bit_cnt  <= 0;
            phase    <= 0;
            spi_cs_n <= 0;
            state    <= S_CFG2_TX;
        end

        S_CFG2_TX: if (tick) begin
            if (phase == 0) begin
                spi_sclk  <= 0;
                spi_mosi  <= shift_tx[15];
                shift_tx  <= {shift_tx[14:0], 1'b0};
                phase     <= 1;
            end else begin
                spi_sclk <= 1;
                bit_cnt  <= bit_cnt + 1;
                phase    <= 0;
                if (bit_cnt == 4'd15) begin
                    spi_cs_n <= 1;
                    state    <= S_CFG2_POST;
                    wait_cnt <= 0;
                end
            end
        end

        S_CFG2_POST: if (tick) begin
            wait_cnt <= wait_cnt + 1;
            if (wait_cnt == 10'd49) begin
                wait_cnt <= 0;
                state    <= S_RD_PRE;
            end
        end

        // Burst read: cmd byte 0xF2 (R=1,MB=1,addr=0x32), then 6 data bytes
        S_RD_PRE: begin
            shift_tx <= {8'hF2, 8'h00};
            bit_cnt  <= 0;
            phase    <= 0;
            byte_idx <= 0;
            spi_cs_n <= 0;
            state    <= S_RD_CMD;
        end

        // Send 8-bit address byte
        S_RD_CMD: if (tick) begin
            if (phase == 0) begin
                spi_sclk  <= 0;
                spi_mosi  <= shift_tx[15];
                shift_tx  <= {shift_tx[14:0], 1'b0};
                phase     <= 1;
            end else begin
                spi_sclk <= 1;
                bit_cnt  <= bit_cnt + 1;
                phase    <= 0;
                if (bit_cnt == 4'd7) begin
                    bit_cnt  <= 0;
                    shift_rx <= 8'h00;
                    state    <= S_RD_DATA;
                end
            end
        end

        // Receive 6 data bytes
        S_RD_DATA: if (tick) begin
            if (phase == 0) begin
                spi_sclk <= 0;
                spi_mosi <= 0;
                phase    <= 1;
            end else begin
                spi_sclk <= 1;
                shift_rx <= {shift_rx[6:0], spi_miso};
                bit_cnt  <= bit_cnt + 1;
                phase    <= 0;
                if (bit_cnt == 4'd7) begin
                    raw[byte_idx] <= {shift_rx[6:0], spi_miso};
                    bit_cnt       <= 0;
                    shift_rx      <= 8'h00;
                    if (byte_idx == 3'd5) begin
                        spi_cs_n <= 1;
                        state    <= S_COMMIT;
                    end else begin
                        byte_idx <= byte_idx + 1;
                    end
                end
            end
        end

        S_COMMIT: begin
            accel_x    <= {raw[1], raw[0]};
            accel_y    <= {raw[3], raw[2]};
            accel_z    <= {raw[5], raw[4]};
            data_valid <= 1;
            state      <= S_RD_POST;
            wait_cnt   <= 0;
        end

        // ~250 µs inter-read gap
        S_RD_POST: if (tick) begin
            wait_cnt <= wait_cnt + 1;
            if (wait_cnt == 10'd249) begin
                wait_cnt <= 0;
                state    <= S_RD_PRE;
            end
        end

        default: state <= S_STARTUP;

        endcase
    end
end

endmodule
