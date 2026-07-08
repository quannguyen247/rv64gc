`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_ctrl (
    input wire [31:0] inst,
    output reg rf_we_gpr,
    output reg rf_we_fpr,
    output reg [2:0] imm_type,
    output reg src_b_sel,
    output reg [3:0] alu_op,
    output reg is_word,
    output reg mem_we,
    output reg mem_req,
    output reg [2:0] wb_sel,
    output reg is_jal,
    output reg is_jalr,
    output reg is_branch,
    output reg is_atomic,
    output reg is_fp,
    output reg [3:0] fpu_op,
    output reg fpu_is_double,
    output reg csr_we,
    output reg [1:0] csr_op,
    output reg is_csr_imm,
    output reg is_muldiv,
    output reg [2:0] muldiv_op,
    output reg halt
);

    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];
    wire [4:0] funct5 = inst[31:27];

    always @(*) begin
        rf_we_gpr = 1'b0;
        rf_we_fpr = 1'b0;
        imm_type = `IMM_I;
        src_b_sel = 1'b0;
        alu_op = `ALU_ADD;
        is_word = 1'b0;
        mem_we = 1'b0;
        mem_req = 1'b0;
        wb_sel = 3'd0;
        is_jal = 1'b0;
        is_jalr = 1'b0;
        is_branch = 1'b0;
        is_atomic = 1'b0;
        is_fp = 1'b0;
        fpu_op = `F_ADD;
        fpu_is_double = 1'b0;
        csr_we = 1'b0;
        csr_op = 2'b00;
        is_csr_imm = 1'b0;
        is_muldiv = 1'b0;
        muldiv_op = 3'd0;
        halt = (inst == 32'h00000073) || (inst == 32'h00100073);

        case (opcode)
            7'b0110111: begin
                rf_we_gpr = 1'b1;
                imm_type = `IMM_U;
                wb_sel = 3'd4;
            end
            7'b0010111: begin
                rf_we_gpr = 1'b1;
                imm_type = `IMM_U;
                wb_sel = 3'd3;
            end
            7'b1101111: begin
                rf_we_gpr = 1'b1;
                imm_type = `IMM_J;
                wb_sel = 3'd2;
                is_jal = 1'b1;
            end
            7'b1100111: begin
                rf_we_gpr = 1'b1;
                imm_type = `IMM_I;
                src_b_sel = 1'b1;
                wb_sel = 3'd2;
                is_jalr = 1'b1;
            end
            7'b1100011: begin
                imm_type = `IMM_B;
                is_branch = 1'b1;
            end
            7'b0000011: begin
                rf_we_gpr = 1'b1;
                imm_type = `IMM_I;
                src_b_sel = 1'b1;
                mem_req = 1'b1;
                wb_sel = 3'd1;
            end
            7'b0100011: begin
                imm_type = `IMM_S;
                src_b_sel = 1'b1;
                mem_we = 1'b1;
                mem_req = 1'b1;
            end
            7'b0010011: begin
                rf_we_gpr = 1'b1;
                imm_type = `IMM_I;
                src_b_sel = 1'b1;
                case (funct3)
                    3'b000:  alu_op = `ALU_ADD;
                    3'b010:  alu_op = `ALU_SLT;
                    3'b011:  alu_op = `ALU_SLTU;
                    3'b100:  alu_op = `ALU_XOR;
                    3'b110:  alu_op = `ALU_OR;
                    3'b111:  alu_op = `ALU_AND;
                    3'b001:  alu_op = `ALU_SLL;
                    3'b101:  alu_op = inst[30] ? `ALU_SRA : `ALU_SRL;
                    default: alu_op = `ALU_ADD;
                endcase
            end
            7'b0110011: begin
                if (funct7 == 7'b0000001) begin
                    rf_we_gpr = 1'b1;
                    is_muldiv = 1'b1;
                    muldiv_op = funct3;
                end else begin
                    rf_we_gpr = 1'b1;
                    case (funct3)
                        3'b000:  alu_op = inst[30] ? `ALU_SUB : `ALU_ADD;
                        3'b001:  alu_op = `ALU_SLL;
                        3'b010:  alu_op = `ALU_SLT;
                        3'b011:  alu_op = `ALU_SLTU;
                        3'b100:  alu_op = `ALU_XOR;
                        3'b101:  alu_op = inst[30] ? `ALU_SRA : `ALU_SRL;
                        3'b110:  alu_op = `ALU_OR;
                        3'b111:  alu_op = `ALU_AND;
                        default: alu_op = `ALU_ADD;
                    endcase
                end
            end
            7'b0011011: begin
                rf_we_gpr = 1'b1;
                imm_type = `IMM_I;
                src_b_sel = 1'b1;
                is_word = 1'b1;
                case (funct3)
                    3'b000:  alu_op = `ALU_ADD;
                    3'b001:  alu_op = `ALU_SLL;
                    3'b101:  alu_op = inst[30] ? `ALU_SRA : `ALU_SRL;
                    default: alu_op = `ALU_ADD;
                endcase
            end
            7'b0111011: begin
                if (funct7 == 7'b0000001) begin
                    rf_we_gpr = 1'b1;
                    is_muldiv = 1'b1;
                    muldiv_op = funct3;
                    is_word = 1'b1;
                end else begin
                    rf_we_gpr = 1'b1;
                    is_word = 1'b1;
                    case (funct3)
                        3'b000:  alu_op = inst[30] ? `ALU_SUB : `ALU_ADD;
                        3'b001:  alu_op = `ALU_SLL;
                        3'b101:  alu_op = inst[30] ? `ALU_SRA : `ALU_SRL;
                        default: alu_op = `ALU_ADD;
                    endcase
                end
            end
            7'b0101111: begin
                rf_we_gpr = 1'b1;
                is_atomic = 1'b1;
                if (funct5 == 5'b00010) begin
                    mem_req = 1'b1;
                    wb_sel = 3'd1;
                end else if (funct5 == 5'b00011) begin
                    mem_req = 1'b1;
                    mem_we = 1'b1;
                    wb_sel = 3'd1;
                end else begin
                    mem_req = 1'b1;
                    mem_we = 1'b1;
                    wb_sel = 3'd1;
                end
            end
            7'b0000111: begin
                rf_we_fpr = 1'b1;
                imm_type = `IMM_I;
                src_b_sel = 1'b1;
                mem_req = 1'b1;
                wb_sel = 3'd5;
                is_fp = 1'b1;
                fpu_is_double = (funct3 == 3'b011);
            end
            7'b0100111: begin
                imm_type = `IMM_S;
                src_b_sel = 1'b1;
                mem_we = 1'b1;
                mem_req = 1'b1;
                is_fp = 1'b1;
                fpu_is_double = (funct3 == 3'b011);
            end
            7'b1010011: begin
                fpu_is_double = (inst[25] == 1'b1);
                case (funct7[6:2])
                    5'b00000: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_ADD;
                        wb_sel = 3'd5;
                    end
                    5'b00001: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_SUB;
                        wb_sel = 3'd5;
                    end
                    5'b00010: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_MUL;
                        wb_sel = 3'd5;
                    end
                    5'b00011: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_DIV;
                        wb_sel = 3'd5;
                    end
                    5'b01011: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_SQRT;
                        wb_sel = 3'd5;
                    end
                    5'b00100: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_SGNJ;
                        wb_sel = 3'd5;
                    end
                    5'b00101: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_MINMAX;
                        wb_sel = 3'd5;
                    end
                    5'b11000: begin
                        rf_we_gpr = 1'b1;
                        fpu_op = `F_CVT;
                        wb_sel = 3'd7;
                    end
                    5'b11010: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_CVT;
                        wb_sel = 3'd5;
                    end
                    5'b10100: begin
                        rf_we_gpr = 1'b1;
                        fpu_op = `F_COMP;
                        wb_sel = 3'd7;
                    end
                    5'b11100: begin
                        rf_we_gpr = 1'b1;
                        fpu_op = (funct3 == 3'b000) ? (inst[20] ? `F_MVTX : `F_CLASS) : `F_MVTX;
                        wb_sel = 3'd7;
                    end
                    5'b11110: begin
                        rf_we_fpr = 1'b1;
                        fpu_op = `F_MVXT;
                        wb_sel = 3'd5;
                    end
                    default: begin
                    end
                endcase
            end
            7'b1110011: begin
                if (funct3 != 3'b000) begin
                    rf_we_gpr = 1'b1;
                    csr_we = 1'b1;
                    csr_op = funct3[1:0];
                    is_csr_imm = funct3[2];
                    wb_sel = 3'd6;
                end
            end
            default: begin
            end
        endcase
    end

endmodule
