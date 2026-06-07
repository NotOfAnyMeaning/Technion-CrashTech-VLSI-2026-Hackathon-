// ============================================================
// seven_seg_decoder.sv — BCD → 7-segment, active-low, with DP
// CrashTech VLSI-2026 — Challenge 5: FPGA Volt-Meter
// ============================================================
// Segment bit mapping (matches DE10-Lite common-anode displays):
//   seg[7:0] = { DP, G, F, E, D, C, B, A }
//   0 = segment ON, 1 = segment OFF (active-low drivers)
//
// blank=1 drives all segments OFF (8'hFF) regardless of digit.
// dp=1 forces the decimal-point segment ON (seg[7] = 0).
// ============================================================

module seven_seg_decoder (
    input  logic [3:0] digit,   // BCD value 0–9
    input  logic       blank,   // 1 → all segments off
    input  logic       dp,      // 1 → decimal point on
    output logic [7:0] seg      // {DP,G,F,E,D,C,B,A}, active-low
);

    always_comb begin
        if (blank) begin
            seg = 8'hFF;    // all segments off
        end else begin
            unique case (digit)
                4'd0: seg = 8'hC0;  // 1100_0000  (g off, rest on)
                4'd1: seg = 8'hF9;  // 1111_1001
                4'd2: seg = 8'hA4;  // 1010_0100
                4'd3: seg = 8'hB0;  // 1011_0000
                4'd4: seg = 8'h99;  // 1001_1001
                4'd5: seg = 8'h92;  // 1001_0010
                4'd6: seg = 8'h82;  // 1000_0010
                4'd7: seg = 8'hF8;  // 1111_1000
                4'd8: seg = 8'h80;  // 1000_0000
                4'd9: seg = 8'h90;  // 1001_0000
                default: seg = 8'hFF;   // out-of-range → blank
            endcase
            // Overlay decimal point (bit 7 active-low)
            if (dp) seg[7] = 1'b0;
        end
    end

endmodule
