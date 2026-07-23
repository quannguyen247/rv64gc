`timescale 1ns / 1ps
`include "rv64gc_defs.vh"
`include "mmu64_defs.vh"

module rv64gc_csr (
    input wire clk,
    input wire rst_n,
    input wire [11:0] raddr,
    input wire [11:0] waddr,
    input wire [63:0] wdata,
    input wire we,
    input wire [1:0] op,
    input wire instret_inc,
    input wire [4:0] fflags_set,
    input wire exception,
    input wire [63:0] exc_cause,
    input wire [63:0] exc_pc,
    input wire [63:0] exc_tval,
    input wire mret,
    output reg [63:0] rdata,
    output wire [63:0] mepc_out,
    output wire [63:0] mtvec_out,
    output wire [63:0] satp_out,
    output wire mstatus_sum_out,
    output wire mstatus_mxr_out,
    output wire [1:0] priv_mode_out,
    output wire [2:0] frm_out
);

    reg [63:0] cycle_cnt;
    reg [63:0] instret_cnt;
    reg [63:0] mstatus;
    reg [63:0] mtvec;
    reg [63:0] mscratch;
    reg [63:0] mepc;
    reg [63:0] mcause;
    reg [63:0] mtval;
    reg [63:0] satp;
    reg [2:0] frm;
    reg [4:0] fflags;
    reg [1:0] priv_mode;
    reg [63:0] next_csr_val;

    wire [63:0] misa;

    assign mepc_out = mepc;
    assign mtvec_out = mtvec;
    assign satp_out = satp;
    assign mstatus_sum_out = mstatus[18];
    assign mstatus_mxr_out = mstatus[19];
    assign priv_mode_out = priv_mode;
    assign frm_out = frm;
    assign misa = (64'd2 << 62) | (64'd1 << 0) | (64'd1 << 2) | (64'd1 << 3) |
                  (64'd1 << 5) | (64'd1 << 8) | (64'd1 << 12) | (64'd1 << 18);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 64'd0;
            instret_cnt <= 64'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 64'd1;
            if (instret_inc) begin
                instret_cnt <= instret_cnt + 64'd1;
            end
        end
    end

    always @(*) begin
        case (raddr)
            12'h001: rdata = {59'd0, fflags | fflags_set};
            12'h002: rdata = {61'd0, frm};
            12'h003: rdata = {56'd0, frm, fflags | fflags_set};
            12'h100,
            12'h300: rdata = mstatus;
            12'h301: rdata = misa;
            12'h305: rdata = mtvec;
            12'h340: rdata = mscratch;
            12'h341: rdata = mepc;
            12'h342: rdata = mcause;
            12'h343: rdata = mtval;
            12'h180: rdata = satp;
            12'hC00,
            12'hC01: rdata = cycle_cnt;
            12'hC02: rdata = instret_cnt;
            default: rdata = 64'd0;
        endcase
    end

    always @(*) begin
        case (op)
            2'b01: next_csr_val = wdata;
            2'b10: next_csr_val = rdata | wdata;
            2'b11: next_csr_val = rdata & ~wdata;
            default: next_csr_val = rdata;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 64'd0;
            mtvec <= 64'd0;
            mscratch <= 64'd0;
            mepc <= 64'd0;
            mcause <= 64'd0;
            mtval <= 64'd0;
            satp <= 64'd0;
            frm <= 3'd0;
            fflags <= 5'd0;
            priv_mode <= `PRIV_M;
        end else begin
            fflags <= fflags | fflags_set;
            if (exception) begin
                mepc <= exc_pc;
                mcause <= exc_cause;
                mtval <= exc_tval;
                mstatus[12:11] <= priv_mode;
                mstatus[7] <= mstatus[3];
                mstatus[3] <= 1'b0;
                priv_mode <= `PRIV_M;
            end else if (mret) begin
                priv_mode <= mstatus[12:11];
                mstatus[3] <= mstatus[7];
                mstatus[7] <= 1'b1;
                mstatus[12:11] <= `PRIV_U;
            end else if (we) begin
                case (waddr)
                    12'h001: fflags <= next_csr_val[4:0];
                    12'h002: frm <= next_csr_val[2:0];
                    12'h003: begin
                        frm <= next_csr_val[7:5];
                        fflags <= next_csr_val[4:0];
                    end
                    12'h100,
                    12'h300: mstatus <= next_csr_val;
                    12'h305: mtvec <= next_csr_val;
                    12'h340: mscratch <= next_csr_val;
                    12'h341: mepc <= next_csr_val;
                    12'h342: mcause <= next_csr_val;
                    12'h343: mtval <= next_csr_val;
                    12'h180: satp <= next_csr_val;
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
