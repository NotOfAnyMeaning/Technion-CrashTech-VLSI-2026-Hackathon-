// Seven-Segment Decimal Decoder — active-low outputs
// seg = {DP, G, F, E, D, C, B, A}  (0 = ON)
// Displays decimal digits 0-9; shows blank (all off) for values 10-15

module seven_segment (
    input  [3:0] value,
    output reg [7:0] segments
);
    always @(*) begin
        case (value)
            4'd0: segments = 8'b11000000;  // 0
            4'd1: segments = 8'b11111001;  // 1
            4'd2: segments = 8'b10100100;  // 2
            4'd3: segments = 8'b10110000;  // 3
            4'd4: segments = 8'b10011001;  // 4
            4'd5: segments = 8'b10010010;  // 5
            4'd6: segments = 8'b10000010;  // 6
            4'd7: segments = 8'b11111000;  // 7
            4'd8: segments = 8'b10000000;  // 8
            4'd9: segments = 8'b10010000;  // 9
            default: segments = 8'b11111111;  // blank
        endcase
    end
endmodule
