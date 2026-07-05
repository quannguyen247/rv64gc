`timescale 1ns / 1ps

module fpu64_sqrt (
    input wire [63:0] rs1,
    input wire is_double,
    output reg [63:0] out,
    output reg [4:0] fflags
);

    wire [31:0] s1_bits = rs1[31:0];

    shortreal s1_f;
    shortreal res_f;

    real d1_f;
    real res_d;

    always @(*) begin
        s1_f = $bitstoshortreal(s1_bits);
        d1_f = $bitstoreal(rs1);
    end

    always @(*) begin
        fflags = 5'd0;
        if (is_double) begin
            if (d1_f < 0.0) begin
                fflags[4] = 1'b1;
                res_d = 0.0;
            end else begin
                res_d = $sqrt(d1_f);
            end
            out = $realtobits(res_d);
        end else begin
            if (s1_f < 0.0) begin
                fflags[4] = 1'b1;
                res_f = 0.0;
            end else begin
                res_f = $sqrt(s1_f);
            end
            out = {32'hFFFFFFFF, $shortrealtobits(res_f)};
        end
    end

endmodule
