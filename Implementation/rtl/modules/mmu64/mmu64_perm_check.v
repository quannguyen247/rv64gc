`timescale 1ns / 1ps
`include "mmu64_defs.vh"

module mmu64_perm_check (
    input wire [1:0] access_type,
    input wire [1:0] priv_mode,
    input wire pte_r,
    input wire pte_w,
    input wire pte_x,
    input wire pte_u,
    input wire pte_a,
    input wire pte_d,
    input wire mstatus_sum,
    input wire mstatus_mxr,
    output wire fault
);

    reg perm_fail;

    always @(*) begin
        perm_fail = 1'b0;

        if (!pte_a) begin
            perm_fail = 1'b1;
        end

        if (access_type == `ACC_STORE && !pte_d) begin
            perm_fail = 1'b1;
        end

        case (priv_mode)
            `PRIV_U: begin
                if (!pte_u) begin
                    perm_fail = 1'b1;
                end
            end
            `PRIV_S: begin
                if (pte_u && !mstatus_sum) begin
                    perm_fail = 1'b1;
                end
                if (pte_u && access_type == `ACC_EXEC) begin
                    perm_fail = 1'b1;
                end
            end
            default: ;
        endcase

        case (access_type)
            `ACC_LOAD: begin
                if (!pte_r && !(mstatus_mxr && pte_x)) begin
                    perm_fail = 1'b1;
                end
            end
            `ACC_STORE: begin
                if (!pte_w) begin
                    perm_fail = 1'b1;
                end
            end
            `ACC_EXEC: begin
                if (!pte_x) begin
                    perm_fail = 1'b1;
                end
            end
            default: perm_fail = 1'b1;
        endcase
    end

    assign fault = perm_fail;

endmodule
