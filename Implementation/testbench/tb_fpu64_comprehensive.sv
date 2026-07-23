`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module tb_fpu64_comprehensive;

    reg clk;
    reg rst_n;
    reg s_axis_valid;
    wire s_axis_ready;
    wire m_axis_valid;
    reg m_axis_ready;
    reg [63:0] rs1;
    reg [63:0] rs2;
    reg [63:0] rs3;
    reg [3:0]  op;
    reg [2:0]  funct3;
    reg [6:0]  funct7;
    reg [4:0]  rs2_val;
    reg        is_double;

    wire [63:0] out_fp;
    wire [63:0] out_int;
    wire        we_gpr;
    wire        we_fpr;
    wire [4:0]  fflags;

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
        rs1 = 64'h0000000040A00000;
        rs2 = 64'h0000000040400000;
        rs3 = 64'd0;
        op = `F_ADD;
        funct3 = `RM_RNE;
        funct7 = 7'd0;
        rs2_val = 5'd0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        launch();
        if (out_fp[31:0] !== 32'h41000000) begin
            $display("Fail SP ADD: %h", out_fp);
            $finish;
        end

        is_double = 1;
        rs1 = 64'h4014000000000000;
        rs2 = 64'h4008000000000000;
        op = `F_ADD;
        launch();
        if (out_fp !== 64'h4020000000000000) begin
            $display("Fail DP ADD: %h", out_fp);
            $finish;
        end

        is_double = 0;
        rs1 = 64'h0000000040A00000;
        rs2 = 64'h0000000040400000;
        op = `F_SUB;
        launch();
        if (out_fp[31:0] !== 32'h40000000) begin
            $display("Fail SP SUB: %h", out_fp);
            $finish;
        end

        is_double = 1;
        rs1 = 64'h4014000000000000;
        rs2 = 64'h4008000000000000;
        op = `F_SUB;
        launch();
        if (out_fp !== 64'h4000000000000000) begin
            $display("Fail DP SUB: %h", out_fp);
            $finish;
        end

        is_double = 0;
        rs1 = 64'h0000000040A00000;
        rs2 = 64'h0000000040400000;
        op = `F_MUL;
        launch();
        if (out_fp[31:0] !== 32'h41700000) begin
            $display("Fail SP MUL: %h", out_fp);
            $finish;
        end

        is_double = 1;
        rs1 = 64'h4014000000000000;
        rs2 = 64'h4008000000000000;
        op = `F_MUL;
        launch();
        if (out_fp !== 64'h402E000000000000) begin
            $display("Fail DP MUL: %h", out_fp);
            $finish;
        end

        is_double = 0;
        rs1 = 64'h0000000040A00000;
        rs2 = 64'h0000000040000000;
        op = `F_DIV;
        launch();
        if (out_fp[31:0] !== 32'h40200000) begin
            $display("Fail SP DIV: %h", out_fp);
            $finish;
        end

        is_double = 1;
        rs1 = 64'h4014000000000000;
        rs2 = 64'h4000000000000000;
        op = `F_DIV;
        launch();
        if (out_fp !== 64'h4004000000000000) begin
            $display("Fail DP DIV: %h", out_fp);
            $finish;
        end

        is_double = 0;
        rs1 = 64'h0000000041100000;
        op = `F_SQRT;
        launch();
        if (out_fp[31:0] !== 32'h40400000) begin
            $display("Fail SP SQRT: %h", out_fp);
            $finish;
        end

        is_double = 1;
        rs1 = 64'h4022000000000000;
        op = `F_SQRT;
        launch();
        if (out_fp !== 64'h4008000000000000) begin
            $display("Fail DP SQRT: %h", out_fp);
            $finish;
        end

        is_double = 0;
        rs1 = 64'h0000000040A00000;
        rs2 = 64'h0000000040400000;
        op = `F_COMP;
        funct3 = 3'b001;
        launch();
        if (out_int !== 64'd0) begin
            $display("Fail SP CMP LT: %h", out_int);
            $finish;
        end

        is_double = 1;
        rs1 = 64'h4008000000000000;
        rs2 = 64'h4014000000000000;
        op = `F_COMP;
        funct3 = 3'b001;
        launch();
        if (out_int !== 64'd1) begin
            $display("Fail DP CMP LT: %h", out_int);
            $finish;
        end

        is_double = 0;
        rs1 = 64'h0000000040A00000;
        op = `F_CLASS;
        launch();
        if (out_int !== 64'b0001000000) begin
            $display("Fail SP CLASS: %h", out_int);
            $finish;
        end

        is_double = 1;
        rs1 = 64'hBFF0000000000000;
        op = `F_CLASS;
        launch();
        if (out_int !== 64'b0000000010) begin
            $display("Fail DP CLASS: %h", out_int);
            $finish;
        end

        is_double = 0;
        rs1 = 64'h0000000041700000;
        op = `F_CVT;
        funct7 = 7'b1100000;
        rs2_val = 5'd0;
        launch();
        if (out_int !== 64'd15) begin
            $display("Fail CVT SP to W: %h", out_int);
            $finish;
        end

        is_double = 1;
        rs1 = 64'h402E000000000000;
        op = `F_CVT;
        funct7 = 7'b1100001;
        rs2_val = 5'd0;
        launch();
        if (out_int !== 64'd15) begin
            $display("Fail CVT DP to W: %h", out_int);
            $finish;
        end

        is_double = 0;
        rs1 = 64'd15;
        op = `F_CVT;
        funct7 = 7'b1101000;
        rs2_val = 5'd0;
        launch();
        if (out_fp[31:0] !== 32'h41700000) begin
            $display("Fail CVT W to SP: %h", out_fp);
            $finish;
        end

        is_double = 1;
        rs1 = 64'd15;
        op = `F_CVT;
        funct7 = 7'b1101001;
        rs2_val = 5'd0;
        launch();
        if (out_fp !== 64'h402E000000000000) begin
            $display("Fail CVT W to DP: %h", out_fp);
            $finish;
        end

        is_double = 0;
        rs1 = 64'h402E000000000000;
        op = `F_CVT;
        funct7 = 7'b0100000;
        rs2_val = 5'd1;
        launch();
        if (out_fp[31:0] !== 32'h41700000) begin
            $display("Fail CVT DP to SP: %h", out_fp);
            $finish;
        end

        is_double = 1;
        rs1 = 64'h0000000041700000;
        op = `F_CVT;
        funct7 = 7'b0100001;
        rs2_val = 5'd0;
        launch();
        if (out_fp !== 64'h402E000000000000) begin
            $display("Fail CVT SP to DP: %h", out_fp);
            $finish;
        end

        $display("ALL COMPREHENSIVE TESTS PASS");
        $finish;
    end

endmodule
