`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_convert_i2f (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire [63:0] rs1,
    input wire [4:0] rs2_val,
    input wire is_double,
    input wire [2:0] rm,
    output reg valid_out,
    input wire ready_out,
    output reg [63:0] result,
    output reg [4:0] fflags
);

    reg pre_sign;
    reg [63:0] pre_absolute;

    reg valid_s1;
    reg sign_s1;
    reg [63:0] absolute_s1;
    reg is_double_s1;
    reg [2:0] rm_s1;

    reg [63:0] pre_normalized;
    reg [5:0] pre_leading_zero_count;

    reg valid_s2;
    reg sign_s2;
    reg zero_s2;
    reg [63:0] normalized_s2;
    reg [5:0] leading_zero_count_s2;
    reg is_double_s2;
    reg [2:0] rm_s2;

    wire ready_s3 = !valid_out || ready_out;
    wire ready_s2 = !valid_s2 || ready_s3;
    wire ready_s1 = !valid_s1 || ready_s2;
    assign ready_in = ready_s1;

    wire [6:0] exponent_s2 = 7'd63 - {1'b0, leading_zero_count_s2};
    wire [52:0] dp_significand_s2 = normalized_s2[63:11];
    wire dp_guard_s2 = normalized_s2[10];
    wire dp_round_s2 = normalized_s2[9];
    wire dp_sticky_s2 = (normalized_s2[8:0] != 9'd0);
    wire dp_inexact_s2 = dp_guard_s2 || dp_round_s2 || dp_sticky_s2;
    reg dp_round_up_s2;
    wire [53:0] dp_rounded_s2 = {1'b0, dp_significand_s2} +
                                     (dp_round_up_s2 ? 54'd1 : 54'd0);
    wire dp_carry_s2 = dp_rounded_s2[53];
    wire [52:0] dp_final_significand_s2 = dp_carry_s2 ?
                                                 dp_rounded_s2[53:1] :
                                                 dp_rounded_s2[52:0];
    wire [11:0] dp_biased_exponent_s2 = {5'd0, exponent_s2} +
                                            12'd1023 +
                                            (dp_carry_s2 ? 12'd1 : 12'd0);

    wire [23:0] sp_significand_s2 = normalized_s2[63:40];
    wire sp_guard_s2 = normalized_s2[39];
    wire sp_round_s2 = normalized_s2[38];
    wire sp_sticky_s2 = (normalized_s2[37:0] != 38'd0);
    wire sp_inexact_s2 = sp_guard_s2 || sp_round_s2 || sp_sticky_s2;
    reg sp_round_up_s2;
    wire [24:0] sp_rounded_s2 = {1'b0, sp_significand_s2} +
                                     (sp_round_up_s2 ? 25'd1 : 25'd0);
    wire sp_carry_s2 = sp_rounded_s2[24];
    wire [23:0] sp_final_significand_s2 = sp_carry_s2 ?
                                                 sp_rounded_s2[24:1] :
                                                 sp_rounded_s2[23:0];
    wire [8:0] sp_biased_exponent_s2 = {2'd0, exponent_s2} +
                                           9'd127 +
                                           (sp_carry_s2 ? 9'd1 : 9'd0);

    always @(*) begin
        pre_sign = 1'b0;
        pre_absolute = 64'd0;
        case (rs2_val)
            5'd0: begin
                pre_sign = rs1[31];
                pre_absolute = pre_sign ?
                               -{{32{rs1[31]}}, rs1[31:0]} :
                               {32'd0, rs1[31:0]};
            end
            5'd1: begin
                pre_absolute = {32'd0, rs1[31:0]};
            end
            5'd2: begin
                pre_sign = rs1[63];
                pre_absolute = pre_sign ? -rs1 : rs1;
            end
            5'd3: begin
                pre_absolute = rs1;
            end
            default: begin
            end
        endcase
    end

    always @(*) begin
        pre_normalized = absolute_s1;
        pre_leading_zero_count = 6'd0;
        if (absolute_s1 != 64'd0) begin
            if (pre_normalized[63:32] == 32'd0) begin
                pre_normalized = pre_normalized << 32;
                pre_leading_zero_count = pre_leading_zero_count + 6'd32;
            end
            if (pre_normalized[63:48] == 16'd0) begin
                pre_normalized = pre_normalized << 16;
                pre_leading_zero_count = pre_leading_zero_count + 6'd16;
            end
            if (pre_normalized[63:56] == 8'd0) begin
                pre_normalized = pre_normalized << 8;
                pre_leading_zero_count = pre_leading_zero_count + 6'd8;
            end
            if (pre_normalized[63:60] == 4'd0) begin
                pre_normalized = pre_normalized << 4;
                pre_leading_zero_count = pre_leading_zero_count + 6'd4;
            end
            if (pre_normalized[63:62] == 2'd0) begin
                pre_normalized = pre_normalized << 2;
                pre_leading_zero_count = pre_leading_zero_count + 6'd2;
            end
            if (!pre_normalized[63]) begin
                pre_normalized = pre_normalized << 1;
                pre_leading_zero_count = pre_leading_zero_count + 6'd1;
            end
        end
    end

    always @(*) begin
        dp_round_up_s2 = 1'b0;
        case (rm_s2)
            `RM_RNE: dp_round_up_s2 = dp_guard_s2 &&
                                      (dp_round_s2 || dp_sticky_s2 ||
                                       dp_significand_s2[0]);
            `RM_RTZ: dp_round_up_s2 = 1'b0;
            `RM_RDN: dp_round_up_s2 = sign_s2 && dp_inexact_s2;
            `RM_RUP: dp_round_up_s2 = !sign_s2 && dp_inexact_s2;
            `RM_RMM: dp_round_up_s2 = dp_guard_s2;
            default: dp_round_up_s2 = 1'b0;
        endcase
    end

    always @(*) begin
        sp_round_up_s2 = 1'b0;
        case (rm_s2)
            `RM_RNE: sp_round_up_s2 = sp_guard_s2 &&
                                      (sp_round_s2 || sp_sticky_s2 ||
                                       sp_significand_s2[0]);
            `RM_RTZ: sp_round_up_s2 = 1'b0;
            `RM_RDN: sp_round_up_s2 = sign_s2 && sp_inexact_s2;
            `RM_RUP: sp_round_up_s2 = !sign_s2 && sp_inexact_s2;
            `RM_RMM: sp_round_up_s2 = sp_guard_s2;
            default: sp_round_up_s2 = 1'b0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s1 <= 1'b0;
            sign_s1 <= 1'b0;
            absolute_s1 <= 64'd0;
            is_double_s1 <= 1'b0;
            rm_s1 <= 3'd0;
        end else if (ready_s1) begin
            valid_s1 <= valid_in;
            if (valid_in) begin
                sign_s1 <= pre_sign;
                absolute_s1 <= pre_absolute;
                is_double_s1 <= is_double;
                rm_s1 <= rm;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s2 <= 1'b0;
            sign_s2 <= 1'b0;
            zero_s2 <= 1'b0;
            normalized_s2 <= 64'd0;
            leading_zero_count_s2 <= 6'd0;
            is_double_s2 <= 1'b0;
            rm_s2 <= 3'd0;
        end else if (ready_s2) begin
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                sign_s2 <= sign_s1;
                zero_s2 <= (absolute_s1 == 64'd0);
                normalized_s2 <= pre_normalized;
                leading_zero_count_s2 <= pre_leading_zero_count;
                is_double_s2 <= is_double_s1;
                rm_s2 <= rm_s1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            result <= 64'd0;
            fflags <= 5'd0;
        end else if (ready_s3) begin
            valid_out <= valid_s2;
            if (valid_s2) begin
                result <= 64'd0;
                fflags <= 5'd0;
                if (zero_s2) begin
                    result <= is_double_s2 ?
                              {sign_s2, 11'd0, 52'd0} :
                              {32'hFFFFFFFF, sign_s2, 8'd0, 23'd0};
                end else if (is_double_s2) begin
                    result <= {sign_s2, dp_biased_exponent_s2[10:0],
                               dp_final_significand_s2[51:0]};
                    fflags[`FF_NX] <= dp_inexact_s2;
                end else begin
                    result <= {32'hFFFFFFFF, sign_s2,
                               sp_biased_exponent_s2[7:0],
                               sp_final_significand_s2[22:0]};
                    fflags[`FF_NX] <= sp_inexact_s2;
                end
            end
        end
    end

endmodule
