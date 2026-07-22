`timescale 1ns / 1ps
`include "mmu64_defs.vh"

module mmu64_tlb #(
    parameter ENTRIES = `TLB_ENTRIES
)(
    input wire clk,
    input wire rst_n,

    input wire [`VPN_TOTAL_W-1:0] lookup_vpn,
    input wire lookup_req,
    input wire [15:0] lookup_asid,
    output wire lookup_hit,
    output reg [`PPN_WIDTH-1:0] lookup_ppn,
    output reg [7:0] lookup_flags,
    output reg [1:0] lookup_page_size,

    input wire write_en,
    input wire [`VPN_TOTAL_W-1:0] write_vpn,
    input wire [`PPN_WIDTH-1:0] write_ppn,
    input wire [7:0] write_flags,
    input wire [1:0] write_page_size,
    input wire [15:0] write_asid,

    input wire flush
);

    wire [ENTRIES-1:0] entry_valid;
    wire [ENTRIES-1:0] match;
    wire [ENTRIES*`PPN_WIDTH-1:0] entry_ppn_flat;
    wire [ENTRIES*8-1:0] entry_flags_flat;
    wire [ENTRIES*2-1:0] entry_pgsz_flat;

    localparam integer IDX_W = (ENTRIES > 1) ? $clog2(ENTRIES) : 1;
    localparam [IDX_W-1:0] LAST_IDX = ENTRIES - 1;

    reg [IDX_W-1:0] rr_ctr;
    reg [IDX_W-1:0] replace_idx;

    integer lookup_i;
    integer replace_i;

    genvar g;
    generate
        for (g = 0; g < ENTRIES; g = g + 1) begin : g_entry
            mmu64_tlb_entry u_entry (
                .clk(clk),
                .rst_n(rst_n),
                .flush(flush),
                .lookup_vpn(lookup_vpn),
                .lookup_asid(lookup_asid),
                .match(match[g]),
                .entry_valid(entry_valid[g]),
                .entry_ppn(entry_ppn_flat[g*`PPN_WIDTH +: `PPN_WIDTH]),
                .entry_flags(entry_flags_flat[g*8 +: 8]),
                .entry_page_size(entry_pgsz_flat[g*2 +: 2]),
                .write_en(write_en && (replace_idx == g)),
                .write_vpn(write_vpn),
                .write_ppn(write_ppn),
                .write_flags(write_flags),
                .write_page_size(write_page_size),
                .write_asid(write_asid)
            );
        end
    endgenerate

    assign lookup_hit = lookup_req && (|match);

    always @(*) begin
        lookup_ppn = {`PPN_WIDTH{1'b0}};
        lookup_flags = 8'h0;
        lookup_page_size = 2'b00;

        for (lookup_i = ENTRIES - 1; lookup_i >= 0; lookup_i = lookup_i - 1) begin
            if (match[lookup_i]) begin
                lookup_ppn = entry_ppn_flat[lookup_i*`PPN_WIDTH +: `PPN_WIDTH];
                lookup_flags = entry_flags_flat[lookup_i*8 +: 8];
                lookup_page_size = entry_pgsz_flat[lookup_i*2 +: 2];
            end
        end
    end

    always @(*) begin
        replace_idx = rr_ctr;
        for (replace_i = ENTRIES - 1; replace_i >= 0; replace_i = replace_i - 1) begin
            if (!entry_valid[replace_i]) replace_idx = replace_i[IDX_W-1:0];
        end
    end

    always @(posedge clk) begin
        if (!rst_n || flush) begin
            rr_ctr <= {IDX_W{1'b0}};
        end else if (write_en) begin
            if (rr_ctr == LAST_IDX) rr_ctr <= {IDX_W{1'b0}};
            else rr_ctr <= rr_ctr + 1'b1;
        end
    end

endmodule

module mmu64_tlb_entry(
    input wire clk,
    input wire rst_n,
    input wire flush,

    input wire [`VPN_TOTAL_W-1:0] lookup_vpn,
    input wire [15:0] lookup_asid,
    output wire match,
    output wire entry_valid,
    output wire [`PPN_WIDTH-1:0] entry_ppn,
    output wire [7:0] entry_flags,
    output wire [1:0] entry_page_size,

    input wire write_en,
    input wire [`VPN_TOTAL_W-1:0] write_vpn,
    input wire [`PPN_WIDTH-1:0] write_ppn,
    input wire [7:0] write_flags,
    input wire [1:0] write_page_size,
    input wire [15:0] write_asid
);

    reg valid_q;
    reg [`VPN_TOTAL_W-1:0] vpn_q;
    reg [`PPN_WIDTH-1:0] ppn_q;
    reg [7:0] flags_q;
    reg [1:0] pgsz_q;
    reg [15:0] asid_q;
    reg vpn_match;
    wire asid_match;

    assign entry_valid = valid_q;
    assign entry_ppn = ppn_q;
    assign entry_flags = flags_q;
    assign entry_page_size = pgsz_q;

    always @(*) begin
        case (pgsz_q)
            2'd0: vpn_match = (vpn_q == lookup_vpn);
            2'd1: vpn_match = (vpn_q[26:9] == lookup_vpn[26:9]);
            2'd2: vpn_match = (vpn_q[26:18] == lookup_vpn[26:18]);
            default: vpn_match = 1'b0;
        endcase
    end

    assign asid_match = flags_q[`PTE_G] || (asid_q == lookup_asid);
    assign match = valid_q && asid_match && vpn_match;

    always @(posedge clk) begin
        if (!rst_n || flush) begin
            valid_q <= 1'b0;
        end else if (write_en) begin
            valid_q <= 1'b1;
            vpn_q <= write_vpn;
            ppn_q <= write_ppn;
            flags_q <= write_flags;
            pgsz_q <= write_page_size;
            asid_q <= write_asid;
        end
    end

endmodule
