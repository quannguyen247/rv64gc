`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_convert_f2f (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire [63:0] rs1,
    input wire to_double,
    input wire [2:0] rm,
    output reg valid_out,
    input wire ready_out,
    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire sp_sign = rs1[31];
    wire [7:0] sp_exp = rs1[30:23];
    wire [22:0] sp_frac = rs1[22:0];
    wire sp_nan = (sp_exp == 8'hFF) && (sp_frac != 23'd0);
    wire sp_snan = sp_nan && !sp_frac[22];
    wire sp_inf = (sp_exp == 8'hFF) && (sp_frac == 23'd0);
    wire sp_zero = (sp_exp == 8'd0) && (sp_frac == 23'd0);
    wire dp_sign = rs1[63];
    wire [10:0] dp_exp = rs1[62:52];
    wire [51:0] dp_frac = rs1[51:0];
    wire dp_nan = (dp_exp == 11'h7FF) && (dp_frac != 52'd0);
    wire dp_snan = dp_nan && !dp_frac[51];
    wire dp_inf = (dp_exp == 11'h7FF) && (dp_frac == 52'd0);
    wire dp_zero = (dp_exp == 11'd0) && (dp_frac == 52'd0);
    reg [23:0] sp_significand;
    reg guard_bit;
    reg round_bit;
    reg sticky_bit;
    reg round_up;
    reg [24:0] rounded_significand;
    reg [7:0] result_sp_exp;
    reg [22:0] result_sp_frac;
    reg [11:0] converted_exp;

    reg [63:0] result_comb;
    reg [4:0] fflags_comb;
    reg valid_s1;
    reg [63:0] result_s1;
    reg [4:0] fflags_s1;
    reg valid_s2;
    reg [63:0] result_s2;
    reg [4:0] fflags_s2;

    wire ready_s3 = !valid_out || ready_out;
    wire ready_s2 = !valid_s2 || ready_s3;
    wire ready_s1 = !valid_s1 || ready_s2;
    assign ready_in = ready_s1;

    always @(*) begin
        result_comb = 64'd0;
        fflags_comb = 5'd0;
        if (to_double) begin
            if (sp_nan) begin
                result_comb = 64'h7FF8000000000000;
                if (sp_snan) fflags_comb[`FF_NV] = 1'b1;
            end else if (sp_inf) begin
                result_comb = {sp_sign, 11'h7FF, 52'd0};
            end else if (sp_zero) begin
                result_comb = {sp_sign, 11'd0, 52'd0};
            end else begin
                converted_exp = {4'd0, sp_exp} - 12'd127 + 12'd1023;
                result_comb = {sp_sign, converted_exp[10:0], sp_frac, 29'd0};
            end
        end else begin
            if (dp_nan) begin
                result_comb = 64'hFFFFFFFF_7FC00000;
                if (dp_snan) fflags_comb[`FF_NV] = 1'b1;
            end else if (dp_inf) begin
                result_comb = {32'hFFFFFFFF, dp_sign, 8'hFF, 23'd0};
            end else if (dp_zero) begin
                result_comb = {32'hFFFFFFFF, dp_sign, 8'd0, 23'd0};
            end else begin
                sp_significand = {(dp_exp == 11'd0) ? 1'b0 : 1'b1, dp_frac[51:29]};
                guard_bit = dp_frac[28];
                round_bit = dp_frac[27];
                sticky_bit = (dp_frac[26:0] != 27'd0);
                round_up = 1'b0;
                case (rm)
                    `RM_RNE: round_up = guard_bit && (round_bit || sticky_bit || sp_significand[0]);
                    `RM_RTZ: round_up = 1'b0;
                    `RM_RDN: round_up = dp_sign && (guard_bit || round_bit || sticky_bit);
                    `RM_RUP: round_up = !dp_sign && (guard_bit || round_bit || sticky_bit);
                    `RM_RMM: round_up = guard_bit;
                    default: round_up = 1'b0;
                endcase
                rounded_significand = sp_significand + (round_up ? 25'd1 : 25'd0);
                converted_exp = {1'b0, dp_exp} - 12'd1023 + (rounded_significand[24] ? 12'd1 : 12'd0);
                if (rounded_significand[24]) rounded_significand = rounded_significand >> 1;
                if ($signed(converted_exp) >= $signed(12'd128)) begin
                    result_comb = {32'hFFFFFFFF, dp_sign, 8'hFF, 23'd0};
                    fflags_comb[`FF_OF] = 1'b1;
                    fflags_comb[`FF_NX] = 1'b1;
                end else if ($signed(converted_exp) < -12'sd126) begin
                    result_comb = {32'hFFFFFFFF, dp_sign, 8'd0, 23'd0};
                    fflags_comb[`FF_UF] = 1'b1;
                    fflags_comb[`FF_NX] = 1'b1;
                end else begin
                    result_sp_exp = converted_exp[7:0] + 8'd127;
                    result_sp_frac = rounded_significand[22:0];
                    result_comb = {32'hFFFFFFFF, dp_sign, result_sp_exp, result_sp_frac};
                    if (guard_bit || round_bit || sticky_bit) fflags_comb[`FF_NX] = 1'b1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s1 <= 1'b0;
            result_s1 <= 64'd0;
            fflags_s1 <= 5'd0;
        end else if (ready_s1) begin
            valid_s1 <= valid_in;
            if (valid_in) begin
                result_s1 <= result_comb;
                fflags_s1 <= fflags_comb;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s2 <= 1'b0;
            result_s2 <= 64'd0;
            fflags_s2 <= 5'd0;
        end else if (ready_s2) begin
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                result_s2 <= result_s1;
                fflags_s2 <= fflags_s1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            result <= 64'd0;
            fflags <= 5'd0;
        end else if (ready_s3) begin
            valid_out <= valid_s2;
            if (valid_s2) begin
                result <= result_s2;
                fflags <= fflags_s2;
            end
        end
    end

endmodule
