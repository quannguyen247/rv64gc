`timescale 1ns / 1ps

module tb_rv64gc_cpu;

    reg clk;
    reg rst_n;
    wire [63:0] pc;
    reg [31:0] inst;
    wire [63:0] mem_addr;
    wire [63:0] mem_wdata;
    reg [63:0] mem_rdata;
    wire mem_we;
    wire [7:0] mem_be;
    wire mem_req;
    wire halt;

    reg [63:0] ram [0:1023];

    rv64gc_cpu u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc),
        .inst(inst),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_we(mem_we),
        .mem_be(mem_be),
        .mem_req(mem_req),
        .halt(halt)
    );

    initial begin
        clk = 1'b0;
        forever #2.5 clk = ~clk;
    end

    integer i;
    integer timeout;
    integer fpu_accepts;
    integer fpu_commits;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            ram[i] = 64'd0;
        end

        ram[0] = {32'h01400113, 32'h00a00093};
        ram[1] = {32'h02208233, 32'h002081b3};
        ram[2] = {32'h00950001, 32'h021242b3};
        ram[3] = {32'hd00080d3, 32'hd0010153};
        ram[4] = {32'hc00184d3, 32'h002081d3};
        ram[5] = {32'h18208243, 32'hc0009473};
        ram[6] = {32'hd0000053, 32'hc0020553};
        ram[7] = {32'h001025f3, 32'h180082d3};
        ram[8] = {32'hf0060353, 32'h3fc00637};
        ram[9] = {32'hc00376d3, 32'h0020d073};
        ram[10] = {32'hd20083d3, 32'h00102773};
        ram[11] = {32'h00000073, 32'hc20387d3};
    end

    wire [15:0] inst_part0 = (pc[2] == 1'b0) ?
                             ((pc[1] == 1'b0) ? ram[pc[11:3]][15:0] : ram[pc[11:3]][31:16]) :
                             ((pc[1] == 1'b0) ? ram[pc[11:3]][47:32] : ram[pc[11:3]][63:48]);

    wire [63:0] pc_plus_2_addr = pc + 64'd2;
    wire [15:0] inst_part1 = (pc_plus_2_addr[2] == 1'b0) ?
                             ((pc_plus_2_addr[1] == 1'b0) ? ram[pc_plus_2_addr[11:3]][15:0] : ram[pc_plus_2_addr[11:3]][31:16]) :
                             ((pc_plus_2_addr[1] == 1'b0) ? ram[pc_plus_2_addr[11:3]][47:32] : ram[pc_plus_2_addr[11:3]][63:48]);

    always @(*) begin
        inst = {inst_part1, inst_part0};
    end

    always @(posedge clk) begin
        if (mem_req) begin
            if (mem_we) begin
                if (mem_be[0]) ram[mem_addr[11:3]][7:0]   <= mem_wdata[7:0];
                if (mem_be[1]) ram[mem_addr[11:3]][15:8]  <= mem_wdata[15:8];
                if (mem_be[2]) ram[mem_addr[11:3]][23:16] <= mem_wdata[23:16];
                if (mem_be[3]) ram[mem_addr[11:3]][31:24] <= mem_wdata[31:24];
                if (mem_be[4]) ram[mem_addr[11:3]][39:32] <= mem_wdata[39:32];
                if (mem_be[5]) ram[mem_addr[11:3]][47:40] <= mem_wdata[47:40];
                if (mem_be[6]) ram[mem_addr[11:3]][55:48] <= mem_wdata[55:48];
                if (mem_be[7]) ram[mem_addr[11:3]][63:56] <= mem_wdata[63:56];
            end
            mem_rdata <= ram[mem_addr[11:3]];
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            $display("Time: %0t | PC: %h | Inst: %h | inst_is_comp: %b | next_pc: %h | GPR[1]: %d | GPR[2]: %d | GPR[3]: %d | br_taken: %b | br_tgt: %h | stall: %b",
                     $time, pc, inst, u_dut.inst_is_compressed, u_dut.next_pc, u_dut.u_rf.gpr[1], u_dut.u_rf.gpr[2], u_dut.u_rf.gpr[3], u_dut.ex_branch_taken, u_dut.ex_branch_target, u_dut.stall_pipeline);
            if (u_dut.u_muldiv.valid_in) begin
                $display("Time: %0t | MULDIV IN | op: %b | a: %0d | b: %0d", $time, u_dut.u_muldiv.op, u_dut.u_muldiv.a, u_dut.u_muldiv.b);
            end
            if (u_dut.u_muldiv.valid_out) begin
                $display("Time: %0t | MULDIV OUT | out: %0d", $time, u_dut.u_muldiv.out);
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            fpu_accepts <= 0;
            fpu_commits <= 0;
        end else begin
            if (u_dut.fpu_valid_in && u_dut.fpu_ready_in) begin
                fpu_accepts <= fpu_accepts + 1;
            end
            if (u_dut.fpu_valid_out) begin
                fpu_commits <= fpu_commits + 1;
            end
        end
    end

    initial begin
        rst_n = 1'b0;
        #20;
        @(posedge clk);
        #1;
        rst_n = 1'b1;

        timeout = 0;
        while (!halt && (timeout < 5000)) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (!halt) begin
            $fatal(1, "STATUS: FAIL timeout");
        end
        #20;

        $display("x1 = %d (Exp: 15)", u_dut.u_rf.gpr[1]);
        $display("x2 = %d (Exp: 20)", u_dut.u_rf.gpr[2]);
        $display("x3 = %d (Exp: 30)", u_dut.u_rf.gpr[3]);
        $display("x4 = %d (Exp: 200)", u_dut.u_rf.gpr[4]);
        $display("x5 = %d (Exp: 20)", u_dut.u_rf.gpr[5]);
        $display("x9 = %d (Exp: 35)", u_dut.u_rf.gpr[9]);
        $display("x10 = %d (Exp: 335)", u_dut.u_rf.gpr[10]);
        $display("x11 = %d (Exp: 8)", u_dut.u_rf.gpr[11]);
        $display("x13 = %d (Exp: 1)", u_dut.u_rf.gpr[13]);
        $display("x14 = %d (Exp: 9)", u_dut.u_rf.gpr[14]);
        $display("x15 = %d (Exp: 15)", u_dut.u_rf.gpr[15]);
        $display("FPU handshakes = %0d commits = %0d (Exp: 12/12)", fpu_accepts, fpu_commits);
        $display("x8 = %d (Cycle count)", u_dut.u_rf.gpr[8]);

        if (u_dut.u_rf.gpr[1] == 64'd15 &&
            u_dut.u_rf.gpr[2] == 64'd20 &&
            u_dut.u_rf.gpr[3] == 64'd30 &&
            u_dut.u_rf.gpr[4] == 64'd200 &&
            u_dut.u_rf.gpr[5] == 64'd20 &&
            u_dut.u_rf.gpr[9] == 64'd35 &&
            u_dut.u_rf.gpr[10] == 64'd335 &&
            u_dut.u_rf.gpr[11] == 64'd8 &&
            u_dut.u_rf.gpr[13] == 64'd1 &&
            u_dut.u_rf.gpr[14] == 64'd9 &&
            u_dut.u_rf.gpr[15] == 64'd15 &&
            fpu_accepts == 12 &&
            fpu_commits == 12) begin
            $display("STATUS: PASS 100%%");
        end else begin
            $fatal(1, "STATUS: FAIL");
        end

        $finish;
    end

endmodule
