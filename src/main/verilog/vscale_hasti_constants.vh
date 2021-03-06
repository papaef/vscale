`define HASTI_BUS_WIDTH		32
`define HASTI_BUS_NBYTES	4
`define HASTI_ADDR_WIDTH	32

`define HASTI_TRANS_WIDTH	2
`define HASTI_TRANS_IDLE	`HASTI_TRANS_WIDTH'd0
`define HASTI_TRANS_BUSY	`HASTI_TRANS_WIDTH'd1
`define HASTI_TRANS_NONSEQ	`HASTI_TRANS_WIDTH'd2
`define HASTI_TRANS_SEQ		`HASTI_TRANS_WIDTH'd3

`define HASTI_PROT_WIDTH	4
`define HASTI_NO_PROT		`HASTI_PROT_WIDTH'd0

`define HASTI_BURST_WIDTH	3
`define HASTI_BURST_SINGLE	`HASTI_BURST_WIDTH'd0

`define HASTI_MASTER_NO_LOCK 1'b0

`define HASTI_RESP_WIDTH	1
`define HASTI_RESP_OKAY		`HASTI_RESP_WIDTH'd0
`define HASTI_RESP_ERROR	`HASTI_RESP_WIDTH'd1

`define HASTI_SIZE_WIDTH	3
`define HASTI_SIZE_BYTE		`HASTI_SIZE_WIDTH'd0
`define HASTI_SIZE_HALFWORD	`HASTI_SIZE_WIDTH'd1
`define HASTI_SIZE_WORD		`HASTI_SIZE_WIDTH'd2
