`timescale 1ns / 1ps
`include "mmu64_defs.vh"

module mmu64_perm_check(
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

        if (!pte_a)
            perm_fail = 1'b1;

        if (access_type == `ACC_STORE && !pte_d)
            perm_fail = 1'b1;

        case (priv_mode)
            `PRIV_U: begin
                if (!pte_u)
                    perm_fail = 1'b1;
            end
            `PRIV_S: begin
                if (pte_u && !mstatus_sum)
                    perm_fail = 1'b1;
                if (pte_u && access_type == `ACC_EXEC)
                    perm_fail = 1'b1;
            end
            default: ;
        endcase

        case (access_type)
            `ACC_LOAD: begin
                if (!pte_r && !(mstatus_mxr && pte_x))
                    perm_fail = 1'b1;
            end
            `ACC_STORE: begin
                if (!pte_w)
                    perm_fail = 1'b1;
            end
            `ACC_EXEC: begin
                if (!pte_x)
                    perm_fail = 1'b1;
            end
            default: perm_fail = 1'b1;
        endcase
    end

    assign fault = perm_fail;

endmodule
