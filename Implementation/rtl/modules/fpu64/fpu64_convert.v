`timescale 1ns / 1ps

module fpu64_convert (
    input wire [63:0] rs1,
    input wire [4:0] rs2_val,
    input wire [6:0] funct7,
    output reg [63:0] out_fp,
    output reg [63:0] out_int,
    output reg we_gpr,
    output reg we_fpr
);

    wire [31:0] s1_bits = rs1[31:0];

    shortreal s1_f;
    shortreal res_f;

    real d1_f;
    real res_d;

    reg [31:0] out_int_32;

    always @(*) begin
        s1_f = $bitstoshortreal(s1_bits);
        d1_f = $bitstoreal(rs1);
    end

    always @(*) begin
        out_fp = 64'd0;
        out_int = 64'd0;
        out_int_32 = 32'd0;
        we_gpr = 1'b0;
        we_fpr = 1'b0;

        case (funct7[6:2])
            5'b11000: begin
                we_gpr = 1'b1;
                out_int_32 = $rtoi(s1_f);
                case (rs2_val)
                    5'd0: out_int = {{32{out_int_32[31]}}, out_int_32};
                    5'd1: out_int = {{32{out_int_32[31]}}, out_int_32};
                    5'd2: out_int = $rtoi(s1_f);
                    5'd3: out_int = $rtoi(s1_f);
                    default: out_int = 64'd0;
                endcase
            end
            5'b11001: begin
                we_gpr = 1'b1;
                out_int_32 = $rtoi(d1_f);
                case (rs2_val)
                    5'd0: out_int = {{32{out_int_32[31]}}, out_int_32};
                    5'd1: out_int = {{32{out_int_32[31]}}, out_int_32};
                    5'd2: out_int = $rtoi(d1_f);
                    5'd3: out_int = $rtoi(d1_f);
                    default: out_int = 64'd0;
                endcase
            end
            5'b11010: begin
                we_fpr = 1'b1;
                case (rs2_val)
                    5'd0: res_f = $itor(rs1[31:0]);
                    5'd1: res_f = $itor(rs1[31:0]);
                    5'd2: res_f = $itor(rs1);
                    5'd3: res_f = $itor(rs1);
                    default: res_f = 0.0;
                endcase
                out_fp = {32'hFFFFFFFF, $shortrealtobits(res_f)};
            end
            5'b11011: begin
                we_fpr = 1'b1;
                case (rs2_val)
                    5'd0: res_d = $itor(rs1[31:0]);
                    5'd1: res_d = $itor(rs1[31:0]);
                    5'd2: res_d = $itor(rs1);
                    5'd3: res_d = $itor(rs1);
                    default: res_d = 0.0;
                endcase
                out_fp = $realtobits(res_d);
            end
            5'b01000: begin
                we_fpr = 1'b1;
                res_f = shortreal'(d1_f);
                out_fp = {32'hFFFFFFFF, $shortrealtobits(res_f)};
            end
            5'b01001: begin
                we_fpr = 1'b1;
                res_d = real'(s1_f);
                out_fp = $realtobits(res_d);
            end
            default: begin
            end
        endcase
    end

endmodule
