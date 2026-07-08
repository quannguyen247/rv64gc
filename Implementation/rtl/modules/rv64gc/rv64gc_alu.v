`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_alu (
    input wire [63:0] alu_a,
    input wire [63:0] alu_b,
    input wire [3:0] alu_op,
    input wire is_word,
    output reg [63:0] alu_out
);

    wire [31:0] a32 = alu_a[31:0];
    wire [31:0] b32 = alu_b[31:0];
    wire [5:0] shamt = is_word ? {1'b0, alu_b[4:0]} : alu_b[5:0];

    reg [63:0] alu_out_64;
    reg [31:0] alu_out_32;

    always @(*) begin
        case (alu_op)
            `ALU_ADD:  alu_out_64 = alu_a + alu_b;
            `ALU_SUB:  alu_out_64 = alu_a - alu_b;
            `ALU_SLL:  alu_out_64 = alu_a << shamt;
            `ALU_SLT:  alu_out_64 = ($signed(alu_a) < $signed(alu_b)) ? 64'd1 : 64'd0;
            `ALU_SLTU: alu_out_64 = (alu_a < alu_b) ? 64'd1 : 64'd0;
            `ALU_XOR:  alu_out_64 = alu_a ^ alu_b;
            `ALU_SRL:  alu_out_64 = alu_a >> shamt;
            `ALU_SRA:  alu_out_64 = $unsigned($signed(alu_a) >>> shamt);
            `ALU_OR:   alu_out_64 = alu_a | alu_b;
            `ALU_AND:  alu_out_64 = alu_a & alu_b;
            default:   alu_out_64 = 64'd0;
        endcase
    end

    always @(*) begin
        case (alu_op)
            `ALU_ADD:  alu_out_32 = a32 + b32;
            `ALU_SUB:  alu_out_32 = a32 - b32;
            `ALU_SLL:  alu_out_32 = a32 << shamt[4:0];
            `ALU_SRL:  alu_out_32 = a32 >> shamt[4:0];
            `ALU_SRA:  alu_out_32 = $unsigned($signed(a32) >>> shamt[4:0]);
            default:   alu_out_32 = 32'd0;
        endcase
    end

    always @(*) begin
        if (is_word) begin
            alu_out = {{32{alu_out_32[31]}}, alu_out_32};
        end else begin
            alu_out = alu_out_64;
        end
    end

endmodule
