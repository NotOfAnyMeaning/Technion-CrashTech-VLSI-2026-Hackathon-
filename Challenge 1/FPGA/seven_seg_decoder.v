// ============================================================
// seven_seg_decoder.v — BCD to 7-segment (active-low), with DP
// CrashTech VLSI-2026 — Challenge 1: Volt-Meter
// ============================================================
// seg[7:0] = { DP, G, F, E, D, C, B, A }  (0 = segment ON)
// blank=1 forces all segments OFF (8'hFF).
// dp=1 forces the decimal-point segment ON (seg[7] = 0).
// ============================================================

module seven_seg_decoder (
    input      [3:0] digit,  // BCD value 0–9
    input            blank,  // 1 = turn all segments off
    input            dp,     // 1 = illuminate decimal point
    output reg [7:0] seg     // active-low 7-segment + DP
);

    always @(*) begin
        if (blank) begin
            seg = 8'hFF;  // all off
        end else begin
            case (digit)
                4'd0: seg = 8'hC0;  // 1100_0000
                4'd1: seg = 8'hF9;  // 1111_1001
                4'd2: seg = 8'hA4;  // 1010_0100
                4'd3: seg = 8'hB0;  // 1011_0000
                4'd4: seg = 8'h99;  // 1001_1001
                4'd5: seg = 8'h92;  // 1001_0010
                4'd6: seg = 8'h82;  // 1000_0010
                4'd7: seg = 8'hF8;  // 1111_1000
                4'd8: seg = 8'h80;  // 1000_0000
                4'd9: seg = 8'h90;  // 1001_0000
                default: seg = 8'hFF;  // blank for out-of-range
            endcase
            // Overlay the decimal point (bit 7, active-low)
            if (dp) seg[7] = 1'b0;
        end
    end

endmodule
