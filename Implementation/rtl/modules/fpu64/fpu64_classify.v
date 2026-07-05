`timescale 1ns / 1ps

module fpu64_classify (
    input wire [63:0] rs1,
    input wire is_double,
    output reg [63:0] out
);

    wire [31:0] s1_bits = rs1[31:0];

    shortreal s1_f;
    real d1_f;

    always @(*) begin
        s1_f = $bitstoshortreal(s1_bits);
        d1_f = $bitstoreal(rs1);
    end

    always @(*) begin
        out = 64'd0;
        if (is_double) begin
            if (d1_f < 0.0) begin
                out = 64'h004;
            end else if (d1_f > 0.0) begin
                out = 64'h080;
            end else if (d1_f == 0.0) begin
                out = 64'h010;
            end else begin
                out = 64'h100;
            end
        end else begin
            if (s1_f < 0.0) begin
                out = 64'h004;
            end else if (s1_f > 0.0) begin
                out = 64'h080;
            end else if (s1_f == 0.0) begin
                out = 64'h010;
            end else begin
                out = 64'h100;
            end
        end
    end

endmodule
