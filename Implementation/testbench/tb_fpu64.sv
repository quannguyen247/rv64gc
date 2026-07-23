`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module tb_fpu64_top;

    reg clk;
    reg rst_n;
    reg s_axis_valid;
    wire s_axis_ready;
    wire m_axis_valid;
    reg m_axis_ready;
    reg [63:0] rs1;
    reg [63:0] rs2;
    reg [63:0] rs3;
    reg [3:0] op;
    reg [2:0] funct3;
    reg [6:0] funct7;
    reg [4:0] rs2_val;
    reg is_double;
    wire [63:0] out_fp;
    wire [63:0] out_int;
    wire we_gpr;
    wire we_fpr;
    wire [4:0] fflags;

    fpu64_top u_fpu (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_valid(s_axis_valid),
        .s_axis_ready(s_axis_ready),
        .rs1(rs1),
        .rs2(rs2),
        .rs3(rs3),
        .op(op),
        .funct3(funct3),
        .funct7(funct7),
        .rs2_val(rs2_val),
        .is_double(is_double),
        .m_axis_valid(m_axis_valid),
        .m_axis_ready(m_axis_ready),
        .out_fp(out_fp),
        .out_int(out_int),
        .we_gpr(we_gpr),
        .we_fpr(we_fpr),
        .fflags(fflags)
    );

    initial begin
        clk = 1'b0;
        forever #2.5 clk = ~clk;
    end

    task launch;
    begin
        if (m_axis_valid) begin
            @(negedge clk);
            m_axis_ready = 1'b1;
            @(negedge clk);
            m_axis_ready = 1'b0;
        end
        while (!s_axis_ready) @(posedge clk);
        @(negedge clk);
        s_axis_valid = 1'b1;
        @(negedge clk);
        s_axis_valid = 1'b0;
        while (!m_axis_valid) @(posedge clk);
        #0.1;
    end
    endtask

    initial begin
        rst_n = 1'b0;
        s_axis_valid = 1'b0;
        m_axis_ready = 1'b0;
        is_double = 0;
        rs1 = 64'h0000000041700000;
        rs2 = 64'h0000000041a00000;
        rs3 = 64'd0;
        op = `F_ADD;
        funct3 = 3'd0;
        funct7 = 7'd0;
        rs2_val = 5'd0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        launch();
        if (out_fp[31:0] !== 32'h420c0000) begin
            $display("Fail Single Add: %h", out_fp);
            $finish;
        end

        is_double = 1;
        rs1 = $realtobits(15.0);
        rs2 = $realtobits(20.0);
        op = `F_ADD;
        launch();
        if ($bitstoreal(out_fp) != 35.0) begin
            $display("Fail Double Add: %f", $bitstoreal(out_fp));
            $finish;
        end

        is_double = 0;
        rs1 = 64'h0000000041700000;
        op = `F_CVT;
        funct7 = 7'b1100000;
        rs2_val = 5'd0;
        launch();
        if (out_int !== 64'd15) begin
            $display("Fail CVT Single to Int: %d", out_int);
            $finish;
        end

        $display("FPU TEST PASS");
        $finish;
    end

endmodule
