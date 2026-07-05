`timescale 1ns / 1ps

module fpu64_compare (
    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire [2:0] funct3,
    input wire is_double,
    output reg [63:0] out
);

    wire [31:0] s1_bits = rs1[31:0];
    wire [31:0] s2_bits = rs2[31:0];

    shortreal s1_f;
    shortreal s2_f;

    real d1_f;
    real d2_f;

    always @(*) begin
        s1_f = $bitstoshortreal(s1_bits);
        s2_f = $bitstoshortreal(s2_bits);
        d1_f = $bitstoreal(rs1);
        d2_f = $bitstoreal(rs2);
    end

    always @(*) begin
        out = 64'd0;
        if (is_double) begin
            case (funct3)
                3'b010: out = (d1_f == d2_f) ? 64'd1 : 64'd0;
                3'b001: out = (d1_f < d2_f) ? 64'd1 : 64'd0;
                3'b000: out = (d1_f <= d2_f) ? 64'd1 : 64'd0;
                default: out = 64'd0;
            endcase
        end else begin
            case (funct3)
                3'b010: out = (s1_f == s2_f) ? 64'd1 : 64'd0;
                3'b001: out = (s1_f < s2_f) ? 64'd1 : 64'd0;
                3'b000: out = (s1_f <= s2_f) ? 64'd1 : 64'd0;
                default: out = 64'd0;
            endcase
        end
    end

endmodule
