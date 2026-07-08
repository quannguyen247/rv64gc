`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_cpu (
    input wire clk,
    input wire rst_n,
    output wire [63:0] pc,
    input wire [31:0] inst,
    output wire [63:0] mem_addr,
    output wire [63:0] mem_wdata,
    input wire [63:0] mem_rdata,
    output wire mem_we,
    output wire [7:0] mem_be,
    output wire mem_req,
    output wire halt
);

    reg [63:0] pc_reg;
    reg [63:0] rf_wdata_gpr;
    reg [63:0] rf_wdata_fpr;

    wire [31:0] inst_decomp;
    wire is_compressed;

    wire rf_we_gpr;
    wire rf_we_fpr;
    wire [2:0] imm_type;
    wire src_b_sel;
    wire [3:0] alu_op;
    wire is_word;
    wire mem_we_ctrl;
    wire mem_req_ctrl;
    wire [2:0] wb_sel;
    wire is_jal;
    wire is_jalr;
    wire is_branch;
    wire is_atomic;
    wire is_fp;
    wire [3:0] fpu_op;
    wire fpu_is_double;
    wire csr_we;
    wire [1:0] csr_op;
    wire is_csr_imm;
    wire is_muldiv;
    wire [2:0] muldiv_op;

    wire [63:0] rs1_data;
    wire [63:0] rs2_data;
    wire [63:0] frs1_data;
    wire [63:0] frs2_data;
    wire [63:0] frs3_data;

    wire [63:0] imm;
    wire [63:0] alu_b;
    wire [63:0] alu_out;
    wire [63:0] muldiv_out;
    wire [63:0] fpu_fp_out;
    wire [63:0] fpu_int_out;
    wire fpu_we_gpr;
    wire fpu_we_fpr;
    wire [4:0] fpu_fflags;

    wire [63:0] lsu_rdata_gpr;
    wire [63:0] lsu_rdata_fpr;
    wire branch_taken;

    wire [63:0] csr_rdata;
    wire [63:0] mepc_out;
    wire [63:0] mtvec_out;

    wire [63:0] pc_next;
    wire [63:0] pc_plus_offset;
    wire [63:0] pc_plus_4;
    wire [63:0] pc_plus_imm;
    wire [63:0] jalr_target;

    assign pc_plus_offset = is_compressed ? 64'd2 : 64'd4;
    assign pc_plus_4 = pc_reg + pc_plus_offset;
    assign pc_plus_imm = pc_reg + imm;
    assign jalr_target = (rs1_data + imm) & ~64'd1;

    assign pc_next = is_jalr ? jalr_target :
                     (is_jal || (is_branch && branch_taken)) ? pc_plus_imm :
                     pc_plus_4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 64'd0;
        end else begin
            if (!halt) begin
                pc_reg <= pc_next;
            end
        end
    end

    assign pc = pc_reg;

    rv64gc_decompress u_dec (
        .inst_in(inst[15:0]),
        .inst_out(inst_decomp),
        .is_compressed(is_compressed)
    );

    wire [31:0] inst_active = is_compressed ? inst_decomp : inst;

    rv64gc_ctrl u_ctrl (
        .inst(inst_active),
        .rf_we_gpr(rf_we_gpr),
        .rf_we_fpr(rf_we_fpr),
        .imm_type(imm_type),
        .src_b_sel(src_b_sel),
        .alu_op(alu_op),
        .is_word(is_word),
        .mem_we(mem_we_ctrl),
        .mem_req(mem_req_ctrl),
        .wb_sel(wb_sel),
        .is_jal(is_jal),
        .is_jalr(is_jalr),
        .is_branch(is_branch),
        .is_atomic(is_atomic),
        .is_fp(is_fp),
        .fpu_op(fpu_op),
        .fpu_is_double(fpu_is_double),
        .csr_we(csr_we),
        .csr_op(csr_op),
        .is_csr_imm(is_csr_imm),
        .is_muldiv(is_muldiv),
        .muldiv_op(muldiv_op),
        .halt(halt)
    );

    wire rf_we_gpr_final = rf_we_gpr || (inst_active[6:0] == 7'b1010011 && fpu_we_gpr);
    wire rf_we_fpr_final = rf_we_fpr || (inst_active[6:0] == 7'b1010011 && fpu_we_fpr);

    rv64gc_rf u_rf (
        .clk(clk),
        .rst_n(rst_n),
        .we_gpr(rf_we_gpr_final),
        .we_fpr(rf_we_fpr_final),
        .rs1(inst_active[19:15]),
        .rs2(inst_active[24:20]),
        .rd(inst_active[11:7]),
        .frs1(inst_active[19:15]),
        .frs2(inst_active[24:20]),
        .frs3(inst_active[31:27]),
        .frd(inst_active[11:7]),
        .wdata_gpr(rf_wdata_gpr),
        .wdata_fpr(rf_wdata_fpr),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .frs1_data(frs1_data),
        .frs2_data(frs2_data),
        .frs3_data(frs3_data)
    );

    rv64gc_imm u_imm (
        .inst(inst_active),
        .imm_type(imm_type),
        .imm(imm)
    );

    rv64gc_branch u_branch (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .funct3(inst_active[14:12]),
        .branch_taken(branch_taken)
    );

    assign alu_b = src_b_sel ? imm : rs2_data;

    rv64gc_alu u_alu (
        .alu_a(rs1_data),
        .alu_b(alu_b),
        .alu_op(alu_op),
        .is_word(is_word),
        .alu_out(alu_out)
    );

    rv64gc_muldiv u_muldiv (
        .a(rs1_data),
        .b(rs2_data),
        .op(muldiv_op),
        .is_word(is_word),
        .out(muldiv_out)
    );

    wire fpu_src_is_gpr = (inst_active[6:0] == 7'b1010011) &&
                          ((fpu_op == `F_MVXT) ||
                           (fpu_op == `F_CVT && inst_active[28] == 1'b1));

    fpu64_top u_fpu (
        .rs1(fpu_src_is_gpr ? rs1_data : frs1_data),
        .rs2(frs2_data),
        .rs3(frs3_data),
        .op(fpu_op),
        .funct3(inst_active[14:12]),
        .funct7(inst_active[31:25]),
        .rs2_val(inst_active[24:20]),
        .is_double(fpu_is_double),
        .out_fp(fpu_fp_out),
        .out_int(fpu_int_out),
        .we_gpr(fpu_we_gpr),
        .we_fpr(fpu_we_fpr),
        .fflags(fpu_fflags)
    );

    rv64gc_lsu u_lsu (
        .clk(clk),
        .rst_n(rst_n),
        .addr(alu_out),
        .reg_wdata(rs2_data),
        .fpr_wdata(frs2_data),
        .mem_rdata(mem_rdata),
        .funct3(inst_active[14:12]),
        .funct5(inst_active[31:27]),
        .is_atomic(is_atomic),
        .is_fp(is_fp),
        .mem_we_ctrl(mem_we_ctrl),
        .mem_req_ctrl(mem_req_ctrl),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_be(mem_be),
        .mem_we(mem_we),
        .mem_req(mem_req),
        .reg_rdata(lsu_rdata_gpr),
        .fpr_rdata(lsu_rdata_fpr)
    );

    wire [63:0] csr_wdata = is_csr_imm ? {59'd0, inst_active[19:15]} : rs1_data;

    rv64gc_csr u_csr (
        .clk(clk),
        .rst_n(rst_n),
        .addr(inst_active[31:20]),
        .wdata(csr_wdata),
        .we(csr_we),
        .op(csr_op),
        .instret_inc(!halt),
        .fflags_set(fpu_fflags),
        .exception(1'b0),
        .exc_cause(64'd0),
        .exc_pc(64'd0),
        .rdata(csr_rdata),
        .mepc_out(mepc_out),
        .mtvec_out(mtvec_out)
    );

    always @(*) begin
        case (wb_sel)
            3'd0:    rf_wdata_gpr = is_muldiv ? muldiv_out : alu_out;
            3'd1:    rf_wdata_gpr = lsu_rdata_gpr;
            3'd2:    rf_wdata_gpr = pc_plus_4;
            3'd3:    rf_wdata_gpr = pc_plus_imm;
            3'd4:    rf_wdata_gpr = imm;
            3'd6:    rf_wdata_gpr = csr_rdata;
            3'd7:    rf_wdata_gpr = fpu_int_out;
            default: rf_wdata_gpr = alu_out;
        endcase
    end

    always @(*) begin
        if (wb_sel == 3'd5) begin
            rf_wdata_fpr = fpu_fp_out;
        end else begin
            rf_wdata_fpr = lsu_rdata_fpr;
        end
    end

endmodule
