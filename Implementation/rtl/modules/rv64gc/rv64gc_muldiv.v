`timescale 1ns / 1ps
`include "rv64gc_defs.vh"

module rv64gc_muldiv (
    input wire [63:0] a,
    input wire [63:0] b,
    input wire [2:0] op,
    input wire is_word,
    output reg [63:0] out
);

    wire [31:0] a32 = a[31:0];
    wire [31:0] b32 = b[31:0];

    reg [127:0] mul_64;
    reg [63:0] div_64;
    reg [63:0] rem_64;
    reg [63:0] mul_32;
    reg [31:0] div_32;
    reg [31:0] rem_32;

    always @(*) begin
        case (op)
            `M_MUL: begin
                mul_64 = a * b;
            end
            `M_MULH: begin
                mul_64 = $signed(a) * $signed(b);
            end
            `M_MULHSU: begin
                mul_64 = $signed(a) * $signed({1'b0, b});
            end
            `M_MULHU: begin
                mul_64 = a * b;
            end
            default: mul_64 = 128'd0;
        endcase
    end

    always @(*) begin
        if (b == 64'd0) begin
            div_64 = 64'hFFFFFFFFFFFFFFFF;
            rem_64 = a;
        end else if (a == 64'h8000000000000000 && b == 64'hFFFFFFFFFFFFFFFF) begin
            div_64 = 64'h8000000000000000;
            rem_64 = 64'd0;
        end else begin
            case (op)
                `M_DIV:  div_64 = $signed(a) / $signed(b);
                `M_DIVU: div_64 = a / b;
                `M_REM:  rem_64 = $signed(a) % $signed(b);
                `M_REMU: rem_64 = a % b;
                default: begin
                    div_64 = 64'd0;
                    rem_64 = 64'd0;
                end
            endcase
        end
    end

    always @(*) begin
        mul_32 = $signed(a32) * $signed(b32);
    end

    always @(*) begin
        if (b32 == 32'd0) begin
            div_32 = 32'hFFFFFFFF;
            rem_32 = a32;
        end else if (a32 == 32'h80000000 && b32 == 32'hFFFFFFFF) begin
            div_32 = 32'h80000000;
            rem_32 = 32'd0;
        end else begin
            case (op)
                `M_DIV:  div_32 = $signed(a32) / $signed(b32);
                `M_DIVU: div_32 = a32 / b32;
                `M_REM:  rem_32 = $signed(a32) % $signed(b32);
                `M_REMU: rem_32 = a32 % b32;
                default: begin
                    div_32 = 32'd0;
                    rem_32 = 32'd0;
                end
            endcase
        end
    end

    always @(*) begin
        if (is_word) begin
            case (op)
                `M_MUL:  out = {{32{mul_32[31]}}, mul_32[31:0]};
                `M_DIV:  out = {{32{div_32[31]}}, div_32};
                `M_DIVU: out = {{32{div_32[31]}}, div_32};
                `M_REM:  out = {{32{rem_32[31]}}, rem_32};
                `M_REMU: out = {{32{rem_32[31]}}, rem_32};
                default: out = 64'd0;
            endcase
        end else begin
            case (op)
                `M_MUL:    out = mul_64[63:0];
                `M_MULH:   out = mul_64[127:64];
                `M_MULHSU: out = mul_64[127:64];
                `M_MULHU:  out = mul_64[127:64];
                `M_DIV,
                `M_DIVU:   out = div_64;
                `M_REM,
                `M_REMU:   out = rem_64;
                default:   out = 64'd0;
            endcase
        end
    end

endmodule
