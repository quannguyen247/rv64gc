`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_lsu (
    input wire clk,
    input wire rst_n,
    input wire [63:0] addr,
    input wire [63:0] reg_wdata,
    input wire [63:0] fpr_wdata,
    input wire [63:0] mem_rdata,
    input wire [2:0] funct3,
    input wire [4:0] funct5,
    input wire is_atomic,
    input wire is_fp,
    input wire mem_we_ctrl,
    input wire mem_req_ctrl,
    output wire [63:0] mem_addr,
    output reg [63:0] mem_wdata,
    output wire [7:0] mem_be,
    output wire mem_we,
    output wire mem_req,
    output reg [63:0] reg_rdata,
    output reg [63:0] fpr_rdata
);

    reg [7:0] be_gate;
    wire [63:0] shifted_rdata;
    reg [63:0] reservation_addr;
    reg reservation_valid;

    assign mem_addr = addr;
    assign mem_req = mem_req_ctrl;

    always @(*) begin
        case (funct3[1:0])
            2'b00:   be_gate = 8'b00000001;
            2'b01:   be_gate = 8'b00000011;
            2'b10:   be_gate = 8'b00001111;
            2'b11:   be_gate = 8'b11111111;
            default: be_gate = 8'b00000000;
        endcase
    end

    assign mem_be = be_gate << addr[2:0];
    assign shifted_rdata = mem_rdata >> {addr[2:0], 3'b000};

    wire [63:0] loaded_val = (funct3 == 3'b000) ? {{56{shifted_rdata[7]}}, shifted_rdata[7:0]} :
                             (funct3 == 3'b001) ? {{48{shifted_rdata[15]}}, shifted_rdata[15:0]} :
                             (funct3 == 3'b010) ? {{32{shifted_rdata[31]}}, shifted_rdata[31:0]} :
                             (funct3 == 3'b011) ? shifted_rdata :
                             (funct3 == 3'b100) ? {56'd0, shifted_rdata[7:0]} :
                             (funct3 == 3'b101) ? {48'd0, shifted_rdata[15:0]} :
                             (funct3 == 3'b110) ? {32'd0, shifted_rdata[31:0]} :
                             shifted_rdata;

    wire is_lr = is_atomic && (funct5 == 5'b00010);
    wire is_sc = is_atomic && (funct5 == 5'b00011);
    wire sc_success = reservation_valid && (reservation_addr == addr);

    assign mem_we = is_sc ? sc_success : mem_we_ctrl;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reservation_addr <= 64'd0;
            reservation_valid <= 1'b0;
        end else begin
            if (is_lr) begin
                reservation_addr <= addr;
                reservation_valid <= 1'b1;
            end else if (is_sc || (mem_we_ctrl && reservation_valid && (addr == reservation_addr))) begin
                reservation_valid <= 1'b0;
            end
        end
    end

    reg [63:0] amo_out;
    always @(*) begin
        case (funct5)
            5'b00001: amo_out = reg_wdata;
            5'b00000: amo_out = loaded_val + reg_wdata;
            5'b00100: amo_out = loaded_val ^ reg_wdata;
            5'b01100: amo_out = loaded_val & reg_wdata;
            5'b01000: amo_out = loaded_val | reg_wdata;
            5'b10000: amo_out = ($signed(loaded_val) < $signed(reg_wdata)) ? loaded_val : reg_wdata;
            5'b10100: amo_out = ($signed(loaded_val) > $signed(reg_wdata)) ? loaded_val : reg_wdata;
            5'b11000: amo_out = (loaded_val < reg_wdata) ? loaded_val : reg_wdata;
            5'b11100: amo_out = (loaded_val > reg_wdata) ? loaded_val : reg_wdata;
            default:  amo_out = reg_wdata;
        endcase
    end

    wire [63:0] wdata_src = is_fp ? fpr_wdata : (is_atomic && !is_lr && !is_sc) ? amo_out : reg_wdata;

    always @(*) begin
        if (funct3[1:0] == 2'b00) begin
            mem_wdata = {8{wdata_src[7:0]}};
        end else if (funct3[1:0] == 2'b01) begin
            mem_wdata = {4{wdata_src[15:0]}};
        end else if (funct3[1:0] == 2'b10) begin
            mem_wdata = {2{wdata_src[31:0]}};
        end else begin
            mem_wdata = wdata_src;
        end
    end

    always @(*) begin
        reg_rdata = loaded_val;
        fpr_rdata = loaded_val;
        if (is_sc) begin
            reg_rdata = sc_success ? 64'd0 : 64'd1;
        end
    end

endmodule
