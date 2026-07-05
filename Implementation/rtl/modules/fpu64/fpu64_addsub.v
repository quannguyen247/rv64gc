`timescale 1ns / 1ps

module fpu64_addsub (
    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire is_double,
    input wire is_sub,
    output reg [63:0] out
);

    wire [31:0] s1_bits = rs1[31:0];
    wire [31:0] s2_bits = rs2[31:0];

    shortreal s1_f;
    shortreal s2_f;
    shortreal res_f;

    real d1_f;
    real d2_f;
    real res_d;

    always @(*) begin
        s1_f = $bitstoshortreal(s1_bits);
        s2_f = $bitstoshortreal(s2_bits);
        d1_f = $bitstoreal(rs1);
        d2_f = $bitstoreal(rs2);
    end

    always @(*) begin
        if (is_double) begin
            res_d = is_sub ? (d1_f - d2_f) : (d1_f + d2_f);
            out = $realtobits(res_d);
        end else begin
            res_f = is_sub ? (s1_f - s2_f) : (s1_f + s2_f);
            out = {32'hFFFFFFFF, $shortrealtobits(res_f)};
        end
    end

endmodule
