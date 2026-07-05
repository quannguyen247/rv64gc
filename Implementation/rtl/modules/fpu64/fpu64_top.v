`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_top (
    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire [63:0] rs3,
    input wire [3:0] op,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [4:0] rs2_val,
    input wire is_double,
    output reg [63:0] out_fp,
    output reg [63:0] out_int,
    output reg we_gpr,
    output reg we_fpr,
    output reg [4:0] fflags
);

    wire [63:0] addsub_out;
    fpu64_addsub u_addsub (
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .is_sub(op == `F_SUB),
        .out(addsub_out)
    );

    wire [63:0] mul_out;
    fpu64_mul u_mul (
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .out(mul_out)
    );

    wire [63:0] div_out;
    wire [4:0] div_fflags;
    fpu64_div u_div (
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .out(div_out),
        .fflags(div_fflags)
    );

    wire [63:0] sqrt_out;
    wire [4:0] sqrt_fflags;
    fpu64_sqrt u_sqrt (
        .rs1(rs1),
        .is_double(is_double),
        .out(sqrt_out),
        .fflags(sqrt_fflags)
    );

    wire [63:0] compare_out;
    fpu64_compare u_compare (
        .rs1(rs1),
        .rs2(rs2),
        .funct3(funct3),
        .is_double(is_double),
        .out(compare_out)
    );

    wire [63:0] classify_out;
    fpu64_classify u_classify (
        .rs1(rs1),
        .is_double(is_double),
        .out(classify_out)
    );

    wire [63:0] convert_fp_out;
    wire [63:0] convert_int_out;
    wire convert_we_gpr;
    wire convert_we_fpr;
    fpu64_convert u_convert (
        .rs1(rs1),
        .rs2_val(rs2_val),
        .funct7(funct7),
        .out_fp(convert_fp_out),
        .out_int(convert_int_out),
        .we_gpr(convert_we_gpr),
        .we_fpr(convert_we_fpr)
    );

    wire [31:0] s1_bits = rs1[31:0];
    wire [31:0] s2_bits = rs2[31:0];
    shortreal s1_f;
    shortreal s2_f;
    shortreal minmax_res_f;
    real d1_f;
    real d2_f;
    real minmax_res_d;

    always @(*) begin
        s1_f = $bitstoshortreal(s1_bits);
        s2_f = $bitstoshortreal(s2_bits);
        d1_f = $bitstoreal(rs1);
        d2_f = $bitstoreal(rs2);
    end

    always @(*) begin
        out_fp = 64'd0;
        out_int = 64'd0;
        we_gpr = 1'b0;
        we_fpr = 1'b0;
        fflags = 5'd0;

        case (op)
            `F_ADD, `F_SUB: begin
                we_fpr = 1'b1;
                out_fp = addsub_out;
            end
            `F_MUL: begin
                we_fpr = 1'b1;
                out_fp = mul_out;
            end
            `F_DIV: begin
                we_fpr = 1'b1;
                out_fp = div_out;
                fflags = div_fflags;
            end
            `F_SQRT: begin
                we_fpr = 1'b1;
                out_fp = sqrt_out;
                fflags = sqrt_fflags;
            end
            `F_SGNJ: begin
                we_fpr = 1'b1;
                if (is_double) begin
                    case (funct3)
                        3'b000: out_fp = {rs2[63], rs1[62:0]};
                        3'b001: out_fp = {~rs2[63], rs1[62:0]};
                        3'b010: out_fp = {rs1[63] ^ rs2[63], rs1[62:0]};
                        default: out_fp = rs1;
                    endcase
                end else begin
                    case (funct3)
                        3'b000: out_fp = {32'hFFFFFFFF, rs2[31], rs1[30:0]};
                        3'b001: out_fp = {32'hFFFFFFFF, ~rs2[31], rs1[30:0]};
                        3'b010: out_fp = {32'hFFFFFFFF, rs1[31] ^ rs2[31], rs1[30:0]};
                        default: out_fp = rs1;
                    endcase
                end
            end
            `F_MINMAX: begin
                we_fpr = 1'b1;
                if (is_double) begin
                    if (funct3 == 3'b000) begin
                        minmax_res_d = (d1_f < d2_f) ? d1_f : d2_f;
                    end else begin
                        minmax_res_d = (d1_f > d2_f) ? d1_f : d2_f;
                    end
                    out_fp = $realtobits(minmax_res_d);
                end else begin
                    if (funct3 == 3'b000) begin
                        minmax_res_f = (s1_f < s2_f) ? s1_f : s2_f;
                    end else begin
                        minmax_res_f = (s1_f > s2_f) ? s1_f : s2_f;
                    end
                    out_fp = {32'hFFFFFFFF, $shortrealtobits(minmax_res_f)};
                end
            end
            `F_CVT: begin
                we_gpr = convert_we_gpr;
                we_fpr = convert_we_fpr;
                out_fp = convert_fp_out;
                out_int = convert_int_out;
            end
            `F_COMP: begin
                we_gpr = 1'b1;
                out_int = compare_out;
            end
            `F_CLASS: begin
                we_gpr = 1'b1;
                out_int = classify_out;
            end
            `F_MVTX: begin
                we_gpr = 1'b1;
                if (is_double) begin
                    out_int = rs1;
                end else begin
                    out_int = {{32{rs1[31]}}, rs1[31:0]};
                end
            end
            `F_MVXT: begin
                we_fpr = 1'b1;
                if (is_double) begin
                    out_fp = rs1;
                end else begin
                    out_fp = {32'hFFFFFFFF, rs1[31:0]};
                end
            end
            default: begin
            end
        endcase
    end

endmodule
