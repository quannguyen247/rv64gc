`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_rf (
    input wire clk,
    input wire rst_n,
    input wire we_gpr,
    input wire we_fpr,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [4:0] frs1,
    input wire [4:0] frs2,
    input wire [4:0] frs3,
    input wire [4:0] frd,
    input wire [63:0] wdata_gpr,
    input wire [63:0] wdata_fpr,
    output wire [63:0] rs1_data,
    output wire [63:0] rs2_data,
    output wire [63:0] frs1_data,
    output wire [63:0] frs2_data,
    output wire [63:0] frs3_data
);

    reg [63:0] gpr [0:31];
    reg [63:0] fpr [0:31];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                gpr[i] <= 64'd0;
                fpr[i] <= 64'd0;
            end
        end else begin
            if (we_gpr && (rd != 5'd0)) begin
                gpr[rd] <= wdata_gpr;
            end
            if (we_fpr) begin
                fpr[frd] <= wdata_fpr;
            end
        end
    end

    assign rs1_data = (rs1 == 5'd0) ? 64'd0 : gpr[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 64'd0 : gpr[rs2];
    assign frs1_data = fpr[frs1];
    assign frs2_data = fpr[frs2];
    assign frs3_data = fpr[frs3];

endmodule
