`ifndef MMU64_DEFS
`define MMU64_DEFS

`define VA_WIDTH        64
`define PA_WIDTH        56
`define PAGE_OFFSET_W   12
`define VPN_FIELD_W     9
`define VPN_TOTAL_W     27
`define PTE_WIDTH       64
`define PPN_WIDTH       44
`define SATP_WIDTH      64

`define PTE_V           0
`define PTE_R           1
`define PTE_W           2
`define PTE_X           3
`define PTE_U           4
`define PTE_G           5
`define PTE_A           6
`define PTE_D           7

`define PTE_RSW         9:8
`define PTE_PPN0        18:10
`define PTE_PPN1        27:19
`define PTE_PPN2        53:28
`define PTE_PPN         53:10
`define PTE_RSVD        63:54

`define ACC_LOAD        2'b00
`define ACC_STORE       2'b01
`define ACC_EXEC        2'b10

`define PRIV_U          2'b00
`define PRIV_S          2'b01
`define PRIV_M          2'b11

`define TLB_ENTRIES     16
`define TLB_IDX_W       4

`define SATP_MODE       63:60
`define SATP_ASID       59:44
`define SATP_PPN        43:0

`define SATP_MODE_BARE  4'd0
`define SATP_MODE_SV39  4'd8

`endif
