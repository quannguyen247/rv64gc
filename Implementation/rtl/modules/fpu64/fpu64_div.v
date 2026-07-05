`timescale 1ns / 1ps

module fpu64_div (
    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire is_double,
    output reg [63:0] out,
    output reg [4:0] fflags
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
        fflags = 5'd0;
        if (is_double) begin
            if (d2_f == 0.0) begin
                fflags[3] = 1'b1;
                res_d = 0.0;
            end else begin
                res_d = d1_f / d2_f;
            end
            out = $realtobits(res_d);
        end else begin
            if (s2_f == 0.0) begin
                fflags[3] = 1'b1;
                res_f = 0.0;
            end else begin
                res_f = s1_f / s2_f;
            end
            out = {32'hFFFFFFFF, $shortrealtobits(res_f)};
        end
    end

endmodule
