`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_convert_f2i (
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

    wire sp_sign = rs1[31];
    wire [7:0] sp_exp = rs1[30:23];
    wire [22:0] sp_frac = rs1[22:0];
    wire sp_nan = (sp_exp == 8'hFF) && (sp_frac != 23'd0);
    wire sp_inf = (sp_exp == 8'hFF) && (sp_frac == 23'd0);
    wire sp_zero = (sp_exp == 8'd0) && (sp_frac == 23'd0);
    wire dp_sign = rs1[63];
    wire [10:0] dp_exp = rs1[62:52];
    wire [51:0] dp_frac = rs1[51:0];
    wire dp_nan = (dp_exp == 11'h7FF) && (dp_frac != 52'd0);
    wire dp_inf = (dp_exp == 11'h7FF) && (dp_frac == 52'd0);
    wire dp_zero = (dp_exp == 11'd0) && (dp_frac == 52'd0);

    reg pre_special;
    reg [63:0] pre_special_result;
    reg [4:0] pre_special_flags;
    reg pre_sign;
    reg pre_overflow;
    reg [63:0] pre_shifted;
    reg pre_round_up;
    reg pre_inexact;
    reg [11:0] pre_exponent;
    reg [63:0] pre_temp;
    reg [63:0] pre_remainder;
    reg pre_guard;
    reg pre_round;
    reg pre_sticky;

    reg valid_s1;
    reg special_s1;
    reg [63:0] special_result_s1;
    reg [4:0] special_flags_s1;
    reg sign_s1;
    reg overflow_s1;
    reg [63:0] shifted_s1;
    reg round_up_s1;
    reg inexact_s1;
    reg [4:0] rs2_val_s1;

    reg valid_s2;
    reg special_s2;
    reg [63:0] special_result_s2;
    reg [4:0] special_flags_s2;
    reg sign_s2;
    reg overflow_s2;
    reg [64:0] rounded_s2;
    reg inexact_s2;
    reg [4:0] rs2_val_s2;

    wire ready_s3 = !valid_out || ready_out;
    wire ready_s2 = !valid_s2 || ready_s3;
    wire ready_s1 = !valid_s1 || ready_s2;
    assign ready_in = ready_s1;

    wire rounded_nonzero_s2 = (rounded_s2 != 65'd0);
    wire invalid_w_s2 = overflow_s2 ||
                        (rounded_s2[64:32] != 33'd0) ||
                        (!sign_s2 && rounded_s2[31]) ||
                        (sign_s2 && rounded_s2[31] && (rounded_s2[30:0] != 31'd0));
    wire invalid_wu_s2 = overflow_s2 ||
                         (rounded_s2[64:32] != 33'd0) ||
                         (sign_s2 && rounded_nonzero_s2);
    wire invalid_l_s2 = overflow_s2 || rounded_s2[64] ||
                        (!sign_s2 && rounded_s2[63]) ||
                        (sign_s2 && rounded_s2[63] && (rounded_s2[62:0] != 63'd0));
    wire invalid_lu_s2 = overflow_s2 || rounded_s2[64] ||
                         (sign_s2 && rounded_nonzero_s2);
    wire [63:0] signed_value_s2 = sign_s2 ?
                                  (~rounded_s2[63:0] + 64'd1) :
                                  rounded_s2[63:0];

    always @(*) begin
        pre_special = 1'b0;
        pre_special_result = 64'd0;
        pre_special_flags = 5'd0;
        pre_sign = is_double ? dp_sign : sp_sign;
        pre_overflow = 1'b0;
        pre_shifted = 64'd0;
        pre_round_up = 1'b0;
        pre_inexact = 1'b0;
        pre_exponent = is_double ? ({1'b0, dp_exp} - 12'd1023) :
                                   ({4'd0, sp_exp} - 12'd127);
        pre_temp = is_double ?
                   {(dp_exp == 11'd0) ? 1'b0 : 1'b1, dp_frac, 11'd0} :
                   {(sp_exp == 8'd0) ? 1'b0 : 1'b1, sp_frac, 40'd0};
        pre_remainder = 64'd0;
        pre_guard = 1'b0;
        pre_round = 1'b0;
        pre_sticky = 1'b0;

        if ((is_double && dp_nan) || (!is_double && sp_nan)) begin
            pre_special = 1'b1;
            pre_special_flags[`FF_NV] = 1'b1;
            case (rs2_val)
                5'd0: pre_special_result = 64'h00000000_7FFFFFFF;
                5'd1: pre_special_result = 64'hFFFFFFFF_FFFFFFFF;
                5'd2: pre_special_result = 64'h7FFFFFFFFFFFFFFF;
                5'd3: pre_special_result = 64'hFFFFFFFFFFFFFFFF;
                default: pre_special_result = 64'd0;
            endcase
        end else if ((is_double && dp_inf) || (!is_double && sp_inf)) begin
            pre_special = 1'b1;
            pre_special_flags[`FF_NV] = 1'b1;
            if (pre_sign) begin
                case (rs2_val)
                    5'd0: pre_special_result = 64'hFFFFFFFF_80000000;
                    5'd1: pre_special_result = 64'd0;
                    5'd2: pre_special_result = 64'h8000000000000000;
                    5'd3: pre_special_result = 64'd0;
                    default: pre_special_result = 64'd0;
                endcase
            end else begin
                case (rs2_val)
                    5'd0: pre_special_result = 64'h00000000_7FFFFFFF;
                    5'd1: pre_special_result = 64'hFFFFFFFF_FFFFFFFF;
                    5'd2: pre_special_result = 64'h7FFFFFFFFFFFFFFF;
                    5'd3: pre_special_result = 64'hFFFFFFFFFFFFFFFF;
                    default: pre_special_result = 64'd0;
                endcase
            end
        end else if ((is_double && dp_zero) || (!is_double && sp_zero)) begin
            pre_special = 1'b1;
            pre_special_result = 64'd0;
        end else begin
            if ($signed(pre_exponent) > $signed(12'd63)) begin
                pre_overflow = 1'b1;
            end else if ($signed(pre_exponent) >= $signed(12'd0)) begin
                pre_shifted = pre_temp >> (12'd63 - pre_exponent);
                pre_remainder = pre_temp << (pre_exponent + 12'd1);
                pre_guard = pre_remainder[63];
                pre_round = pre_remainder[62];
                pre_sticky = (pre_remainder[61:0] != 62'd0);
            end else if ($signed(pre_exponent) == -12'sd1) begin
                pre_guard = pre_temp[63];
                pre_round = pre_temp[62];
                pre_sticky = (pre_temp[61:0] != 62'd0);
            end else if ($signed(pre_exponent) == -12'sd2) begin
                pre_round = pre_temp[63];
                pre_sticky = (pre_temp[62:0] != 63'd0);
            end else begin
                pre_sticky = (pre_temp != 64'd0);
            end

            pre_inexact = pre_guard || pre_round || pre_sticky;
            case (rm)
                `RM_RNE: pre_round_up = pre_guard &&
                                           (pre_round || pre_sticky || pre_shifted[0]);
                `RM_RTZ: pre_round_up = 1'b0;
                `RM_RDN: pre_round_up = pre_sign && pre_inexact;
                `RM_RUP: pre_round_up = !pre_sign && pre_inexact;
                `RM_RMM: pre_round_up = pre_guard;
                default: pre_round_up = 1'b0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s1 <= 1'b0;
            special_s1 <= 1'b0;
            special_result_s1 <= 64'd0;
            special_flags_s1 <= 5'd0;
            sign_s1 <= 1'b0;
            overflow_s1 <= 1'b0;
            shifted_s1 <= 64'd0;
            round_up_s1 <= 1'b0;
            inexact_s1 <= 1'b0;
            rs2_val_s1 <= 5'd0;
        end else if (ready_s1) begin
            valid_s1 <= valid_in;
            if (valid_in) begin
                special_s1 <= pre_special;
                special_result_s1 <= pre_special_result;
                special_flags_s1 <= pre_special_flags;
                sign_s1 <= pre_sign;
                overflow_s1 <= pre_overflow;
                shifted_s1 <= pre_shifted;
                round_up_s1 <= pre_round_up;
                inexact_s1 <= pre_inexact;
                rs2_val_s1 <= rs2_val;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s2 <= 1'b0;
            special_s2 <= 1'b0;
            special_result_s2 <= 64'd0;
            special_flags_s2 <= 5'd0;
            sign_s2 <= 1'b0;
            overflow_s2 <= 1'b0;
            rounded_s2 <= 65'd0;
            inexact_s2 <= 1'b0;
            rs2_val_s2 <= 5'd0;
        end else if (ready_s2) begin
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                special_s2 <= special_s1;
                special_result_s2 <= special_result_s1;
                special_flags_s2 <= special_flags_s1;
                sign_s2 <= sign_s1;
                overflow_s2 <= overflow_s1;
                rounded_s2 <= {1'b0, shifted_s1} +
                              (round_up_s1 ? 65'd1 : 65'd0);
                inexact_s2 <= inexact_s1;
                rs2_val_s2 <= rs2_val_s1;
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
                fflags <= 5'd0;
                if (special_s2) begin
                    result <= special_result_s2;
                    fflags <= special_flags_s2;
                end else begin
                    fflags[`FF_NX] <= inexact_s2;
                    case (rs2_val_s2)
                        5'd0: begin
                            if (invalid_w_s2) begin
                                result <= sign_s2 ? 64'hFFFFFFFF_80000000 :
                                                    64'h00000000_7FFFFFFF;
                                fflags <= 5'd0;
                                fflags[`FF_NV] <= 1'b1;
                            end else begin
                                result <= {{32{signed_value_s2[31]}},
                                           signed_value_s2[31:0]};
                            end
                        end
                        5'd1: begin
                            if (invalid_wu_s2) begin
                                result <= sign_s2 ? 64'd0 : 64'hFFFFFFFF_FFFFFFFF;
                                fflags <= 5'd0;
                                fflags[`FF_NV] <= 1'b1;
                            end else begin
                                result <= {{32{rounded_s2[31]}}, rounded_s2[31:0]};
                            end
                        end
                        5'd2: begin
                            if (invalid_l_s2) begin
                                result <= sign_s2 ? 64'h8000000000000000 :
                                                    64'h7FFFFFFFFFFFFFFF;
                                fflags <= 5'd0;
                                fflags[`FF_NV] <= 1'b1;
                            end else begin
                                result <= signed_value_s2;
                            end
                        end
                        5'd3: begin
                            if (invalid_lu_s2) begin
                                result <= sign_s2 ? 64'd0 : 64'hFFFFFFFFFFFFFFFF;
                                fflags <= 5'd0;
                                fflags[`FF_NV] <= 1'b1;
                            end else begin
                                result <= rounded_s2[63:0];
                            end
                        end
                    endcase
                end
            end
        end
    end

endmodule
