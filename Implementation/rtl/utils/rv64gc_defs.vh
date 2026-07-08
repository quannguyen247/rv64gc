`ifndef RV64GC_DEFS_VH
`define RV64GC_DEFS_VH

`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_SLL  4'd2
`define ALU_SLT  4'd3
`define ALU_SLTU 4'd4
`define ALU_XOR  4'd5
`define ALU_SRL  4'd6
`define ALU_SRA  4'd7
`define ALU_OR   4'd8
`define ALU_AND  4'd9

`define M_MUL    3'd0
`define M_MULH   3'd1
`define M_MULHSU 3'd2
`define M_MULHU  3'd3
`define M_DIV    3'd4
`define M_DIVU   3'd5
`define M_REM    3'd6
`define M_REMU   3'd7

`define IMM_I    3'd0
`define IMM_S    3'd1
`define IMM_B    3'd2
`define IMM_U    3'd3
`define IMM_J    3'd4
`define IMM_CI   3'd5
`define IMM_CSS  3'd6

`define F_ADD    4'd0
`define F_SUB    4'd1
`define F_MUL    4'd2
`define F_DIV    4'd3
`define F_SQRT   4'd4
`define F_SGNJ   4'd5
`define F_MINMAX 4'd6
`define F_CVT    4'd7
`define F_COMP   4'd8
`define F_CLASS  4'd9
`define F_MVTX   4'd10
`define F_MVXT   4'd11

`endif
