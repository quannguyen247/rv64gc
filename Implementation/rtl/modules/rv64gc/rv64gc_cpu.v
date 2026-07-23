`timescale 1ns / 1ps
`include "rv64gc_defs.vh"
`include "mmu64_defs.vh"

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

    localparam [1:0] ASYNC_NONE = 2'd0;
    localparam [1:0] ASYNC_FPU = 2'd1;
    localparam [1:0] ASYNC_MULDIV = 2'd2;

    localparam [2:0] MEM_TLB_REQ = 3'd0;
    localparam [2:0] MEM_TLB_WAIT = 3'd1;
    localparam [2:0] MEM_DATA_REQ = 3'd2;
    localparam [2:0] MEM_DATA_WAIT = 3'd3;
    localparam [2:0] MEM_AMO_WRITE = 3'd4;
    localparam [2:0] MEM_COMPLETE = 3'd5;

    reg [63:0] pc_reg;
    reg halted_reg;
    reg if_pending_reg;
    reg if_discard_reg;
    reg [63:0] if_pending_pc_reg;

    reg if_id_valid_reg;
    reg [63:0] if_id_pc_reg;
    reg [31:0] if_id_inst_reg;
    reg [2:0] if_id_length_reg;
    reg if_id_exc_reg;
    reg [63:0] if_id_exc_cause_reg;
    reg [63:0] if_id_exc_tval_reg;

    reg id_ex_valid_reg;
    reg [63:0] id_ex_pc_reg;
    reg [2:0] id_ex_length_reg;
    reg [63:0] id_ex_rs1_data_reg;
    reg [63:0] id_ex_rs2_data_reg;
    reg [63:0] id_ex_frs1_data_reg;
    reg [63:0] id_ex_frs2_data_reg;
    reg [63:0] id_ex_frs3_data_reg;
    reg [63:0] id_ex_imm_reg;
    reg [4:0] id_ex_rs1_reg;
    reg [4:0] id_ex_rs2_reg;
    reg [4:0] id_ex_frs1_reg;
    reg [4:0] id_ex_frs2_reg;
    reg [4:0] id_ex_frs3_reg;
    reg [4:0] id_ex_rd_reg;
    reg id_ex_rf_we_gpr_reg;
    reg id_ex_rf_we_fpr_reg;
    reg id_ex_src_b_sel_reg;
    reg id_ex_is_word_reg;
    reg id_ex_mem_we_reg;
    reg id_ex_mem_req_reg;
    reg id_ex_is_jal_reg;
    reg id_ex_is_jalr_reg;
    reg id_ex_is_branch_reg;
    reg id_ex_is_atomic_reg;
    reg id_ex_is_fp_mem_reg;
    reg id_ex_is_fpu_reg;
    reg id_ex_fpu_is_double_reg;
    reg id_ex_fpu_src_is_gpr_reg;
    reg id_ex_csr_we_reg;
    reg id_ex_is_csr_imm_reg;
    reg id_ex_is_muldiv_reg;
    reg id_ex_halt_reg;
    reg id_ex_serializing_reg;
    reg id_ex_sfence_vma_reg;
    reg id_ex_mret_reg;
    reg [2:0] id_ex_wb_sel_reg;
    reg [2:0] id_ex_muldiv_op_reg;
    reg [2:0] id_ex_fpu_rm_reg;
    reg [3:0] id_ex_alu_op_reg;
    reg [3:0] id_ex_fpu_op_reg;
    reg [1:0] id_ex_csr_op_reg;
    reg [11:0] id_ex_csr_addr_reg;
    reg [4:0] id_ex_csr_zimm_reg;
    reg [6:0] id_ex_fpu_funct7_reg;
    reg [4:0] id_ex_fpu_rs2_val_reg;
    reg [2:0] id_ex_funct3_reg;
    reg [4:0] id_ex_funct5_reg;
    reg id_ex_exc_reg;
    reg [63:0] id_ex_exc_cause_reg;
    reg [63:0] id_ex_exc_tval_reg;

    reg ex_mem_valid_reg;
    reg [63:0] ex_mem_pc_reg;
    reg [2:0] ex_mem_length_reg;
    reg [4:0] ex_mem_rd_reg;
    reg ex_mem_rf_we_gpr_reg;
    reg ex_mem_rf_we_fpr_reg;
    reg ex_mem_mem_we_reg;
    reg ex_mem_mem_req_reg;
    reg ex_mem_is_atomic_reg;
    reg ex_mem_is_fp_mem_reg;
    reg ex_mem_csr_we_reg;
    reg [1:0] ex_mem_csr_op_reg;
    reg [11:0] ex_mem_csr_addr_reg;
    reg [63:0] ex_mem_csr_wdata_reg;
    reg ex_mem_halt_reg;
    reg ex_mem_serializing_reg;
    reg ex_mem_mret_reg;
    reg [2:0] ex_mem_funct3_reg;
    reg [4:0] ex_mem_funct5_reg;
    reg [63:0] ex_mem_result_reg;
    reg [63:0] ex_mem_va_reg;
    reg [63:0] ex_mem_store_gpr_reg;
    reg [63:0] ex_mem_store_fpr_reg;
    reg [55:0] ex_mem_pa_reg;
    reg [63:0] ex_mem_load_raw_reg;
    reg [2:0] ex_mem_state_reg;
    reg ex_mem_exc_reg;
    reg [63:0] ex_mem_exc_cause_reg;
    reg [63:0] ex_mem_exc_tval_reg;

    reg mem_wb_valid_reg;
    reg [4:0] mem_wb_rd_reg;
    reg mem_wb_rf_we_gpr_reg;
    reg mem_wb_rf_we_fpr_reg;
    reg [63:0] mem_wb_result_reg;
    reg mem_wb_csr_we_reg;
    reg [1:0] mem_wb_csr_op_reg;
    reg [11:0] mem_wb_csr_addr_reg;
    reg [63:0] mem_wb_csr_wdata_reg;
    reg mem_wb_halt_reg;
    reg mem_wb_serializing_reg;
    reg mem_wb_mret_reg;
    reg mem_wb_exc_reg;
    reg [63:0] mem_wb_exc_cause_reg;
    reg [63:0] mem_wb_exc_pc_reg;
    reg [63:0] mem_wb_exc_tval_reg;

    reg [1:0] async_mode_reg;
    reg [3:0] async_class_reg;
    reg [31:0] gpr_busy_reg;
    reg [31:0] fpr_busy_reg;

    reg [6:0] fpu_tag_mem [0:15];
    reg [3:0] fpu_tag_write_ptr_reg;
    reg [3:0] fpu_tag_read_ptr_reg;
    reg [4:0] fpu_tag_count_reg;

    reg [4:0] muldiv_tag_mem [0:15];
    reg [3:0] muldiv_tag_write_ptr_reg;
    reg [3:0] muldiv_tag_read_ptr_reg;
    reg [4:0] muldiv_tag_count_reg;

    reg fpu_input_valid_reg;
    reg [63:0] fpu_input_rs1_reg;
    reg [63:0] fpu_input_rs2_reg;
    reg [63:0] fpu_input_rs3_reg;
    reg [3:0] fpu_input_op_reg;
    reg [2:0] fpu_input_rm_reg;
    reg [6:0] fpu_input_funct7_reg;
    reg [4:0] fpu_input_rs2_val_reg;
    reg fpu_input_is_double_reg;

    reg ptw_response_valid_reg;
    reg ptw_response_owner_reg;
    reg data_response_valid_reg;

    wire [31:0] inst_decomp;
    wire inst_is_compressed;
    wire [2:0] fetch_length;
    wire [63:0] sequential_fetch_pc;
    wire itlb_bypass;
    wire itlb_req;
    wire itlb_ready;
    wire itlb_pa_valid;
    wire [55:0] itlb_pa;
    wire itlb_page_fault;
    wire itlb_access_fault;
    wire itlb_mem_req;
    wire [55:0] itlb_mem_addr;
    wire itlb_mem_valid;

    wire [1:0] priv_mode_out;
    wire [63:0] satp_out;
    wire mstatus_sum_out;
    wire mstatus_mxr_out;
    wire [2:0] frm_out;
    wire [63:0] mepc_out;
    wire [63:0] mtvec_out;
    wire [63:0] csr_rdata;

    wire [4:0] id_rs1;
    wire [4:0] id_rs2;
    wire [4:0] id_rs3;
    wire [4:0] id_rd;
    wire id_rf_we_gpr;
    wire id_rf_we_fpr;
    wire [2:0] id_imm_type;
    wire id_src_b_sel;
    wire [3:0] id_alu_op;
    wire id_is_word;
    wire id_mem_we;
    wire id_mem_req;
    wire [2:0] id_wb_sel;
    wire id_is_jal;
    wire id_is_jalr;
    wire id_is_branch;
    wire id_is_atomic;
    wire id_is_fp_ctrl;
    wire [3:0] id_fpu_op;
    wire id_fpu_is_double;
    wire id_csr_we;
    wire [1:0] id_csr_op;
    wire id_is_csr_imm;
    wire id_is_muldiv;
    wire [2:0] id_muldiv_op;
    wire id_halt;
    wire [63:0] id_imm;
    wire [63:0] id_rs1_data;
    wire [63:0] id_rs2_data;
    wire [63:0] id_frs1_data;
    wire [63:0] id_frs2_data;
    wire [63:0] id_frs3_data;
    wire id_is_fma;
    wire id_is_fpu;
    wire id_is_fp_mem;
    wire id_fpu_i2f;
    wire id_fpu_src_is_gpr;
    wire [2:0] id_fpu_rm;
    wire [3:0] id_fpu_class;
    wire id_sfence_vma;
    wire id_mret;
    wire id_serializing;
    wire id_uses_gpr_rs1;
    wire id_uses_gpr_rs2;
    wire id_uses_fpr_rs1;
    wire id_uses_fpr_rs2;
    wire id_uses_fpr_rs3;
    wire id_source_busy;
    wire id_dest_busy;
    wire id_async_dependency;
    wire id_async_compatible;
    wire id_serializing_wait;
    wire load_use_hazard;
    wire id_stall;
    wire id_payload_fire;
    wire id_fire;
    wire id_ex_ready;

    wire [63:0] ex_fw_rs1;
    wire [63:0] ex_fw_rs2;
    wire [63:0] ex_fw_frs1;
    wire [63:0] ex_fw_frs2;
    wire [63:0] ex_fw_frs3;
    wire [63:0] alu_out;
    wire [63:0] pc_plus_imm;
    wire [63:0] jalr_target;
    wire branch_taken;
    wire [63:0] ex_result_value;
    wire [63:0] effective_addr;
    wire [3:0] id_ex_fpu_class;
    wire backend_ready_for_async;
    wire fpu_fifo_ready;
    wire muldiv_fifo_ready;
    wire fpu_mode_compatible;
    wire muldiv_mode_compatible;
    wire fpu_valid_in;
    wire fpu_ready_in;
    wire fpu_core_ready_in;
    wire fpu_valid_out;
    wire [63:0] fpu_fp_out;
    wire [63:0] fpu_int_out;
    wire fpu_we_gpr;
    wire fpu_we_fpr;
    wire [4:0] fpu_fflags;
    wire muldiv_valid_in;
    wire muldiv_ready_in;
    wire muldiv_valid_out;
    wire [63:0] muldiv_out;
    wire fpu_issue_fire;
    wire muldiv_issue_fire;
    wire async_issue_fire;
    wire ex_normal_fire;
    wire ex_stage_fire;
    wire ex_branch_taken;
    wire [63:0] ex_branch_target;
    wire sfence_vma_ex;
    wire sfence_vma;

    wire dtlb_req;
    wire dtlb_ready;
    wire dtlb_pa_valid;
    wire [55:0] dtlb_pa;
    wire dtlb_page_fault;
    wire dtlb_access_fault;
    wire dtlb_mem_req;
    wire [55:0] dtlb_mem_addr;
    wire dtlb_mem_valid;
    wire ex_mem_is_lr;
    wire ex_mem_is_sc;
    wire ex_mem_is_amo;
    wire data_mem_req;
    wire data_mem_we_ctrl;
    wire lsu_is_atomic;
    wire [63:0] lsu_mem_addr;
    wire [63:0] lsu_mem_wdata;
    wire [7:0] lsu_mem_be;
    wire lsu_mem_we;
    wire lsu_mem_req;
    wire [63:0] lsu_reg_rdata;
    wire [63:0] lsu_fpr_rdata;
    wire [63:0] lsu_mem_rdata;
    wire ex_mem_complete;
    wire ex_mem_ready;
    wire ex_mem_to_wb;
    wire data_fault_now;

    wire fpu_complete_fire;
    wire muldiv_complete_fire;
    wire [4:0] fpu_complete_rd;
    wire fpu_complete_we_gpr;
    wire fpu_complete_we_fpr;
    wire [4:0] muldiv_complete_rd;
    wire async_write_valid;
    wire async_write_gpr;
    wire async_write_fpr;
    wire [4:0] async_write_rd;
    wire [63:0] async_write_data;
    wire rf_we_gpr;
    wire rf_we_fpr;
    wire [4:0] rf_write_rd;
    wire [63:0] rf_write_data;

    wire trap_commit;
    wire mret_commit;
    wire branch_redirect;
    wire control_redirect;
    wire pipeline_kill;
    wire [63:0] redirect_pc;
    wire serializing_inflight;
    wire fetch_block;
    wire fetch_slot_available;
    wire bypass_fetch_fire;
    wire itlb_response;
    wire stall_pipeline;
    wire [63:0] next_pc;

    integer scoreboard_i;

    rv64gc_decompress u_dec (
        .inst_in(inst[15:0]),
        .inst_out(inst_decomp),
        .is_compressed(inst_is_compressed)
    );

    assign fetch_length = inst_is_compressed ? 3'd2 : 3'd4;
    assign sequential_fetch_pc = pc_reg + fetch_length;
    assign next_pc = branch_redirect ? ex_branch_target :
                     control_redirect ? redirect_pc :
                     sequential_fetch_pc;
    assign itlb_bypass = (priv_mode_out == `PRIV_M) ||
                         (satp_out[63:60] == `SATP_MODE_BARE);
    assign pc = itlb_bypass ? pc_reg :
                ((if_pending_reg && itlb_pa_valid) ?
                 {8'd0, itlb_pa} : {8'd0, pc_reg[55:0]});

    assign fetch_slot_available = !if_id_valid_reg || id_fire;
    assign serializing_inflight =
        (id_ex_valid_reg && id_ex_serializing_reg) ||
        (ex_mem_valid_reg && ex_mem_serializing_reg) ||
        (mem_wb_valid_reg && mem_wb_serializing_reg);
    assign fetch_block = halted_reg || serializing_inflight ||
                         (if_id_valid_reg && id_serializing) ||
                         (ex_mem_valid_reg && ex_mem_mem_req_reg);
    assign bypass_fetch_fire = itlb_bypass && fetch_slot_available &&
                               !fetch_block && !pipeline_kill;
    assign itlb_req = !itlb_bypass && !if_pending_reg &&
                      fetch_slot_available && !fetch_block &&
                      !pipeline_kill && itlb_ready;
    assign itlb_response = if_pending_reg &&
                           (itlb_pa_valid || itlb_page_fault ||
                            itlb_access_fault);

    mmu64_top #(
        .TLB_ENTRIES(`TLB_ENTRIES)
    ) u_mmu_itlb (
        .clk(clk),
        .rst_n(rst_n),
        .req(itlb_req),
        .va(pc_reg),
        .access_type(`ACC_EXEC),
        .priv_mode(priv_mode_out),
        .ready(itlb_ready),
        .satp(satp_out),
        .mstatus_sum(mstatus_sum_out),
        .mstatus_mxr(mstatus_mxr_out),
        .pa_valid(itlb_pa_valid),
        .pa(itlb_pa),
        .page_fault(itlb_page_fault),
        .access_fault(itlb_access_fault),
        .sfence_vma(sfence_vma_ex),
        .mem_req(itlb_mem_req),
        .mem_addr(itlb_mem_addr),
        .mem_rdata(mem_rdata),
        .mem_valid(itlb_mem_valid),
        .mem_error(1'b0)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 64'd0;
            halted_reg <= 1'b0;
            if_pending_reg <= 1'b0;
            if_discard_reg <= 1'b0;
            if_pending_pc_reg <= 64'd0;
            if_id_valid_reg <= 1'b0;
            if_id_pc_reg <= 64'd0;
            if_id_inst_reg <= 32'h00000013;
            if_id_length_reg <= 3'd4;
            if_id_exc_reg <= 1'b0;
            if_id_exc_cause_reg <= 64'd0;
            if_id_exc_tval_reg <= 64'd0;
        end else begin
            if (mem_wb_valid_reg && mem_wb_halt_reg &&
                !mem_wb_exc_reg) begin
                halted_reg <= 1'b1;
            end

            if (id_fire) begin
                if_id_valid_reg <= 1'b0;
            end

            if (control_redirect) begin
                pc_reg <= redirect_pc;
                if_id_valid_reg <= 1'b0;
                if (if_pending_reg) begin
                    if_discard_reg <= 1'b1;
                end
            end else if (data_fault_now) begin
                if_id_valid_reg <= 1'b0;
                if (if_pending_reg) begin
                    if_discard_reg <= 1'b1;
                end
            end else if (branch_redirect) begin
                pc_reg <= ex_branch_target;
                if_id_valid_reg <= 1'b0;
                if (if_pending_reg) begin
                    if_discard_reg <= 1'b1;
                end
            end

            if (itlb_req) begin
                if_pending_reg <= 1'b1;
                if_pending_pc_reg <= pc_reg;
                if_discard_reg <= 1'b0;
            end

            if (itlb_response) begin
                if_pending_reg <= 1'b0;
                if (if_discard_reg || pipeline_kill) begin
                    if_discard_reg <= 1'b0;
                end else begin
                    if_id_valid_reg <= 1'b1;
                    if_id_pc_reg <= if_pending_pc_reg;
                    if_id_inst_reg <= inst_is_compressed ?
                                      inst_decomp : inst;
                    if_id_length_reg <= fetch_length;
                    if_id_exc_reg <= itlb_page_fault ||
                                     itlb_access_fault;
                    if_id_exc_cause_reg <= itlb_page_fault ?
                                           64'd12 : 64'd1;
                    if_id_exc_tval_reg <= if_pending_pc_reg;
                    pc_reg <= if_pending_pc_reg + fetch_length;
                end
            end else if (bypass_fetch_fire) begin
                if_id_valid_reg <= 1'b1;
                if_id_pc_reg <= pc_reg;
                if_id_inst_reg <= inst_is_compressed ?
                                  inst_decomp : inst;
                if_id_length_reg <= fetch_length;
                if_id_exc_reg <= 1'b0;
                if_id_exc_cause_reg <= 64'd0;
                if_id_exc_tval_reg <= 64'd0;
                pc_reg <= sequential_fetch_pc;
            end
        end
    end

    assign id_rs1 = if_id_inst_reg[19:15];
    assign id_rs2 = if_id_inst_reg[24:20];
    assign id_rs3 = if_id_inst_reg[31:27];
    assign id_rd = if_id_inst_reg[11:7];

    rv64gc_ctrl u_ctrl (
        .inst(if_id_inst_reg),
        .rf_we_gpr(id_rf_we_gpr),
        .rf_we_fpr(id_rf_we_fpr),
        .imm_type(id_imm_type),
        .src_b_sel(id_src_b_sel),
        .alu_op(id_alu_op),
        .is_word(id_is_word),
        .mem_we(id_mem_we),
        .mem_req(id_mem_req),
        .wb_sel(id_wb_sel),
        .is_jal(id_is_jal),
        .is_jalr(id_is_jalr),
        .is_branch(id_is_branch),
        .is_atomic(id_is_atomic),
        .is_fp(id_is_fp_ctrl),
        .fpu_op(id_fpu_op),
        .fpu_is_double(id_fpu_is_double),
        .csr_we(id_csr_we),
        .csr_op(id_csr_op),
        .is_csr_imm(id_is_csr_imm),
        .is_muldiv(id_is_muldiv),
        .muldiv_op(id_muldiv_op),
        .halt(id_halt)
    );

    rv64gc_imm u_imm (
        .inst(if_id_inst_reg),
        .imm_type(id_imm_type),
        .imm(id_imm)
    );

    assign id_is_fma = (if_id_inst_reg[6:0] == 7'b1000011) ||
                       (if_id_inst_reg[6:0] == 7'b1000111) ||
                       (if_id_inst_reg[6:0] == 7'b1001011) ||
                       (if_id_inst_reg[6:0] == 7'b1001111);
    assign id_is_fpu = (if_id_inst_reg[6:0] == 7'b1010011) ||
                       id_is_fma;
    assign id_is_fp_mem = (if_id_inst_reg[6:0] == 7'b0000111) ||
                          (if_id_inst_reg[6:0] == 7'b0100111);
    assign id_fpu_i2f = (id_fpu_op == `F_CVT) &&
                        ((if_id_inst_reg[31:27] == 5'b11010) ||
                         (if_id_inst_reg[31:27] == 5'b11011));
    assign id_fpu_src_is_gpr = (id_fpu_op == `F_MVTX) ||
                               id_fpu_i2f;
    assign id_fpu_rm = (if_id_inst_reg[14:12] == 3'b111) ?
                       frm_out : if_id_inst_reg[14:12];
    assign id_fpu_class =
        ((id_fpu_op == `F_ADD) || (id_fpu_op == `F_SUB)) ? 4'd0 :
        (id_fpu_op == `F_MUL) ? 4'd1 :
        ((id_fpu_op == `F_MADD) || (id_fpu_op == `F_MSUB) ||
         (id_fpu_op == `F_NMSUB) || (id_fpu_op == `F_NMADD)) ? 4'd2 :
        (id_fpu_op == `F_DIV) ? 4'd3 :
        (id_fpu_op == `F_SQRT) ? 4'd4 :
        (id_fpu_op == `F_COMP) ? 4'd5 :
        (id_fpu_op == `F_CLASS) ? 4'd6 :
        (id_fpu_op == `F_CVT) ? 4'd7 : 4'd8;
    assign id_sfence_vma =
        (if_id_inst_reg[31:25] == 7'b0001001) &&
        (if_id_inst_reg[14:12] == 3'b000) &&
        (if_id_inst_reg[6:0] == 7'b1110011);
    assign id_mret = (if_id_inst_reg == 32'h30200073);
    assign id_serializing = if_id_exc_reg ||
                            (if_id_inst_reg[6:0] == 7'b1110011);

    assign id_uses_gpr_rs1 =
        id_fpu_src_is_gpr ||
        (!id_is_fpu &&
         (if_id_inst_reg[6:0] != 7'b0110111) &&
         (if_id_inst_reg[6:0] != 7'b0010111) &&
         (if_id_inst_reg[6:0] != 7'b1101111) &&
         !(id_is_csr_imm &&
           (if_id_inst_reg[6:0] == 7'b1110011)));
    assign id_uses_gpr_rs2 =
        (if_id_inst_reg[6:0] == 7'b0110011) ||
        (if_id_inst_reg[6:0] == 7'b0111011) ||
        (if_id_inst_reg[6:0] == 7'b1100011) ||
        (if_id_inst_reg[6:0] == 7'b0100011) ||
        (if_id_inst_reg[6:0] == 7'b0101111);
    assign id_uses_fpr_rs1 = id_is_fpu && !id_fpu_src_is_gpr;
    assign id_uses_fpr_rs2 = id_is_fpu &&
                             (id_fpu_op != `F_SQRT) &&
                             (id_fpu_op != `F_CLASS) &&
                             (id_fpu_op != `F_CVT) &&
                             (id_fpu_op != `F_MVTX) &&
                             (id_fpu_op != `F_MVXT);
    assign id_uses_fpr_rs3 = id_is_fma;

    assign id_source_busy =
        (id_uses_gpr_rs1 && (id_rs1 != 5'd0) &&
         gpr_busy_reg[id_rs1]) ||
        (id_uses_gpr_rs2 && (id_rs2 != 5'd0) &&
         gpr_busy_reg[id_rs2]) ||
        (id_uses_fpr_rs1 && fpr_busy_reg[id_rs1]) ||
        (id_uses_fpr_rs2 && fpr_busy_reg[id_rs2]) ||
        (id_uses_fpr_rs3 && fpr_busy_reg[id_rs3]) ||
        ((if_id_inst_reg[6:0] == 7'b0100111) &&
         fpr_busy_reg[id_rs2]);
    assign id_dest_busy =
        (id_rf_we_gpr && (id_rd != 5'd0) &&
         gpr_busy_reg[id_rd]) ||
        (id_rf_we_fpr && fpr_busy_reg[id_rd]);
    assign id_async_dependency =
        (id_ex_valid_reg &&
         (id_ex_is_fpu_reg || id_ex_is_muldiv_reg) &&
         id_ex_rf_we_gpr_reg &&
         (id_ex_rd_reg != 5'd0) &&
         ((id_uses_gpr_rs1 && (id_ex_rd_reg == id_rs1)) ||
          (id_uses_gpr_rs2 && (id_ex_rd_reg == id_rs2)) ||
          (id_rf_we_gpr && (id_ex_rd_reg == id_rd)))) ||
        (id_ex_valid_reg && id_ex_is_fpu_reg &&
         id_ex_rf_we_fpr_reg &&
         ((id_uses_fpr_rs1 && (id_ex_rd_reg == id_rs1)) ||
          (id_uses_fpr_rs2 && (id_ex_rd_reg == id_rs2)) ||
          (id_uses_fpr_rs3 && (id_ex_rd_reg == id_rs3)) ||
          ((if_id_inst_reg[6:0] == 7'b0100111) &&
           (id_ex_rd_reg == id_rs2)) ||
          (id_rf_we_fpr && (id_ex_rd_reg == id_rd))));
    assign id_async_compatible =
        (async_mode_reg == ASYNC_FPU) ?
        (id_is_fpu && (id_fpu_class == async_class_reg)) :
        (async_mode_reg == ASYNC_MULDIV) ?
        (id_is_muldiv && (async_class_reg == 4'd9) &&
         (id_muldiv_op < `M_DIV)) :
        fpu_issue_fire ?
        (id_is_fpu && (id_fpu_class == id_ex_fpu_class)) :
        muldiv_issue_fire ?
        (id_is_muldiv && (id_ex_muldiv_op_reg < `M_DIV) &&
         (id_muldiv_op < `M_DIV)) :
        1'b1;
    assign id_serializing_wait = id_serializing &&
                                 (id_ex_valid_reg ||
                                  ex_mem_valid_reg ||
                                  mem_wb_valid_reg ||
                                  (async_mode_reg != ASYNC_NONE));
    assign load_use_hazard =
        id_ex_valid_reg && id_ex_mem_req_reg &&
        id_ex_rf_we_gpr_reg && (id_ex_rd_reg != 5'd0) &&
        ((id_uses_gpr_rs1 && (id_ex_rd_reg == id_rs1)) ||
         (id_uses_gpr_rs2 && (id_ex_rd_reg == id_rs2)));
    assign id_stall = id_source_busy || id_dest_busy ||
                      id_async_dependency ||
                      !id_async_compatible ||
                      id_serializing_wait || load_use_hazard;
    assign id_ex_ready = !id_ex_valid_reg || ex_stage_fire;
    assign id_payload_fire = if_id_valid_reg && id_ex_ready &&
                             !id_stall;
    assign id_fire = id_payload_fire && !pipeline_kill;

    assign fpu_complete_fire = fpu_valid_out &&
                               (fpu_tag_count_reg != 5'd0);
    assign muldiv_complete_fire = muldiv_valid_out &&
                                  (muldiv_tag_count_reg != 5'd0);
    assign fpu_complete_rd =
        fpu_tag_mem[fpu_tag_read_ptr_reg][4:0];
    assign fpu_complete_we_gpr =
        fpu_tag_mem[fpu_tag_read_ptr_reg][5];
    assign fpu_complete_we_fpr =
        fpu_tag_mem[fpu_tag_read_ptr_reg][6];
    assign muldiv_complete_rd =
        muldiv_tag_mem[muldiv_tag_read_ptr_reg];
    assign async_write_valid = fpu_complete_fire ||
                               muldiv_complete_fire;
    assign async_write_gpr =
        (fpu_complete_fire && fpu_complete_we_gpr) ||
        muldiv_complete_fire;
    assign async_write_fpr =
        fpu_complete_fire && fpu_complete_we_fpr;
    assign async_write_rd = fpu_complete_fire ?
                            fpu_complete_rd :
                            muldiv_complete_rd;
    assign async_write_data = fpu_complete_fire ?
                              (fpu_complete_we_gpr ?
                               fpu_int_out : fpu_fp_out) :
                              muldiv_out;
    assign rf_we_gpr = async_write_valid ? async_write_gpr :
                       (mem_wb_valid_reg &&
                        mem_wb_rf_we_gpr_reg &&
                        !mem_wb_exc_reg);
    assign rf_we_fpr = async_write_valid ? async_write_fpr :
                       (mem_wb_valid_reg &&
                        mem_wb_rf_we_fpr_reg &&
                        !mem_wb_exc_reg);
    assign rf_write_rd = async_write_valid ?
                         async_write_rd : mem_wb_rd_reg;
    assign rf_write_data = async_write_valid ?
                           async_write_data : mem_wb_result_reg;

    rv64gc_rf u_rf (
        .clk(clk),
        .rst_n(rst_n),
        .we_gpr(rf_we_gpr),
        .we_fpr(rf_we_fpr),
        .rs1(id_rs1),
        .rs2(id_rs2),
        .rd(rf_write_rd),
        .frs1(id_rs1),
        .frs2(id_rs2),
        .frs3(id_rs3),
        .frd(rf_write_rd),
        .wdata_gpr(rf_write_data),
        .wdata_fpr(rf_write_data),
        .rs1_data(id_rs1_data),
        .rs2_data(id_rs2_data),
        .frs1_data(id_frs1_data),
        .frs2_data(id_frs2_data),
        .frs3_data(id_frs3_data)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_valid_reg <= 1'b0;
        end else if (pipeline_kill) begin
            id_ex_valid_reg <= 1'b0;
        end else if (id_ex_ready) begin
            id_ex_valid_reg <= id_fire;
        end
    end

    always @(posedge clk) begin
        if (id_payload_fire) begin
            id_ex_pc_reg <= if_id_pc_reg;
            id_ex_length_reg <= if_id_length_reg;
            id_ex_rs1_data_reg <= id_rs1_data;
            id_ex_rs2_data_reg <= id_rs2_data;
            id_ex_frs1_data_reg <= id_frs1_data;
            id_ex_frs2_data_reg <= id_frs2_data;
            id_ex_frs3_data_reg <= id_frs3_data;
            id_ex_imm_reg <= id_imm;
            id_ex_rs1_reg <= id_rs1;
            id_ex_rs2_reg <= id_rs2;
            id_ex_frs1_reg <= id_rs1;
            id_ex_frs2_reg <= id_rs2;
            id_ex_frs3_reg <= id_rs3;
            id_ex_rd_reg <= id_rd;
            id_ex_rf_we_gpr_reg <= id_rf_we_gpr;
            id_ex_rf_we_fpr_reg <= id_rf_we_fpr;
            id_ex_src_b_sel_reg <= id_src_b_sel;
            id_ex_is_word_reg <= id_is_word;
            id_ex_mem_we_reg <= id_mem_we;
            id_ex_mem_req_reg <= id_mem_req;
            id_ex_is_jal_reg <= id_is_jal;
            id_ex_is_jalr_reg <= id_is_jalr;
            id_ex_is_branch_reg <= id_is_branch;
            id_ex_is_atomic_reg <= id_is_atomic;
            id_ex_is_fp_mem_reg <= id_is_fp_mem;
            id_ex_is_fpu_reg <= id_is_fpu;
            id_ex_fpu_is_double_reg <= id_fpu_is_double;
            id_ex_fpu_src_is_gpr_reg <= id_fpu_src_is_gpr;
            id_ex_csr_we_reg <= id_csr_we;
            id_ex_is_csr_imm_reg <= id_is_csr_imm;
            id_ex_is_muldiv_reg <= id_is_muldiv;
            id_ex_halt_reg <= id_halt;
            id_ex_serializing_reg <= id_serializing;
            id_ex_sfence_vma_reg <= id_sfence_vma;
            id_ex_mret_reg <= id_mret;
            id_ex_wb_sel_reg <= id_wb_sel;
            id_ex_muldiv_op_reg <= id_muldiv_op;
            id_ex_fpu_rm_reg <= id_fpu_rm;
            id_ex_alu_op_reg <= id_alu_op;
            id_ex_fpu_op_reg <= id_fpu_op;
            id_ex_csr_op_reg <= id_csr_op;
            id_ex_csr_addr_reg <= if_id_inst_reg[31:20];
            id_ex_csr_zimm_reg <= if_id_inst_reg[19:15];
            id_ex_fpu_funct7_reg <= if_id_inst_reg[31:25];
            id_ex_fpu_rs2_val_reg <= if_id_inst_reg[24:20];
            id_ex_funct3_reg <= if_id_inst_reg[14:12];
            id_ex_funct5_reg <= if_id_inst_reg[31:27];
            id_ex_exc_reg <= if_id_exc_reg;
            id_ex_exc_cause_reg <= if_id_exc_cause_reg;
            id_ex_exc_tval_reg <= if_id_exc_tval_reg;
        end else if (!id_ex_ready) begin
            if (rf_we_gpr && (rf_write_rd != 5'd0)) begin
                if (rf_write_rd == id_ex_rs1_reg) begin
                    id_ex_rs1_data_reg <= rf_write_data;
                end
                if (rf_write_rd == id_ex_rs2_reg) begin
                    id_ex_rs2_data_reg <= rf_write_data;
                end
            end
            if (rf_we_fpr) begin
                if (rf_write_rd == id_ex_frs1_reg) begin
                    id_ex_frs1_data_reg <= rf_write_data;
                end
                if (rf_write_rd == id_ex_frs2_reg) begin
                    id_ex_frs2_data_reg <= rf_write_data;
                end
                if (rf_write_rd == id_ex_frs3_reg) begin
                    id_ex_frs3_data_reg <= rf_write_data;
                end
            end
        end
    end

    assign ex_fw_rs1 =
        (ex_mem_valid_reg && ex_mem_rf_we_gpr_reg &&
         (!ex_mem_mem_req_reg ||
          (ex_mem_state_reg == MEM_COMPLETE)) &&
         !ex_mem_exc_reg &&
         (ex_mem_rd_reg != 5'd0) &&
         (ex_mem_rd_reg == id_ex_rs1_reg)) ?
        ex_mem_result_reg :
        (mem_wb_valid_reg && mem_wb_rf_we_gpr_reg &&
         !mem_wb_exc_reg && (mem_wb_rd_reg != 5'd0) &&
         (mem_wb_rd_reg == id_ex_rs1_reg)) ?
        mem_wb_result_reg : id_ex_rs1_data_reg;
    assign ex_fw_rs2 =
        (ex_mem_valid_reg && ex_mem_rf_we_gpr_reg &&
         (!ex_mem_mem_req_reg ||
          (ex_mem_state_reg == MEM_COMPLETE)) &&
         !ex_mem_exc_reg &&
         (ex_mem_rd_reg != 5'd0) &&
         (ex_mem_rd_reg == id_ex_rs2_reg)) ?
        ex_mem_result_reg :
        (mem_wb_valid_reg && mem_wb_rf_we_gpr_reg &&
         !mem_wb_exc_reg && (mem_wb_rd_reg != 5'd0) &&
         (mem_wb_rd_reg == id_ex_rs2_reg)) ?
        mem_wb_result_reg : id_ex_rs2_data_reg;
    assign ex_fw_frs1 =
        (ex_mem_valid_reg && ex_mem_rf_we_fpr_reg &&
         (!ex_mem_mem_req_reg ||
          (ex_mem_state_reg == MEM_COMPLETE)) &&
         !ex_mem_exc_reg &&
         (ex_mem_rd_reg == id_ex_frs1_reg)) ?
        ex_mem_result_reg :
        (mem_wb_valid_reg && mem_wb_rf_we_fpr_reg &&
         !mem_wb_exc_reg &&
         (mem_wb_rd_reg == id_ex_frs1_reg)) ?
        mem_wb_result_reg : id_ex_frs1_data_reg;
    assign ex_fw_frs2 =
        (ex_mem_valid_reg && ex_mem_rf_we_fpr_reg &&
         (!ex_mem_mem_req_reg ||
          (ex_mem_state_reg == MEM_COMPLETE)) &&
         !ex_mem_exc_reg &&
         (ex_mem_rd_reg == id_ex_frs2_reg)) ?
        ex_mem_result_reg :
        (mem_wb_valid_reg && mem_wb_rf_we_fpr_reg &&
         !mem_wb_exc_reg &&
         (mem_wb_rd_reg == id_ex_frs2_reg)) ?
        mem_wb_result_reg : id_ex_frs2_data_reg;
    assign ex_fw_frs3 =
        (ex_mem_valid_reg && ex_mem_rf_we_fpr_reg &&
         (!ex_mem_mem_req_reg ||
          (ex_mem_state_reg == MEM_COMPLETE)) &&
         !ex_mem_exc_reg &&
         (ex_mem_rd_reg == id_ex_frs3_reg)) ?
        ex_mem_result_reg :
        (mem_wb_valid_reg && mem_wb_rf_we_fpr_reg &&
         !mem_wb_exc_reg &&
         (mem_wb_rd_reg == id_ex_frs3_reg)) ?
        mem_wb_result_reg : id_ex_frs3_data_reg;

    rv64gc_alu u_alu (
        .alu_a(ex_fw_rs1),
        .alu_b(id_ex_src_b_sel_reg ?
               id_ex_imm_reg : ex_fw_rs2),
        .alu_op(id_ex_alu_op_reg),
        .is_word(id_ex_is_word_reg),
        .alu_out(alu_out)
    );

    rv64gc_branch u_branch (
        .rs1_data(ex_fw_rs1),
        .rs2_data(ex_fw_rs2),
        .funct3(id_ex_funct3_reg),
        .branch_taken(branch_taken)
    );

    assign pc_plus_imm = id_ex_pc_reg + id_ex_imm_reg;
    assign jalr_target = (ex_fw_rs1 + id_ex_imm_reg) &
                         ~64'd1;
    assign effective_addr = id_ex_is_atomic_reg ?
                            ex_fw_rs1 : alu_out;
    assign ex_branch_target = id_ex_is_jalr_reg ?
                              jalr_target : pc_plus_imm;
    assign ex_result_value =
        (id_ex_wb_sel_reg == 3'd2) ?
        (id_ex_pc_reg + id_ex_length_reg) :
        (id_ex_wb_sel_reg == 3'd3) ? pc_plus_imm :
        (id_ex_wb_sel_reg == 3'd4) ? id_ex_imm_reg :
        (id_ex_wb_sel_reg == 3'd6) ? csr_rdata :
        alu_out;
    assign id_ex_fpu_class =
        ((id_ex_fpu_op_reg == `F_ADD) ||
         (id_ex_fpu_op_reg == `F_SUB)) ? 4'd0 :
        (id_ex_fpu_op_reg == `F_MUL) ? 4'd1 :
        ((id_ex_fpu_op_reg == `F_MADD) ||
         (id_ex_fpu_op_reg == `F_MSUB) ||
         (id_ex_fpu_op_reg == `F_NMSUB) ||
         (id_ex_fpu_op_reg == `F_NMADD)) ? 4'd2 :
        (id_ex_fpu_op_reg == `F_DIV) ? 4'd3 :
        (id_ex_fpu_op_reg == `F_SQRT) ? 4'd4 :
        (id_ex_fpu_op_reg == `F_COMP) ? 4'd5 :
        (id_ex_fpu_op_reg == `F_CLASS) ? 4'd6 :
        (id_ex_fpu_op_reg == `F_CVT) ? 4'd7 : 4'd8;

    assign backend_ready_for_async = !ex_mem_valid_reg;
    assign fpu_fifo_ready = (fpu_tag_count_reg < 5'd16);
    assign muldiv_fifo_ready = (muldiv_tag_count_reg < 5'd16);
    assign fpu_mode_compatible =
        ((async_mode_reg == ASYNC_NONE) &&
         backend_ready_for_async) ||
        ((async_mode_reg == ASYNC_FPU) &&
         (async_class_reg == id_ex_fpu_class));
    assign muldiv_mode_compatible =
        ((async_mode_reg == ASYNC_NONE) &&
         backend_ready_for_async) ||
        ((async_mode_reg == ASYNC_MULDIV) &&
         (async_class_reg == 4'd9) &&
         (id_ex_muldiv_op_reg < `M_DIV));
    assign fpu_valid_in = id_ex_valid_reg &&
                          id_ex_is_fpu_reg &&
                          !id_ex_exc_reg &&
                          !control_redirect &&
                          !data_fault_now &&
                          fpu_fifo_ready &&
                          fpu_mode_compatible;
    assign muldiv_valid_in = id_ex_valid_reg &&
                             id_ex_is_muldiv_reg &&
                             !id_ex_exc_reg &&
                             !control_redirect &&
                             !data_fault_now &&
                             muldiv_fifo_ready &&
                             muldiv_mode_compatible;
    assign fpu_ready_in = !fpu_input_valid_reg ||
                          fpu_core_ready_in;
    assign fpu_issue_fire = fpu_valid_in && fpu_ready_in;
    assign muldiv_issue_fire = muldiv_valid_in &&
                               muldiv_ready_in;
    assign async_issue_fire = fpu_issue_fire ||
                              muldiv_issue_fire;
    assign ex_normal_fire = id_ex_valid_reg &&
                            (id_ex_exc_reg ||
                             (!id_ex_is_fpu_reg &&
                              !id_ex_is_muldiv_reg)) &&
                            ex_mem_ready;
    assign ex_stage_fire = async_issue_fire ||
                           ex_normal_fire;
    assign ex_branch_taken =
        ex_normal_fire && !id_ex_exc_reg &&
        (id_ex_is_jal_reg || id_ex_is_jalr_reg ||
         (id_ex_is_branch_reg && branch_taken));
    assign sfence_vma_ex = ex_normal_fire &&
                           id_ex_sfence_vma_reg;
    assign sfence_vma = sfence_vma_ex;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fpu_input_valid_reg <= 1'b0;
        end else if (fpu_ready_in) begin
            fpu_input_valid_reg <= fpu_valid_in;
        end
    end

    always @(posedge clk) begin
        if (fpu_ready_in && fpu_valid_in) begin
            fpu_input_rs1_reg <= id_ex_fpu_src_is_gpr_reg ?
                                 ex_fw_rs1 : ex_fw_frs1;
            fpu_input_rs2_reg <= ex_fw_frs2;
            fpu_input_rs3_reg <= ex_fw_frs3;
            fpu_input_op_reg <= id_ex_fpu_op_reg;
            fpu_input_rm_reg <= id_ex_fpu_rm_reg;
            fpu_input_funct7_reg <= id_ex_fpu_funct7_reg;
            fpu_input_rs2_val_reg <= id_ex_fpu_rs2_val_reg;
            fpu_input_is_double_reg <= id_ex_fpu_is_double_reg;
        end
    end

    fpu64_top u_fpu (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_valid(fpu_input_valid_reg),
        .s_axis_ready(fpu_core_ready_in),
        .rs1(fpu_input_rs1_reg),
        .rs2(fpu_input_rs2_reg),
        .rs3(fpu_input_rs3_reg),
        .op(fpu_input_op_reg),
        .funct3(fpu_input_rm_reg),
        .funct7(fpu_input_funct7_reg),
        .rs2_val(fpu_input_rs2_val_reg),
        .is_double(fpu_input_is_double_reg),
        .m_axis_valid(fpu_valid_out),
        .m_axis_ready(1'b1),
        .out_fp(fpu_fp_out),
        .out_int(fpu_int_out),
        .we_gpr(fpu_we_gpr),
        .we_fpr(fpu_we_fpr),
        .fflags(fpu_fflags)
    );

    rv64gc_muldiv u_muldiv (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(muldiv_valid_in),
        .ready_in(muldiv_ready_in),
        .a(ex_fw_rs1),
        .b(ex_fw_rs2),
        .op(id_ex_muldiv_op_reg),
        .is_word(id_ex_is_word_reg),
        .valid_out(muldiv_valid_out),
        .ready_out(1'b1),
        .out(muldiv_out)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            async_mode_reg <= ASYNC_NONE;
            async_class_reg <= 4'd0;
            fpu_tag_write_ptr_reg <= 4'd0;
            fpu_tag_read_ptr_reg <= 4'd0;
            fpu_tag_count_reg <= 5'd0;
            muldiv_tag_write_ptr_reg <= 4'd0;
            muldiv_tag_read_ptr_reg <= 4'd0;
            muldiv_tag_count_reg <= 5'd0;
            gpr_busy_reg <= 32'd0;
            fpr_busy_reg <= 32'd0;
        end else begin
            if (fpu_issue_fire) begin
                fpu_tag_write_ptr_reg <=
                    fpu_tag_write_ptr_reg + 4'd1;
                if (id_ex_rf_we_gpr_reg &&
                    (id_ex_rd_reg != 5'd0)) begin
                    gpr_busy_reg[id_ex_rd_reg] <= 1'b1;
                end
                if (id_ex_rf_we_fpr_reg) begin
                    fpr_busy_reg[id_ex_rd_reg] <= 1'b1;
                end
            end

            if (fpu_complete_fire) begin
                fpu_tag_read_ptr_reg <=
                    fpu_tag_read_ptr_reg + 4'd1;
                if (fpu_complete_we_gpr &&
                    (fpu_complete_rd != 5'd0)) begin
                    gpr_busy_reg[fpu_complete_rd] <= 1'b0;
                end
                if (fpu_complete_we_fpr) begin
                    fpr_busy_reg[fpu_complete_rd] <= 1'b0;
                end
            end

            case ({fpu_issue_fire, fpu_complete_fire})
                2'b10: fpu_tag_count_reg <=
                        fpu_tag_count_reg + 5'd1;
                2'b01: fpu_tag_count_reg <=
                        fpu_tag_count_reg - 5'd1;
                default: begin
                end
            endcase

            if (muldiv_issue_fire) begin
                muldiv_tag_write_ptr_reg <=
                    muldiv_tag_write_ptr_reg + 4'd1;
                if (id_ex_rd_reg != 5'd0) begin
                    gpr_busy_reg[id_ex_rd_reg] <= 1'b1;
                end
            end

            if (muldiv_complete_fire) begin
                muldiv_tag_read_ptr_reg <=
                    muldiv_tag_read_ptr_reg + 4'd1;
                if (muldiv_complete_rd != 5'd0) begin
                    gpr_busy_reg[muldiv_complete_rd] <= 1'b0;
                end
            end

            case ({muldiv_issue_fire, muldiv_complete_fire})
                2'b10: muldiv_tag_count_reg <=
                        muldiv_tag_count_reg + 5'd1;
                2'b01: muldiv_tag_count_reg <=
                        muldiv_tag_count_reg - 5'd1;
                default: begin
                end
            endcase

            if (async_mode_reg == ASYNC_NONE) begin
                if (fpu_issue_fire) begin
                    async_mode_reg <= ASYNC_FPU;
                    async_class_reg <= id_ex_fpu_class;
                end else if (muldiv_issue_fire) begin
                    async_mode_reg <= ASYNC_MULDIV;
                    async_class_reg <=
                        (id_ex_muldiv_op_reg < `M_DIV) ?
                        4'd9 : 4'd10;
                end
            end else if ((async_mode_reg == ASYNC_FPU) &&
                         fpu_complete_fire &&
                         (fpu_tag_count_reg == 5'd1) &&
                         !fpu_issue_fire) begin
                async_mode_reg <= ASYNC_NONE;
            end else if ((async_mode_reg == ASYNC_MULDIV) &&
                         muldiv_complete_fire &&
                         (muldiv_tag_count_reg == 5'd1) &&
                         !muldiv_issue_fire) begin
                async_mode_reg <= ASYNC_NONE;
            end
        end
    end

    always @(posedge clk) begin
        if (fpu_issue_fire) begin
            fpu_tag_mem[fpu_tag_write_ptr_reg] <=
                {id_ex_rf_we_fpr_reg, id_ex_rf_we_gpr_reg,
                 id_ex_rd_reg};
        end
        if (muldiv_issue_fire) begin
            muldiv_tag_mem[muldiv_tag_write_ptr_reg] <=
                id_ex_rd_reg;
        end
    end

    assign ex_mem_is_lr = ex_mem_is_atomic_reg &&
                          (ex_mem_funct5_reg == 5'b00010);
    assign ex_mem_is_sc = ex_mem_is_atomic_reg &&
                          (ex_mem_funct5_reg == 5'b00011);
    assign ex_mem_is_amo = ex_mem_is_atomic_reg &&
                           !ex_mem_is_lr && !ex_mem_is_sc;
    assign dtlb_req = ex_mem_valid_reg &&
                      ex_mem_mem_req_reg &&
                      (ex_mem_state_reg == MEM_TLB_REQ) &&
                      dtlb_ready && !if_pending_reg &&
                      itlb_ready;

    mmu64_top #(
        .TLB_ENTRIES(`TLB_ENTRIES)
    ) u_mmu_dtlb (
        .clk(clk),
        .rst_n(rst_n),
        .req(dtlb_req),
        .va(ex_mem_va_reg),
        .access_type((ex_mem_mem_we_reg &&
                      !ex_mem_is_lr) ?
                     `ACC_STORE : `ACC_LOAD),
        .priv_mode(priv_mode_out),
        .ready(dtlb_ready),
        .satp(satp_out),
        .mstatus_sum(mstatus_sum_out),
        .mstatus_mxr(mstatus_mxr_out),
        .pa_valid(dtlb_pa_valid),
        .pa(dtlb_pa),
        .page_fault(dtlb_page_fault),
        .access_fault(dtlb_access_fault),
        .sfence_vma(sfence_vma_ex),
        .mem_req(dtlb_mem_req),
        .mem_addr(dtlb_mem_addr),
        .mem_rdata(mem_rdata),
        .mem_valid(dtlb_mem_valid),
        .mem_error(1'b0)
    );

    assign data_mem_req =
        ex_mem_valid_reg && ex_mem_mem_req_reg &&
        ((ex_mem_state_reg == MEM_DATA_REQ) ||
         (ex_mem_state_reg == MEM_AMO_WRITE));
    assign data_mem_we_ctrl =
        (ex_mem_state_reg == MEM_AMO_WRITE) ||
        ((ex_mem_state_reg == MEM_DATA_REQ) &&
         ex_mem_mem_we_reg && !ex_mem_is_amo);
    assign lsu_is_atomic = data_mem_req &&
                           ex_mem_is_atomic_reg;
    assign lsu_mem_rdata =
        (ex_mem_state_reg == MEM_AMO_WRITE) ?
        ex_mem_load_raw_reg : mem_rdata;

    rv64gc_lsu u_lsu (
        .clk(clk),
        .rst_n(rst_n),
        .addr({8'd0, ex_mem_pa_reg}),
        .reg_wdata(ex_mem_store_gpr_reg),
        .fpr_wdata(ex_mem_store_fpr_reg),
        .mem_rdata(lsu_mem_rdata),
        .funct3(ex_mem_funct3_reg),
        .funct5(ex_mem_funct5_reg),
        .is_atomic(lsu_is_atomic),
        .is_fp(ex_mem_is_fp_mem_reg),
        .mem_we_ctrl(data_mem_we_ctrl),
        .mem_req_ctrl(data_mem_req),
        .mem_addr(lsu_mem_addr),
        .mem_wdata(lsu_mem_wdata),
        .mem_be(lsu_mem_be),
        .mem_we(lsu_mem_we),
        .mem_req(lsu_mem_req),
        .reg_rdata(lsu_reg_rdata),
        .fpr_rdata(lsu_fpr_rdata)
    );

    assign mem_req = itlb_mem_req || dtlb_mem_req ||
                     lsu_mem_req;
    assign mem_addr = itlb_mem_req ?
                      {8'd0, itlb_mem_addr} :
                      dtlb_mem_req ?
                      {8'd0, dtlb_mem_addr} :
                      lsu_mem_addr;
    assign mem_wdata = lsu_mem_wdata;
    assign mem_be = lsu_mem_be;
    assign mem_we = lsu_mem_req && lsu_mem_we;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptw_response_valid_reg <= 1'b0;
            ptw_response_owner_reg <= 1'b0;
            data_response_valid_reg <= 1'b0;
        end else begin
            ptw_response_valid_reg <= itlb_mem_req ||
                                      dtlb_mem_req;
            if (itlb_mem_req) begin
                ptw_response_owner_reg <= 1'b0;
            end else if (dtlb_mem_req) begin
                ptw_response_owner_reg <= 1'b1;
            end
            data_response_valid_reg <= lsu_mem_req &&
                                       !lsu_mem_we;
        end
    end

    assign itlb_mem_valid = ptw_response_valid_reg &&
                            !ptw_response_owner_reg;
    assign dtlb_mem_valid = ptw_response_valid_reg &&
                            ptw_response_owner_reg;
    assign data_fault_now =
        ex_mem_valid_reg && ex_mem_mem_req_reg &&
        (ex_mem_state_reg == MEM_TLB_WAIT) &&
        (dtlb_page_fault || dtlb_access_fault);
    assign ex_mem_complete =
        ex_mem_valid_reg &&
        (!ex_mem_mem_req_reg ||
         (ex_mem_state_reg == MEM_COMPLETE));
    assign ex_mem_ready = !ex_mem_valid_reg ||
                          ex_mem_complete;
    assign ex_mem_to_wb = ex_mem_complete;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_valid_reg <= 1'b0;
            ex_mem_state_reg <= MEM_COMPLETE;
            ex_mem_exc_reg <= 1'b0;
        end else if (control_redirect) begin
            ex_mem_valid_reg <= 1'b0;
            ex_mem_state_reg <= MEM_COMPLETE;
            ex_mem_exc_reg <= 1'b0;
        end else begin
            if (ex_mem_valid_reg && ex_mem_mem_req_reg) begin
                case (ex_mem_state_reg)
                    MEM_TLB_REQ: begin
                        if (dtlb_req) begin
                            ex_mem_state_reg <= MEM_TLB_WAIT;
                        end
                    end

                    MEM_TLB_WAIT: begin
                        if (dtlb_pa_valid) begin
                            ex_mem_pa_reg <= dtlb_pa;
                            ex_mem_state_reg <= MEM_DATA_REQ;
                        end else if (dtlb_page_fault ||
                                     dtlb_access_fault) begin
                            ex_mem_exc_reg <= 1'b1;
                            ex_mem_exc_cause_reg <=
                                dtlb_page_fault ?
                                (ex_mem_mem_we_reg ?
                                 64'd15 : 64'd13) :
                                (ex_mem_mem_we_reg ?
                                 64'd7 : 64'd5);
                            ex_mem_exc_tval_reg <= ex_mem_va_reg;
                            ex_mem_state_reg <= MEM_COMPLETE;
                        end
                    end

                    MEM_DATA_REQ: begin
                        if (lsu_mem_req) begin
                            if (ex_mem_is_amo) begin
                                ex_mem_state_reg <= MEM_DATA_WAIT;
                            end else if (ex_mem_mem_we_reg) begin
                                if (ex_mem_is_sc) begin
                                    ex_mem_result_reg <=
                                        lsu_reg_rdata;
                                end
                                ex_mem_state_reg <= MEM_COMPLETE;
                            end else begin
                                ex_mem_state_reg <= MEM_DATA_WAIT;
                            end
                        end
                    end

                    MEM_DATA_WAIT: begin
                        if (data_response_valid_reg) begin
                            ex_mem_load_raw_reg <= mem_rdata;
                            if (ex_mem_is_fp_mem_reg) begin
                                ex_mem_result_reg <= lsu_fpr_rdata;
                            end else begin
                                ex_mem_result_reg <= lsu_reg_rdata;
                            end
                            if (ex_mem_is_amo) begin
                                ex_mem_state_reg <= MEM_AMO_WRITE;
                            end else begin
                                ex_mem_state_reg <= MEM_COMPLETE;
                            end
                        end
                    end

                    MEM_AMO_WRITE: begin
                        if (lsu_mem_req) begin
                            ex_mem_state_reg <= MEM_COMPLETE;
                        end
                    end

                    default: begin
                        ex_mem_state_reg <= MEM_COMPLETE;
                    end
                endcase
            end

            if (ex_mem_ready) begin
                ex_mem_valid_reg <= ex_normal_fire;
                if (ex_normal_fire) begin
                    ex_mem_pc_reg <= id_ex_pc_reg;
                    ex_mem_length_reg <= id_ex_length_reg;
                    ex_mem_rd_reg <= id_ex_rd_reg;
                    ex_mem_rf_we_gpr_reg <=
                        id_ex_rf_we_gpr_reg;
                    ex_mem_rf_we_fpr_reg <=
                        id_ex_rf_we_fpr_reg;
                    ex_mem_mem_we_reg <= id_ex_mem_we_reg;
                    ex_mem_mem_req_reg <= id_ex_mem_req_reg;
                    ex_mem_is_atomic_reg <=
                        id_ex_is_atomic_reg;
                    ex_mem_is_fp_mem_reg <=
                        id_ex_is_fp_mem_reg;
                    ex_mem_csr_we_reg <= id_ex_csr_we_reg;
                    ex_mem_csr_op_reg <= id_ex_csr_op_reg;
                    ex_mem_csr_addr_reg <= id_ex_csr_addr_reg;
                    ex_mem_csr_wdata_reg <=
                        id_ex_is_csr_imm_reg ?
                        {59'd0, id_ex_csr_zimm_reg} :
                        ex_fw_rs1;
                    ex_mem_halt_reg <= id_ex_halt_reg;
                    ex_mem_serializing_reg <=
                        id_ex_serializing_reg;
                    ex_mem_mret_reg <= id_ex_mret_reg;
                    ex_mem_funct3_reg <= id_ex_funct3_reg;
                    ex_mem_funct5_reg <= id_ex_funct5_reg;
                    ex_mem_result_reg <= ex_result_value;
                    ex_mem_va_reg <= effective_addr;
                    ex_mem_store_gpr_reg <= ex_fw_rs2;
                    ex_mem_store_fpr_reg <= ex_fw_frs2;
                    ex_mem_pa_reg <= 56'd0;
                    ex_mem_load_raw_reg <= 64'd0;
                    ex_mem_state_reg <= id_ex_mem_req_reg ?
                                        MEM_TLB_REQ :
                                        MEM_COMPLETE;
                    ex_mem_exc_reg <= id_ex_exc_reg;
                    ex_mem_exc_cause_reg <=
                        id_ex_exc_cause_reg;
                    ex_mem_exc_tval_reg <=
                        id_ex_exc_tval_reg;
                end
            end
        end
    end

    assign trap_commit = mem_wb_valid_reg &&
                         mem_wb_exc_reg;
    assign mret_commit = mem_wb_valid_reg &&
                         mem_wb_mret_reg &&
                         !mem_wb_exc_reg;
    assign branch_redirect = ex_branch_taken;
    assign control_redirect = trap_commit || mret_commit;
    assign redirect_pc = trap_commit ? mtvec_out : mepc_out;
    assign pipeline_kill = control_redirect ||
                           branch_redirect ||
                           data_fault_now;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_valid_reg <= 1'b0;
            mem_wb_exc_reg <= 1'b0;
        end else if (control_redirect) begin
            mem_wb_valid_reg <= 1'b0;
            mem_wb_exc_reg <= 1'b0;
        end else begin
            mem_wb_valid_reg <= ex_mem_to_wb;
            if (ex_mem_to_wb) begin
                mem_wb_rd_reg <= ex_mem_rd_reg;
                mem_wb_rf_we_gpr_reg <=
                    ex_mem_rf_we_gpr_reg;
                mem_wb_rf_we_fpr_reg <=
                    ex_mem_rf_we_fpr_reg;
                mem_wb_result_reg <= ex_mem_result_reg;
                mem_wb_csr_we_reg <= ex_mem_csr_we_reg;
                mem_wb_csr_op_reg <= ex_mem_csr_op_reg;
                mem_wb_csr_addr_reg <= ex_mem_csr_addr_reg;
                mem_wb_csr_wdata_reg <=
                    ex_mem_csr_wdata_reg;
                mem_wb_halt_reg <= ex_mem_halt_reg;
                mem_wb_serializing_reg <=
                    ex_mem_serializing_reg;
                mem_wb_mret_reg <= ex_mem_mret_reg;
                mem_wb_exc_reg <= ex_mem_exc_reg;
                mem_wb_exc_cause_reg <=
                    ex_mem_exc_cause_reg;
                mem_wb_exc_pc_reg <= ex_mem_pc_reg;
                mem_wb_exc_tval_reg <=
                    ex_mem_exc_tval_reg;
            end
        end
    end

    rv64gc_csr u_csr (
        .clk(clk),
        .rst_n(rst_n),
        .raddr(id_ex_csr_addr_reg),
        .waddr(mem_wb_csr_addr_reg),
        .wdata(mem_wb_csr_wdata_reg),
        .we(mem_wb_valid_reg &&
            mem_wb_csr_we_reg &&
            !mem_wb_exc_reg),
        .op(mem_wb_csr_op_reg),
        .instret_inc(
            (mem_wb_valid_reg &&
             !mem_wb_exc_reg &&
             !mem_wb_halt_reg) ||
            fpu_complete_fire ||
            muldiv_complete_fire),
        .fflags_set(fpu_complete_fire ?
                    fpu_fflags : 5'd0),
        .exception(trap_commit),
        .exc_cause(mem_wb_exc_cause_reg),
        .exc_pc(mem_wb_exc_pc_reg),
        .exc_tval(mem_wb_exc_tval_reg),
        .mret(mret_commit),
        .rdata(csr_rdata),
        .mepc_out(mepc_out),
        .mtvec_out(mtvec_out),
        .satp_out(satp_out),
        .mstatus_sum_out(mstatus_sum_out),
        .mstatus_mxr_out(mstatus_mxr_out),
        .priv_mode_out(priv_mode_out),
        .frm_out(frm_out)
    );

    assign halt = halted_reg;
    assign stall_pipeline =
        (id_ex_valid_reg && !ex_stage_fire) ||
        (if_id_valid_reg && !id_fire) ||
        fetch_block;

endmodule
