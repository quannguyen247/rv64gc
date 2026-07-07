`timescale 1ns / 1ps
`include "mmu64_defs.vh"

module mmu64_pte_decode (
    input wire [`PTE_WIDTH-1:0] pte_in,
    output wire [`PPN_WIDTH-1:0] ppn,
    output wire [25:0] ppn2,
    output wire [8:0] ppn1,
    output wire [8:0] ppn0,
    output wire valid,
    output wire readable,
    output wire writable,
    output wire executable,
    output wire user_mode,
    output wire global_flag,
    output wire accessed,
    output wire dirty,
    output wire [1:0] rsw,
    output wire [9:0] rsvd_bits,
    output wire is_leaf,
    output wire is_pointer
);

    assign ppn0 = pte_in[`PTE_PPN0];
    assign ppn1 = pte_in[`PTE_PPN1];
    assign ppn2 = pte_in[`PTE_PPN2];
    assign ppn = pte_in[`PTE_PPN];

    assign valid = pte_in[`PTE_V];
    assign readable = pte_in[`PTE_R];
    assign writable = pte_in[`PTE_W];
    assign executable = pte_in[`PTE_X];
    assign user_mode = pte_in[`PTE_U];
    assign global_flag = pte_in[`PTE_G];
    assign accessed = pte_in[`PTE_A];
    assign dirty = pte_in[`PTE_D];

    assign rsw = pte_in[`PTE_RSW];
    assign rsvd_bits = pte_in[`PTE_RSVD];

    assign is_leaf = valid & (readable | executable);
    assign is_pointer = valid & ~readable & ~writable & ~executable;

endmodule
