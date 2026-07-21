`timescale 1ns / 1ps

module fpu64_convert (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire [63:0] rs1,
    input wire [4:0] rs2_val,
    input wire [6:0] funct7,
    input wire [2:0] rm,
    output reg valid_out,
    input wire ready_out,
    output reg [63:0] out_fp,
    output reg [63:0] out_int,
    output reg we_gpr,
    output reg we_fpr,
    output reg [4:0] fflags
);

    wire f2i_ready_in;
    wire f2i_valid_out;
    wire [63:0] f2i_result;
    wire [4:0] f2i_flags;
    wire i2f_ready_in;
    wire i2f_valid_out;
    wire [63:0] i2f_result;
    wire [4:0] i2f_flags;
    wire f2f_ready_in;
    wire f2f_valid_out;
    wire [63:0] f2f_result;
    wire [4:0] f2f_flags;

    reg control_valid_s1;
    reg [4:0] control_op_s1;
    reg control_unsupported_s1;
    reg control_valid_s2;
    reg [4:0] control_op_s2;
    reg control_unsupported_s2;
    reg control_valid_s3;
    reg [4:0] control_op_s3;
    reg control_unsupported_s3;

    wire control_ready_s3 = !control_valid_s3 || ready_out;
    wire control_ready_s2 = !control_valid_s2 || control_ready_s3;
    wire control_ready_s1 = !control_valid_s1 || control_ready_s2;
    assign ready_in = control_ready_s1 && f2i_ready_in &&
                      i2f_ready_in && f2f_ready_in;
    wire accept_in = valid_in && ready_in;

    fpu64_convert_f2i u_f2i (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(accept_in),
        .ready_in(f2i_ready_in),
        .rs1(rs1),
        .rs2_val(rs2_val),
        .is_double(funct7[0]),
        .rm(rm),
        .valid_out(f2i_valid_out),
        .ready_out(ready_out),
        .result(f2i_result),
        .fflags(f2i_flags)
    );

    fpu64_convert_i2f u_i2f (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(accept_in),
        .ready_in(i2f_ready_in),
        .rs1(rs1),
        .rs2_val(rs2_val),
        .is_double(funct7[0]),
        .rm(rm),
        .valid_out(i2f_valid_out),
        .ready_out(ready_out),
        .result(i2f_result),
        .fflags(i2f_flags)
    );

    fpu64_convert_f2f u_f2f (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(accept_in),
        .ready_in(f2f_ready_in),
        .rs1(rs1),
        .to_double(funct7[0]),
        .rm(rm),
        .valid_out(f2f_valid_out),
        .ready_out(ready_out),
        .result(f2f_result),
        .fflags(f2f_flags)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_valid_s1 <= 1'b0;
            control_op_s1 <= 5'd0;
            control_unsupported_s1 <= 1'b0;
        end else if (control_ready_s1) begin
            control_valid_s1 <= accept_in;
            if (accept_in) begin
                control_op_s1 <= funct7[6:2];
                control_unsupported_s1 <= funct7[1];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_valid_s2 <= 1'b0;
            control_op_s2 <= 5'd0;
            control_unsupported_s2 <= 1'b0;
        end else if (control_ready_s2) begin
            control_valid_s2 <= control_valid_s1;
            if (control_valid_s1) begin
                control_op_s2 <= control_op_s1;
                control_unsupported_s2 <= control_unsupported_s1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_valid_s3 <= 1'b0;
            control_op_s3 <= 5'd0;
            control_unsupported_s3 <= 1'b0;
        end else if (control_ready_s3) begin
            control_valid_s3 <= control_valid_s2;
            if (control_valid_s2) begin
                control_op_s3 <= control_op_s2;
                control_unsupported_s3 <= control_unsupported_s2;
            end
        end
    end

    always @(*) begin
        valid_out = control_valid_s3 && f2i_valid_out &&
                    i2f_valid_out && f2f_valid_out;
        out_fp = 64'd0;
        out_int = 64'd0;
        we_gpr = 1'b0;
        we_fpr = 1'b0;
        fflags = 5'd0;
        case (control_op_s3)
            5'b11000, 5'b11001: begin
                out_int = f2i_result;
                we_gpr = 1'b1;
                fflags = f2i_flags | {control_unsupported_s3, 4'd0};
            end
            5'b11010, 5'b11011: begin
                out_fp = i2f_result;
                we_fpr = 1'b1;
                fflags = i2f_flags | {control_unsupported_s3, 4'd0};
            end
            5'b01000, 5'b01001: begin
                out_fp = f2f_result;
                we_fpr = 1'b1;
                fflags = f2f_flags | {control_unsupported_s3, 4'd0};
            end
            default: begin
            end
        endcase
    end

endmodule
