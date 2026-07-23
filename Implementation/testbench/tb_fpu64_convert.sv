`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module tb_fpu64_convert;

    reg clk;
    reg rst_n;
    reg valid_in;
    wire ready_in;
    reg [63:0] rs1;
    reg [4:0] rs2_val;
    reg [6:0] funct7;
    reg [2:0] rm;
    wire valid_out;
    reg ready_out;
    wire [63:0] out_fp;
    wire [63:0] out_int;
    wire we_gpr;
    wire we_fpr;
    wire [4:0] fflags;

    reg [63:0] vector_rs1 [0:191];
    reg [4:0] vector_rs2_val [0:191];
    reg [6:0] vector_funct7 [0:191];
    reg [2:0] vector_rm [0:191];
    reg [63:0] vector_out_fp [0:191];
    reg [63:0] vector_out_int [0:191];
    reg vector_we_gpr [0:191];
    reg vector_we_fpr [0:191];
    reg [4:0] vector_fflags [0:191];
    integer vector_count;
    integer send_count;
    integer receive_count;
    integer timeout_count;
    integer random_i;
    reg [31:0] random_state;
    reg stalled;
    reg [134:0] stalled_payload;

    fpu64_convert u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .rs1(rs1),
        .rs2_val(rs2_val),
        .funct7(funct7),
        .rm(rm),
        .valid_out(valid_out),
        .ready_out(ready_out),
        .out_fp(out_fp),
        .out_int(out_int),
        .we_gpr(we_gpr),
        .we_fpr(we_fpr),
        .fflags(fflags)
    );

    always #2.5 clk = ~clk;

    function [31:0] uint_to_float_exact;
        input [23:0] value;
        integer bit_i;
        integer leading_bit;
        reg [47:0] shifted_value;
        reg [7:0] exponent_value;
        begin
            leading_bit = -1;
            for (bit_i = 23; bit_i >= 0; bit_i = bit_i - 1) begin
                if ((leading_bit < 0) && value[bit_i]) begin
                    leading_bit = bit_i;
                end
            end
            if (leading_bit < 0) begin
                uint_to_float_exact = 32'd0;
            end else begin
                shifted_value = {24'd0, value} << (23 - leading_bit);
                exponent_value = leading_bit + 8'd127;
                uint_to_float_exact = {1'b0, exponent_value,
                                       shifted_value[22:0]};
            end
        end
    endfunction

    task add_vector;
        input [63:0] task_rs1;
        input [4:0] task_rs2_val;
        input [6:0] task_funct7;
        input [2:0] task_rm;
        input [63:0] task_out_fp;
        input [63:0] task_out_int;
        input task_we_gpr;
        input task_we_fpr;
        input [4:0] task_fflags;
        begin
            vector_rs1[vector_count] = task_rs1;
            vector_rs2_val[vector_count] = task_rs2_val;
            vector_funct7[vector_count] = task_funct7;
            vector_rm[vector_count] = task_rm;
            vector_out_fp[vector_count] = task_out_fp;
            vector_out_int[vector_count] = task_out_int;
            vector_we_gpr[vector_count] = task_we_gpr;
            vector_we_fpr[vector_count] = task_we_fpr;
            vector_fflags[vector_count] = task_fflags;
            vector_count = vector_count + 1;
        end
    endtask

    always @(negedge clk) begin
        if (!rst_n) begin
            valid_in = 1'b0;
            rs1 = 64'd0;
            rs2_val = 5'd0;
            funct7 = 7'd0;
            rm = 3'd0;
            ready_out = 1'b0;
        end else begin
            ready_out = random_state[0] || random_state[3];
            if (send_count < vector_count) begin
                valid_in = 1'b1;
                rs1 = vector_rs1[send_count];
                rs2_val = vector_rs2_val[send_count];
                funct7 = vector_funct7[send_count];
                rm = vector_rm[send_count];
            end else begin
                valid_in = 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            send_count <= 0;
            receive_count <= 0;
            timeout_count <= 0;
            random_state <= 32'h1ACEB00C;
            stalled <= 1'b0;
            stalled_payload <= 135'd0;
        end else begin
            random_state <= {random_state[30:0],
                             random_state[31] ^ random_state[21] ^
                             random_state[1] ^ random_state[0]};
            timeout_count <= timeout_count + 1;
            if (valid_in && ready_in) begin
                send_count <= send_count + 1;
            end
            if (valid_out && ready_out) begin
                if ((out_fp !== vector_out_fp[receive_count]) ||
                    (out_int !== vector_out_int[receive_count]) ||
                    (we_gpr !== vector_we_gpr[receive_count]) ||
                    (we_fpr !== vector_we_fpr[receive_count]) ||
                    (fflags !== vector_fflags[receive_count])) begin
                    $display("CONVERT FAIL index=%0d fp=%h/%h int=%h/%h we=%b%b/%b%b flags=%h/%h",
                             receive_count, out_fp,
                             vector_out_fp[receive_count], out_int,
                             vector_out_int[receive_count], we_gpr, we_fpr,
                             vector_we_gpr[receive_count],
                             vector_we_fpr[receive_count], fflags,
                             vector_fflags[receive_count]);
                    $fatal;
                end
                receive_count <= receive_count + 1;
            end
            if (stalled && (!valid_out ||
                ({out_fp, out_int, we_gpr, we_fpr, fflags} !== stalled_payload))) begin
                $display("CONVERT FAIL payload changed under backpressure");
                $fatal;
            end
            stalled <= valid_out && !ready_out;
            if (valid_out && !ready_out) begin
                stalled_payload <= {out_fp, out_int, we_gpr, we_fpr, fflags};
            end
            if (receive_count == vector_count) begin
                $display("CONVERT PIPELINE TEST PASS vectors=%0d", vector_count);
                $finish;
            end
            if (timeout_count > 5000) begin
                $display("CONVERT FAIL timeout sent=%0d received=%0d",
                         send_count, receive_count);
                $fatal;
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        valid_in = 1'b0;
        ready_out = 1'b0;
        rs1 = 64'd0;
        rs2_val = 5'd0;
        funct7 = 7'd0;
        rm = 3'd0;
        vector_count = 0;
        send_count = 0;
        receive_count = 0;
        timeout_count = 0;
        random_state = 32'h1ACEB00C;
        stalled = 1'b0;
        stalled_payload = 135'd0;

        add_vector(64'hFFFFFFFF_3FC00000, 5'd0, 7'b1100000,
                   `RM_RNE, 64'd0, 64'd2, 1'b1, 1'b0, 5'b00001);
        add_vector(64'hFFFFFFFF_3FC00000, 5'd0, 7'b1100000,
                   `RM_RTZ, 64'd0, 64'd1, 1'b1, 1'b0, 5'b00001);
        add_vector(64'hFFFFFFFF_BFC00000, 5'd0, 7'b1100000,
                   `RM_RDN, 64'd0, 64'hFFFFFFFFFFFFFFFE,
                   1'b1, 1'b0, 5'b00001);
        add_vector(64'hFFFFFFFF_BF800000, 5'd1, 7'b1100000,
                   `RM_RTZ, 64'd0, 64'd0, 1'b1, 1'b0, 5'b10000);
        add_vector(64'h00000000_CF000000, 5'd0, 7'b1100000,
                   `RM_RNE, 64'd0, 64'hFFFFFFFF80000000,
                   1'b1, 1'b0, 5'd0);
        add_vector(64'hC3E0000000000000, 5'd2, 7'b1100001,
                   `RM_RNE, 64'd0, 64'h8000000000000000,
                   1'b1, 1'b0, 5'd0);
        add_vector(64'h43E0000000000000, 5'd3, 7'b1100001,
                   `RM_RNE, 64'd0, 64'h8000000000000000,
                   1'b1, 1'b0, 5'd0);
        add_vector(64'h43E0000000000000, 5'd2, 7'b1100001,
                   `RM_RNE, 64'd0, 64'h7FFFFFFFFFFFFFFF,
                   1'b1, 1'b0, 5'b10000);
        add_vector(64'h43F0000000000000, 5'd3, 7'b1100001,
                   `RM_RNE, 64'd0, 64'hFFFFFFFFFFFFFFFF,
                   1'b1, 1'b0, 5'b10000);
        add_vector(64'h7FF8000000000000, 5'd2, 7'b1100001,
                   `RM_RNE, 64'd0, 64'h7FFFFFFFFFFFFFFF,
                   1'b1, 1'b0, 5'b10000);
        add_vector(64'd15, 5'd2, 7'b1101001,
                   `RM_RNE, 64'h402E000000000000, 64'd0,
                   1'b0, 1'b1, 5'd0);
        add_vector(64'hFFFFFFFF_3F800000, 5'd0, 7'b0100001,
                   `RM_RNE, 64'h3FF0000000000000, 64'd0,
                   1'b0, 1'b1, 5'd0);
        add_vector(64'h3FF0000000000000, 5'd0, 7'b0100000,
                   `RM_RNE, 64'hFFFFFFFF3F800000, 64'd0,
                   1'b0, 1'b1, 5'd0);

        for (random_i = 0; random_i < 64; random_i = random_i + 1) begin
            random_state = {random_state[30:0],
                            random_state[31] ^ random_state[21] ^
                            random_state[1] ^ random_state[0]};
            add_vector({40'd0, random_state[23:0]}, 5'd1, 7'b1101000,
                       `RM_RNE,
                       {32'hFFFFFFFF,
                        uint_to_float_exact(random_state[23:0])},
                       64'd0, 1'b0, 1'b1, 5'd0);
            add_vector({32'hFFFFFFFF,
                        uint_to_float_exact(random_state[23:0])},
                       5'd1, 7'b1100000, `RM_RNE, 64'd0,
                       {32'd0, 8'd0, random_state[23:0]},
                       1'b1, 1'b0, 5'd0);
        end

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
    end

endmodule
