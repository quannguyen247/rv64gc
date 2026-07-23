`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_decompress (
    input wire [15:0] inst_in,
    output reg [31:0] inst_out,
    output reg is_compressed
);

    wire [1:0] op = inst_in[1:0];
    wire [2:0] funct3 = inst_in[15:13];
    wire [4:0] rd_rs1_f = inst_in[11:7];
    wire [2:0] rd_rs1_c = inst_in[9:7];
    wire [2:0] rs2_c = inst_in[4:2];
    wire [4:0] rs2_f = inst_in[6:2];

    wire [4:0] reg_c_rd_rs1 = {2'b01, rd_rs1_c};
    wire [4:0] reg_c_rs2 = {2'b01, rs2_c};

    reg [11:0] fsd_imm;
    reg [11:0] sw_imm;
    reg [11:0] sd_imm;
    reg [12:0] b_offset;
    reg [20:0] j_offset;
    reg [11:0] fsdsp_imm;
    reg [11:0] swsp_imm;
    reg [11:0] sdsp_imm;

    always @(*) begin
        fsd_imm   = {4'd0, inst_in[6:5], inst_in[12:10], 3'b000};
        sw_imm    = {5'd0, inst_in[5], inst_in[12:10], inst_in[6], 2'b00};
        sd_imm    = {4'd0, inst_in[6:5], inst_in[12:10], 3'b000};
        b_offset  = {{4{inst_in[12]}}, inst_in[12], inst_in[6:5], inst_in[2], inst_in[11:10], inst_in[4:3], 1'b0};
        j_offset  = {{9{inst_in[12]}}, inst_in[12], inst_in[8], inst_in[10:9], inst_in[6], inst_in[7], inst_in[2], inst_in[11], inst_in[5:3], 1'b0};
        fsdsp_imm = {3'd0, inst_in[9:7], inst_in[12:10], 3'b000};
        swsp_imm  = {4'd0, inst_in[8:7], inst_in[12:9], 2'b00};
        sdsp_imm  = {3'd0, inst_in[9:7], inst_in[12:10], 3'b000};
    end

    always @(*) begin
        inst_out = {16'd0, inst_in};
        is_compressed = 1'b1;

        if (op == 2'b11) begin
            is_compressed = 1'b0;
        end else begin
            case (op)
                2'b00: begin
                    case (funct3)
                        3'b000: begin
                            inst_out = {{2'b00, inst_in[10:7], inst_in[12:11], inst_in[5], inst_in[6], 2'b00}, 5'd2, 3'b000, reg_c_rs2, 7'b0010011};
                        end
                        3'b001: begin
                            inst_out = {{4'd0, inst_in[6:5], inst_in[12:10], 3'b000}, reg_c_rd_rs1, 3'b011, reg_c_rs2, 7'b0000111};
                        end
                        3'b010: begin
                            inst_out = {{5'd0, inst_in[5], inst_in[12:10], inst_in[6], 2'b00}, reg_c_rd_rs1, 3'b010, reg_c_rs2, 7'b0000011};
                        end
                        3'b011: begin
                            inst_out = {{4'd0, inst_in[6:5], inst_in[12:10], 3'b000}, reg_c_rd_rs1, 3'b011, reg_c_rs2, 7'b0000011};
                        end
                        3'b101: begin
                            inst_out = {fsd_imm[11:5], reg_c_rs2, reg_c_rd_rs1, 3'b011, fsd_imm[4:0], 7'b0100111};
                        end
                        3'b110: begin
                            inst_out = {sw_imm[11:5], reg_c_rs2, reg_c_rd_rs1, 3'b010, sw_imm[4:0], 7'b0100011};
                        end
                        3'b111: begin
                            inst_out = {sd_imm[11:5], reg_c_rs2, reg_c_rd_rs1, 3'b011, sd_imm[4:0], 7'b0100011};
                        end
                        default: begin
                            inst_out = 32'h00000013;
                        end
                    endcase
                end

                2'b01: begin
                    case (funct3)
                        3'b000: begin
                            inst_out = {{6{inst_in[12]}}, inst_in[12], inst_in[6:2], rd_rs1_f, 3'b000, rd_rs1_f, 7'b0010011};
                        end
                        3'b001: begin
                            inst_out = {{6{inst_in[12]}}, inst_in[12], inst_in[6:2], rd_rs1_f, 3'b000, rd_rs1_f, 7'b0011011};
                        end
                        3'b010: begin
                            inst_out = {{6{inst_in[12]}}, inst_in[12], inst_in[6:2], 5'd0, 3'b000, rd_rs1_f, 7'b0010011};
                        end
                        3'b011: begin
                            if (rd_rs1_f == 5'd2) begin
                                inst_out = {{2{inst_in[12]}}, inst_in[12], inst_in[4:3], inst_in[5], inst_in[2], inst_in[6], 4'd0, 5'd2, 3'b000, 5'd2, 7'b0010011};
                            end else begin
                                inst_out = {{14{inst_in[12]}}, inst_in[12], inst_in[6:2], rd_rs1_f, 7'b0110111};
                            end
                        end
                        3'b100: begin
                            case (inst_in[11:10])
                                2'b00: begin
                                    inst_out = {6'd0, inst_in[12], inst_in[6:2], reg_c_rd_rs1, 3'b101, reg_c_rd_rs1, 7'b0010011};
                                end
                                2'b01: begin
                                    inst_out = {6'b010000, inst_in[12], inst_in[6:2], reg_c_rd_rs1, 3'b101, reg_c_rd_rs1, 7'b0010011};
                                end
                                2'b10: begin
                                    inst_out = {{6{inst_in[12]}}, inst_in[12], inst_in[6:2], reg_c_rd_rs1, 3'b111, reg_c_rd_rs1, 7'b0010011};
                                end
                                2'b11: begin
                                    case ({inst_in[12], inst_in[6:5]})
                                        3'b000: begin
                                            inst_out = {7'b0100000, reg_c_rs2, reg_c_rd_rs1, 3'b000, reg_c_rd_rs1, 7'b0110011};
                                        end
                                        3'b001: begin
                                            inst_out = {7'b0000000, reg_c_rs2, reg_c_rd_rs1, 3'b100, reg_c_rd_rs1, 7'b0110011};
                                        end
                                        3'b010: begin
                                            inst_out = {7'b0000000, reg_c_rs2, reg_c_rd_rs1, 3'b110, reg_c_rd_rs1, 7'b0110011};
                                        end
                                        3'b011: begin
                                            inst_out = {7'b0000000, reg_c_rs2, reg_c_rd_rs1, 3'b111, reg_c_rd_rs1, 7'b0110011};
                                        end
                                        3'b100: begin
                                            inst_out = {7'b0100000, reg_c_rs2, reg_c_rd_rs1, 3'b000, reg_c_rd_rs1, 7'b0111011};
                                        end
                                        3'b101: begin
                                            inst_out = {7'b0000000, reg_c_rs2, reg_c_rd_rs1, 3'b000, reg_c_rd_rs1, 7'b0111011};
                                        end
                                        default: begin
                                            inst_out = 32'h00000013;
                                        end
                                    endcase
                                end
                            endcase
                        end
                        3'b101: begin
                            inst_out = {j_offset[20], j_offset[10:1], j_offset[11], j_offset[19:12], 5'd0, 7'b1101111};
                        end
                        3'b110: begin
                            inst_out = {b_offset[12], b_offset[10:5], 5'd0, reg_c_rd_rs1, 3'b000, b_offset[4:1], b_offset[11], 7'b1100011};
                        end
                        3'b111: begin
                            inst_out = {b_offset[12], b_offset[10:5], 5'd0, reg_c_rd_rs1, 3'b001, b_offset[4:1], b_offset[11], 7'b1100011};
                        end
                    endcase
                end

                2'b10: begin
                    case (funct3)
                        3'b000: begin
                            inst_out = {7'b0000000, rs2_f, rd_rs1_f, 3'b001, rd_rs1_f, 7'b0010011};
                        end
                        3'b001: begin
                            inst_out = {{3'd0, inst_in[4:2], inst_in[12], inst_in[6:5], 3'b000}, 5'd2, 3'b011, rd_rs1_f, 7'b0000111};
                        end
                        3'b010: begin
                            inst_out = {{4'd0, inst_in[3:2], inst_in[12], inst_in[6:4], 2'b00}, 5'd2, 3'b010, rd_rs1_f, 7'b0000011};
                        end
                        3'b011: begin
                            inst_out = {{3'd0, inst_in[4:2], inst_in[12], inst_in[6:5], 3'b000}, 5'd2, 3'b011, rd_rs1_f, 7'b0000011};
                        end
                        3'b100: begin
                            if (inst_in[12] == 1'b0) begin
                                if (rs2_f == 5'd0) begin
                                    inst_out = {12'd0, rd_rs1_f, 3'b000, 5'd0, 7'b1100111};
                                end else begin
                                    inst_out = {7'b0000000, rs2_f, 5'd0, 3'b000, rd_rs1_f, 7'b0110011};
                                end
                            end else begin
                                if (rs2_f == 5'd0) begin
                                    if (rd_rs1_f == 5'd0) begin
                                        inst_out = 32'h00100073;
                                    end else begin
                                        inst_out = {12'd0, rd_rs1_f, 3'b000, 5'd1, 7'b1100111};
                                    end
                                end else begin
                                    inst_out = {7'b0000000, rs2_f, rd_rs1_f, 3'b000, rd_rs1_f, 7'b0110011};
                                end
                            end
                        end
                        3'b101: begin
                            inst_out = {fsdsp_imm[11:5], rs2_f, 5'd2, 3'b011, fsdsp_imm[4:0], 7'b0100111};
                        end
                        3'b110: begin
                            inst_out = {swsp_imm[11:5], rs2_f, 5'd2, 3'b010, swsp_imm[4:0], 7'b0100011};
                        end
                        3'b111: begin
                            inst_out = {sdsp_imm[11:5], rs2_f, 5'd2, 3'b011, sdsp_imm[4:0], 7'b0100011};
                        end
                    endcase
                end
            endcase
        end
    end

endmodule
