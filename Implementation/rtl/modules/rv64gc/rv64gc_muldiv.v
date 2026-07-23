`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_muldiv (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire [63:0] a,
    input wire [63:0] b,
    input wire [2:0] op,
    input wire is_word,
    output wire valid_out,
    input wire ready_out,
    output reg [63:0] out
);

    localparam [1:0] DIV_IDLE = 2'b01;
    localparam [1:0] DIV_RUN = 2'b10;
    localparam [1:0] DIV_DONE = 2'b11;

    reg mul_valid_s1;
    reg signed [64:0] mul_a_s1;
    reg signed [64:0] mul_b_s1;
    reg [2:0] mul_op_s1;
    reg mul_word_s1;
    reg mul_valid_s2;
    reg [2:0] mul_op_s2;
    reg mul_word_s2;
    reg signed [129:0] mul_product_s2;

    reg [1:0] div_state;
    reg [2:0] div_op_reg;
    reg div_word_reg;
    reg div_quot_negative_reg;
    reg div_rem_negative_reg;
    reg [6:0] div_count_reg;
    reg [63:0] div_divisor_reg;
    reg [63:0] div_quotient_reg;
    reg [64:0] div_remainder_reg;
    reg [63:0] div_out_reg;
    reg [63:0] div_quotient_next;
    reg [64:0] div_remainder_next;

    wire input_is_mul;
    wire mul_output_ready;
    wire mul_stage1_ready;
    wire mul_accept;
    wire div_accept;
    wire mul_pipeline_empty;
    wire div_valid_out;
    wire [63:0] div_quotient_signed;
    wire [64:0] div_remainder_signed;

    assign input_is_mul = (op == `M_MUL) || (op == `M_MULH) ||
                          (op == `M_MULHSU) || (op == `M_MULHU);
    assign div_valid_out = (div_state == DIV_DONE);
    assign valid_out = div_valid_out || mul_valid_s2;
    assign mul_output_ready = !mul_valid_s2 ||
                              (ready_out && !div_valid_out);
    assign mul_stage1_ready = !mul_valid_s1 || mul_output_ready;
    assign mul_pipeline_empty = !mul_valid_s1 && !mul_valid_s2;
    assign ready_in = input_is_mul ?
                      ((div_state == DIV_IDLE) && mul_stage1_ready) :
                      ((div_state == DIV_IDLE) && mul_pipeline_empty);
    assign mul_accept = valid_in && ready_in && input_is_mul;
    assign div_accept = valid_in && ready_in && !input_is_mul;
    assign div_quotient_signed = div_quot_negative_reg ?
                                 (~div_quotient_next + 64'd1) :
                                 div_quotient_next;
    assign div_remainder_signed = div_rem_negative_reg ?
                                  (~div_remainder_next + 65'd1) :
                                  div_remainder_next;

    always @(*) begin
        if (div_valid_out) begin
            out = div_out_reg;
        end else if (mul_word_s2) begin
            out = {{32{mul_product_s2[31]}}, mul_product_s2[31:0]};
        end else begin
            case (mul_op_s2)
                `M_MUL: out = mul_product_s2[63:0];
                `M_MULH: out = mul_product_s2[127:64];
                `M_MULHSU: out = mul_product_s2[127:64];
                `M_MULHU: out = mul_product_s2[127:64];
                default: out = 64'd0;
            endcase
        end
    end

    always @(*) begin
        if (div_word_reg) begin
            div_remainder_next = {div_remainder_reg[63:0],
                                  div_quotient_reg[31]};
            div_quotient_next = {32'd0, div_quotient_reg[30:0], 1'b0};
        end else begin
            div_remainder_next = {div_remainder_reg[63:0],
                                  div_quotient_reg[63]};
            div_quotient_next = {div_quotient_reg[62:0], 1'b0};
        end

        if (div_remainder_next >= {1'b0, div_divisor_reg}) begin
            div_remainder_next = div_remainder_next -
                                 {1'b0, div_divisor_reg};
            div_quotient_next[0] = 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_valid_s1 <= 1'b0;
            mul_op_s1 <= 3'd0;
            mul_word_s1 <= 1'b0;
            mul_valid_s2 <= 1'b0;
            mul_op_s2 <= 3'd0;
            mul_word_s2 <= 1'b0;
        end else begin
            if (mul_output_ready) begin
                mul_valid_s2 <= mul_valid_s1;
                if (mul_valid_s1) begin
                    mul_op_s2 <= mul_op_s1;
                    mul_word_s2 <= mul_word_s1;
                end
            end

            if (mul_stage1_ready) begin
                mul_valid_s1 <= mul_accept;
                if (mul_accept) begin
                    mul_op_s1 <= op;
                    mul_word_s1 <= is_word;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (mul_output_ready && mul_valid_s1) begin
            mul_product_s2 <= mul_a_s1 * mul_b_s1;
        end

        if (mul_stage1_ready && mul_accept) begin
            mul_a_s1 <= ((op == `M_MULH) ||
                         (op == `M_MULHSU)) ?
                        {a[63], a} : {1'b0, a};
            mul_b_s1 <= (op == `M_MULH) ?
                        {b[63], b} : {1'b0, b};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_state <= DIV_IDLE;
            div_op_reg <= 3'd0;
            div_word_reg <= 1'b0;
            div_quot_negative_reg <= 1'b0;
            div_rem_negative_reg <= 1'b0;
            div_count_reg <= 7'd0;
            div_divisor_reg <= 64'd0;
            div_quotient_reg <= 64'd0;
            div_remainder_reg <= 65'd0;
            div_out_reg <= 64'd0;
        end else begin
            case (div_state)
                DIV_IDLE: begin
                    if (div_accept) begin
                        div_op_reg <= op;
                        div_word_reg <= is_word;
                        div_count_reg <= 7'd0;
                        if ((is_word && (b[31:0] == 32'd0)) ||
                            (!is_word && (b == 64'd0))) begin
                            if (op == `M_DIV || op == `M_DIVU) begin
                                div_out_reg <= 64'hFFFFFFFFFFFFFFFF;
                            end else begin
                                div_out_reg <= is_word ?
                                               {{32{a[31]}}, a[31:0]} : a;
                            end
                            div_state <= DIV_DONE;
                        end else if ((op == `M_DIV || op == `M_REM) &&
                                     ((is_word &&
                                       (a[31:0] == 32'h80000000) &&
                                       (b[31:0] == 32'hFFFFFFFF)) ||
                                      (!is_word &&
                                       (a == 64'h8000000000000000) &&
                                       (b == 64'hFFFFFFFFFFFFFFFF)))) begin
                            if (op == `M_DIV) begin
                                div_out_reg <= is_word ?
                                               64'hFFFFFFFF80000000 :
                                               64'h8000000000000000;
                            end else begin
                                div_out_reg <= 64'd0;
                            end
                            div_state <= DIV_DONE;
                        end else begin
                            div_quot_negative_reg <= (op == `M_DIV) &&
                                                     ((is_word ? a[31] :
                                                       a[63]) ^
                                                      (is_word ? b[31] :
                                                       b[63]));
                            div_rem_negative_reg <= (op == `M_REM) &&
                                                    (is_word ? a[31] :
                                                     a[63]);
                            if (is_word) begin
                                div_quotient_reg <= {32'd0,
                                    ((op == `M_DIV || op == `M_REM) &&
                                     a[31]) ?
                                    (~a[31:0] + 32'd1) : a[31:0]};
                                div_divisor_reg <= {32'd0,
                                    ((op == `M_DIV || op == `M_REM) &&
                                     b[31]) ?
                                    (~b[31:0] + 32'd1) : b[31:0]};
                            end else begin
                                div_quotient_reg <=
                                    ((op == `M_DIV || op == `M_REM) &&
                                     a[63]) ?
                                    (~a + 64'd1) : a;
                                div_divisor_reg <=
                                    ((op == `M_DIV || op == `M_REM) &&
                                     b[63]) ?
                                    (~b + 64'd1) : b;
                            end
                            div_remainder_reg <= 65'd0;
                            div_state <= DIV_RUN;
                        end
                    end
                end

                DIV_RUN: begin
                    if (div_count_reg ==
                        (div_word_reg ? 7'd31 : 7'd63)) begin
                        if (div_op_reg == `M_DIV ||
                            div_op_reg == `M_DIVU) begin
                            div_out_reg <= div_word_reg ?
                                           {{32{div_quotient_signed[31]}},
                                            div_quotient_signed[31:0]} :
                                           div_quotient_signed;
                        end else begin
                            div_out_reg <= div_word_reg ?
                                           {{32{div_remainder_signed[31]}},
                                            div_remainder_signed[31:0]} :
                                           div_remainder_signed[63:0];
                        end
                        div_state <= DIV_DONE;
                    end else begin
                        div_quotient_reg <= div_quotient_next;
                        div_remainder_reg <= div_remainder_next;
                        div_count_reg <= div_count_reg + 7'd1;
                    end
                end

                DIV_DONE: begin
                    if (ready_out) begin
                        div_state <= DIV_IDLE;
                    end
                end

                default: begin
                    div_state <= DIV_IDLE;
                end
            endcase
        end
    end

endmodule
