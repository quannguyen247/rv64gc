`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_csr (
    input wire clk,
    input wire rst_n,
    input wire [11:0] addr,
    input wire [63:0] wdata,
    input wire we,
    input wire [1:0] op,
    input wire instret_inc,
    input wire [4:0] fflags_set,
    input wire exception,
    input wire [63:0] exc_cause,
    input wire [63:0] exc_pc,
    output reg [63:0] rdata,
    output wire [63:0] mepc_out,
    output wire [63:0] mtvec_out
);

    reg [63:0] cycle_cnt;
    reg [63:0] instret_cnt;
    reg [63:0] mstatus;
    reg [63:0] mtvec;
    reg [63:0] mscratch;
    reg [63:0] mepc;
    reg [63:0] mcause;
    reg [63:0] mtval;
    reg [2:0]  frm;
    reg [4:0]  fflags;

    assign mepc_out = mepc;
    assign mtvec_out = mtvec;

    wire [63:0] misa = (64'd2 << 62) | (64'd1 << 0) | (64'd1 << 2) | (64'd1 << 3) | (64'd1 << 5) | (64'd1 << 8) | (64'd1 << 12);

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
        case (addr)
            12'h001: rdata = {59'd0, fflags};
            12'h002: rdata = {61'd0, frm};
            12'h003: rdata = {56'd0, frm, fflags};
            12'h300: rdata = mstatus;
            12'h301: rdata = misa;
            12'h305: rdata = mtvec;
            12'h340: rdata = mscratch;
            12'h341: rdata = mepc;
            12'h342: rdata = mcause;
            12'h343: rdata = mtval;
            12'hC00,
            12'hC01: rdata = cycle_cnt;
            12'hC02: rdata = instret_cnt;
            default: rdata = 64'd0;
        endcase
    end

    reg [63:0] next_csr_val;
    always @(*) begin
        case (op)
            2'b01:   next_csr_val = wdata;
            2'b10:   next_csr_val = rdata | wdata;
            2'b11:   next_csr_val = rdata & ~wdata;
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
            frm <= 3'd0;
            fflags <= 5'd0;
        end else begin
            fflags <= fflags | fflags_set;
            if (exception) begin
                mepc <= exc_pc;
                mcause <= exc_cause;
            end else if (we) begin
                case (addr)
                    12'h001: fflags <= next_csr_val[4:0];
                    12'h002: frm <= next_csr_val[2:0];
                    12'h003: begin
                        frm <= next_csr_val[7:5];
                        fflags <= next_csr_val[4:0];
                    end
                    12'h300: mstatus <= next_csr_val;
                    12'h305: mtvec <= next_csr_val;
                    12'h340: mscratch <= next_csr_val;
                    12'h341: mepc <= next_csr_val;
                    12'h342: mcause <= next_csr_val;
                    12'h343: mtval <= next_csr_val;
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
