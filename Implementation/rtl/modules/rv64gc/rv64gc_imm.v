`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_imm (
    input wire [31:0] inst,
    input wire [2:0] imm_type,
    output reg [63:0] imm
);

    always @(*) begin
        case (imm_type)
            `IMM_I:  imm = {{52{inst[31]}}, inst[31:20]};
            `IMM_S:  imm = {{52{inst[31]}}, inst[31:25], inst[11:7]};
            `IMM_B:  imm = {{51{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
            `IMM_U:  imm = {{32{inst[31]}}, inst[31:12], 12'd0};
            `IMM_J:  imm = {{43{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
            default: imm = 64'd0;
        endcase
    end

endmodule
