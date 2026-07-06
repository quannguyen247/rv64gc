`timescale 1ns / 1ps
`include "mmu64_defs.vh"

module mmu64_impl_wrapper (
    input wire clk,
    input wire rst_n,
    output wire [3:0] debug
);

    reg [63:0] va;
    reg [1:0] access_type;
    reg [1:0] priv_mode;
    reg req;
    wire ready;
    reg [63:0] satp;
    reg mstatus_sum;
    reg mstatus_mxr;
    wire [55:0] pa;
    wire pa_valid;
    wire page_fault;
    reg sfence_vma;
    wire mem_req;
    wire [55:0] mem_addr;
    reg [63:0] mem_rdata;
    reg mem_valid;

    reg [7:0] seq_ctr;
    reg [3:0] va_sel;

    localparam [63:0] SATP_SV39 = {4'd8, 16'd0, 44'h001};

    (* dont_touch = "true" *) mmu64_top #(
        .TLB_ENTRIES(`TLB_ENTRIES)
    ) u_mmu (
        .clk(clk),
        .rst_n(rst_n),
        .va(va),
        .access_type(access_type),
        .priv_mode(priv_mode),
        .req(req),
        .ready(ready),
        .satp(satp),
        .mstatus_sum(mstatus_sum),
        .mstatus_mxr(mstatus_mxr),
        .pa(pa),
        .pa_valid(pa_valid),
        .page_fault(page_fault),
        .sfence_vma(sfence_vma),
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_valid(mem_valid)
    );

    function automatic [63:0] make_pte(
        input [43:0] ppn,
        input r,
        input w,
        input x,
        input u,
        input g,
        input a,
        input d,
        input v
    );
        make_pte = {10'b0, ppn, 2'b00, d, a, g, u, x, w, r, v};
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            seq_ctr <= 8'd0;
            va_sel <= 4'd0;
            va <= 64'd0;
            access_type <= `ACC_LOAD;
            priv_mode <= `PRIV_U;
            req <= 1'b0;
            satp <= SATP_SV39;
            mstatus_sum <= 1'b0;
            mstatus_mxr <= 1'b0;
            sfence_vma <= 1'b0;
        end else begin
            seq_ctr <= seq_ctr + 8'd1;
            req <= 1'b0;
            sfence_vma <= (seq_ctr == 8'h7f);

            if (ready && seq_ctr[1:0] == 2'b00) begin
                va_sel <= va_sel + 4'd1;
                req <= 1'b1;

                case (va_sel[2:0])
                    3'd0: va <= 64'h0000_0000_0000_0000;
                    3'd1: va <= 64'h0000_0000_0000_1000;
                    3'd2: va <= 64'h0000_0000_0020_0000;
                    3'd3: va <= 64'h0000_0000_4010_0000;
                    3'd4: va <= 64'h0000_0000_0000_3000;
                    3'd5: va <= 64'h0000_0000_0000_4000;
                    3'd6: va <= 64'h0000_0000_0000_5000;
                    default: va <= 64'h0000_0000_0000_6000;
                endcase

                case (va_sel[1:0])
                    2'd0: access_type <= `ACC_LOAD;
                    2'd1: access_type <= `ACC_STORE;
                    2'd2: access_type <= `ACC_EXEC;
                    default: access_type <= `ACC_LOAD;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        mem_valid <= 1'b0;
        if (mem_req) begin
            mem_valid <= 1'b1;
            case (mem_addr[15:3])
                13'h200 + 13'd0: mem_rdata <= make_pte(44'h002, 0, 0, 0, 0, 0, 0, 0, 1);
                13'h200 + 13'd1: mem_rdata <= make_pte(44'h00000040000, 1, 1, 1, 1, 0, 1, 1, 1);
                13'h400 + 13'd0: mem_rdata <= make_pte(44'h003, 0, 0, 0, 0, 0, 0, 0, 1);
                13'h400 + 13'd1: mem_rdata <= make_pte(44'h00000000400, 1, 1, 1, 1, 0, 1, 1, 1);
                13'h600 + 13'd0: mem_rdata <= make_pte(44'h00000000800, 1, 1, 1, 1, 0, 1, 1, 1);
                13'h600 + 13'd1: mem_rdata <= make_pte(44'h00000000801, 1, 0, 0, 1, 0, 1, 0, 1);
                13'h600 + 13'd3: mem_rdata <= make_pte(44'h00000000803, 1, 1, 1, 0, 0, 1, 1, 1);
                default: mem_rdata <= 64'd0;
            endcase
        end
    end

    assign debug[0] = ready;
    assign debug[1] = pa_valid;
    assign debug[2] = page_fault;
    assign debug[3] = ^pa ^ mem_req ^ req;

endmodule
