`timescale 1ns / 1ps
`include "mmu64_defs.vh"

module mmu64_top #(
    parameter TLB_ENTRIES = `TLB_ENTRIES
)(
    input wire clk,
    input wire rst_n,

    input wire req,
    input wire [`VA_WIDTH-1:0] va,
    input wire [1:0] access_type,
    input wire [1:0] priv_mode,
    output wire ready,

    input wire [`SATP_WIDTH-1:0] satp,
    input wire mstatus_sum,
    input wire mstatus_mxr,

    output reg pa_valid,
    output reg [`PA_WIDTH-1:0] pa,
    output reg page_fault,
    output reg access_fault,

    input wire sfence_vma,

    output wire mem_req,
    output wire [`PA_WIDTH-1:0] mem_addr,
    input wire [`PTE_WIDTH-1:0] mem_rdata,
    input wire mem_valid,
    input wire mem_error
);

    localparam [1:0] ST_IDLE = 2'b01;
    localparam [1:0] ST_WALK = 2'b10;

    (* fsm_encoding = "one_hot" *) reg [1:0] state;

    wire [3:0] satp_mode = satp[63:60];
    wire [15:0] satp_asid = satp[59:44];
    wire [`PPN_WIDTH-1:0] satp_ppn = satp[43:0];

    wire translation_en = (satp_mode == 4'd8) && (priv_mode != `PRIV_M);
    wire va_sign_ok = (va[63:39] == {25{va[38]}});

    wire [`VPN_TOTAL_W-1:0] cpu_vpn = va[38:12];

    reg [`VA_WIDTH-1:0] va_reg;
    reg [15:0] asid_reg;
    reg kill_walk;
    wire [`VPN_TOTAL_W-1:0] va_reg_vpn = va_reg[38:12];

    wire tlb_lookup_req = req && translation_en && va_sign_ok && (state == ST_IDLE);
    wire tlb_hit;
    wire [`PPN_WIDTH-1:0] tlb_hit_ppn;
    wire [7:0] tlb_hit_flags;
    wire [1:0] tlb_hit_pgsz;
    wire tlb_write_en;

    wire walk_start;
    wire walk_done;
    wire walk_fault;
    wire walk_access_fault;
    wire [`PPN_WIDTH-1:0] walk_ppn;
    wire [7:0] walk_flags;
    wire [1:0] walk_pgsz;

    mmu64_tlb #(
        .ENTRIES(TLB_ENTRIES)
    ) u_tlb (
        .clk(clk),
        .rst_n(rst_n),
        .lookup_vpn(cpu_vpn),
        .lookup_req(tlb_lookup_req),
        .lookup_asid(satp_asid),
        .lookup_hit(tlb_hit),
        .lookup_ppn(tlb_hit_ppn),
        .lookup_flags(tlb_hit_flags),
        .lookup_page_size(tlb_hit_pgsz),
        .write_en(tlb_write_en),
        .write_vpn(va_reg_vpn),
        .write_ppn(walk_ppn),
        .write_flags(walk_flags),
        .write_page_size(walk_pgsz),
        .write_asid(asid_reg),
        .flush(sfence_vma)
    );

    wire tlb_perm_fault;
    mmu64_perm_check u_tlb_perm (
        .access_type(access_type),
        .priv_mode(priv_mode),
        .pte_r(tlb_hit_flags[`PTE_R]),
        .pte_w(tlb_hit_flags[`PTE_W]),
        .pte_x(tlb_hit_flags[`PTE_X]),
        .pte_u(tlb_hit_flags[`PTE_U]),
        .pte_a(tlb_hit_flags[`PTE_A]),
        .pte_d(tlb_hit_flags[`PTE_D]),
        .mstatus_sum(mstatus_sum),
        .mstatus_mxr(mstatus_mxr),
        .fault(tlb_perm_fault)
    );

    wire [`PA_WIDTH-1:0] tlb_pa;
    assign tlb_pa = (tlb_hit_pgsz == 2'd2) ? {tlb_hit_ppn[43:18], va[29:0]} :
                    (tlb_hit_pgsz == 2'd1) ? {tlb_hit_ppn[43:9],  va[20:0]} :
                                             {tlb_hit_ppn,        va[11:0]};

    assign walk_start = tlb_lookup_req && !tlb_hit;
    assign tlb_write_en = (state == ST_WALK) && walk_done && !kill_walk && !sfence_vma;

    mmu64_walker u_walker (
        .clk(clk),
        .rst_n(rst_n),
        .walk_req(walk_start),
        .vpn(cpu_vpn),
        .access_type(access_type),
        .priv_mode(priv_mode),
        .satp_ppn(satp_ppn),
        .mstatus_sum(mstatus_sum),
        .mstatus_mxr(mstatus_mxr),
        .walk_done(walk_done),
        .walk_fault(walk_fault),
        .walk_access_fault(walk_access_fault),
        .walk_ppn(walk_ppn),
        .walk_flags(walk_flags),
        .walk_page_size(walk_pgsz),
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_valid(mem_valid),
        .mem_error(mem_error)
    );

    wire [`PA_WIDTH-1:0] walk_pa;
    assign walk_pa = (walk_pgsz == 2'd2) ? {walk_ppn[43:18], va_reg[29:0]} :
                     (walk_pgsz == 2'd1) ? {walk_ppn[43:9],  va_reg[20:0]} :
                                           {walk_ppn,        va_reg[11:0]};

    assign ready = (state == ST_IDLE);

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            pa <= {`PA_WIDTH{1'b0}};
            pa_valid <= 1'b0;
            page_fault <= 1'b0;
            access_fault <= 1'b0;
            va_reg <= {`VA_WIDTH{1'b0}};
            asid_reg <= 16'd0;
            kill_walk <= 1'b0;
        end else begin
            pa_valid <= 1'b0;
            page_fault <= 1'b0;
            access_fault <= 1'b0;

            case (state)
                ST_IDLE: begin
                    kill_walk <= 1'b0;
                    if (req) begin
                        va_reg <= va;
                        asid_reg <= satp_asid;
                        if (!translation_en) begin
                            pa <= va[55:0];
                            pa_valid <= 1'b1;
                        end else if (!va_sign_ok) begin
                            page_fault <= 1'b1;
                        end else begin
                            if (tlb_hit) begin
                                if (tlb_perm_fault) page_fault <= 1'b1;
                                else begin
                                    pa <= tlb_pa;
                                    pa_valid <= 1'b1;
                                end
                            end else begin
                                state <= ST_WALK;
                            end
                        end
                    end
                end

                ST_WALK: begin
                    if (sfence_vma) kill_walk <= 1'b1;

                    if (walk_done) begin
                        if (!kill_walk && !sfence_vma) begin
                            pa <= walk_pa;
                            pa_valid <= 1'b1;
                        end
                        state <= ST_IDLE;
                    end else if (walk_access_fault) begin
                        if (!kill_walk && !sfence_vma) access_fault <= 1'b1;
                        state <= ST_IDLE;
                    end else if (walk_fault) begin
                        if (!kill_walk && !sfence_vma) page_fault <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
