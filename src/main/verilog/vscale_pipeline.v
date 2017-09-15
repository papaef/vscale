`include "vscale_ctrl_constants.vh"
`include "vscale_alu_ops.vh"
`include "rv32_opcodes.vh"
`include "vscale_csr_addr_map.vh"
`include "vscale_md_constants.vh"
`include "vscale_platform_constants.vh"

`ifdef XVEC2
`include "xvec2/xvec2_defines.vh"
`endif

module vscale_pipeline (
		clk,
		ext_interrupts,
		reset,
		imem_wait,
		imem_addr,
		imem_rdata,
		imem_badmem_e,
		dmem_wait,
		dmem_en,
		dmem_wen,
		dmem_size,
		dmem_addr,
		dmem_wdata_delayed,
		dmem_rdata,
		dmem_badmem_e,
		htif_reset,
		htif_pcr_req_valid,
		htif_pcr_req_ready,
		htif_pcr_req_rw,
		htif_pcr_req_addr,
		htif_pcr_req_data,
		htif_pcr_resp_valid,
		htif_pcr_resp_ready,
		htif_pcr_resp_data
	);

	input clk;
	input [`N_EXT_INTS-1:0] ext_interrupts;
	input reset;
	input imem_wait;
	output [`XPR_LEN-1:0] imem_addr;
	input [`XPR_LEN-1:0] imem_rdata;
	input imem_badmem_e;
	input dmem_wait;
	output dmem_en;
	output dmem_wen;
	output [`MEM_TYPE_WIDTH-1:0] dmem_size;
	output [`XPR_LEN-1:0] dmem_addr;
	output [`XPR_LEN-1:0] dmem_wdata_delayed;
	input [`XPR_LEN-1:0] dmem_rdata;
	input dmem_badmem_e;
	input htif_reset;
	input htif_pcr_req_valid;
	output htif_pcr_req_ready;
	input htif_pcr_req_rw;
	input [`CSR_ADDR_WIDTH-1:0] htif_pcr_req_addr;
	input [`HTIF_PCR_WIDTH-1:0] htif_pcr_req_data;
	output htif_pcr_resp_valid;
	input htif_pcr_resp_ready;
	output [`HTIF_PCR_WIDTH-1:0] htif_pcr_resp_data;

	function [`XPR_LEN-1:0] store_data;
		input [`XPR_LEN-1:0] addr;
		input [`XPR_LEN-1:0] data;
		input [`MEM_TYPE_WIDTH-1:0] mem_type;
		begin
			case(mem_type)
				`MEM_TYPE_SB: store_data = {4{data[7:0]}};
				`MEM_TYPE_SH: store_data = {2{data[15:0]}};
				default: store_data = data;
			endcase
		end
	endfunction

	function [`XPR_LEN-1:0] load_data;
		input [`XPR_LEN-1:0] addr;
		input [`XPR_LEN-1:0] data;
		input [`MEM_TYPE_WIDTH-1:0] mem_type;
		reg [`XPR_LEN-1:0] shifted_data;
		reg [`XPR_LEN-1:0] b_extend;
		reg [`XPR_LEN-1:0] h_extend;
		begin
			shifted_data = data >> {addr[1:0], 3'b0};
			b_extend = {{24{shifted_data[7]}}, 8'b0};
			h_extend = {{16{shifted_data[15]}}, 16'b0};
			case(mem_type)
				`MEM_TYPE_LB: load_data = (shifted_data & `XPR_LEN'hff) | b_extend;
				`MEM_TYPE_LH: load_data = (shifted_data & `XPR_LEN'hffff) | h_extend;
				`MEM_TYPE_LBU: load_data = (shifted_data & `XPR_LEN'hff);
				`MEM_TYPE_LHU: load_data = (shifted_data & `XPR_LEN'hffff);
				default: load_data = shifted_data;
			endcase
		end
	endfunction

	wire [`PC_SRC_SEL_WIDTH-1:0] PC_src_sel;
	wire [`XPR_LEN-1:0] PC_PIF;

	reg [`XPR_LEN-1:0] PC_IF;

	wire kill_IF;
	wire stall_IF;

	reg [`XPR_LEN-1:0] PC_DX;
	reg [`INST_WIDTH-1:0] inst_DX;

	wire kill_DX;
	wire stall_DX;
	wire [`IMM_TYPE_WIDTH-1:0] imm_type;
	wire [`XPR_LEN-1:0] imm;
	wire [`SRC_A_SEL_WIDTH-1:0] src_a_sel;
	wire [`SRC_B_SEL_WIDTH-1:0] src_b_sel;
	wire [`REG_ADDR_WIDTH-1:0] rs1_addr;
	wire [`REG_ADDR_WIDTH-1:0] rs2_addr;
	wire [`XPR_LEN-1:0] rs1_data;
	wire [`XPR_LEN-1:0] rs2_data;
	wire [`XPR_LEN-1:0] rs1_data_bypassed;
	wire [`XPR_LEN-1:0] rs2_data_bypassed;
	wire [`ALU_OP_WIDTH-1:0] alu_op;
	wire [`XPR_LEN-1:0] alu_src_a;
	wire [`XPR_LEN-1:0] alu_src_b;
	wire [`XPR_LEN-1:0] alu_out;
	wire cmp_true;
	wire bypass_rs1;
	wire bypass_rs2;
`ifdef XVEC2
	wire xvec2_mode_WB;
	//wire [`SRC_B_SEL_WIDTH-1:0] xvec2_src_b_sel;
	//wire [`VEC_ADDR_WIDTH-1:0] xvec2_rs1_addr;
	//wire [`VEC_ADDR_WIDTH-1:0] xvec2_rs2_addr;
	wire [`VEC_XPR_LEN-1:0] xvec2_rs1_data;
	wire [`VEC_XPR_LEN-1:0] xvec2_rs2_data;
	wire [`VEC_XPR_LEN-1:0] xvec2_rs1_data_bypassed;
	wire [`VEC_XPR_LEN-1:0] xvec2_rs2_data_bypassed;
	//wire [`ALU_OP_WIDTH-1:0] xvec2_alu_op;
	wire [`VEC_XPR_LEN-1:0] xvec2_alu_src_a;
	wire [`VEC_XPR_LEN-1:0] xvec2_alu_src_b;
	wire [`VEC_XPR_LEN-1:0] xvec2_alu_out;
	wire xvec2_bypass_rs1;
	wire xvec2_bypass_rs2;
`endif
	wire [`MEM_TYPE_WIDTH-1:0] dmem_type;

	wire md_req_valid;
	wire md_req_ready;
	wire md_req_in_1_signed;
	wire md_req_in_2_signed;
	wire [`MD_OUT_SEL_WIDTH-1:0] md_req_out_sel;
	wire [`MD_OP_WIDTH-1:0] md_req_op;
	wire md_resp_valid;
	wire [`XPR_LEN-1:0] md_resp_result;

`ifdef XVEC2
	//wire xvec2_md_req_valid;
	wire xvec2_md_req_ready;
	//wire xvec2_md_req_in_1_signed;
	//wire xvec2_md_req_in_2_signed;
	//wire [`MD_OUT_SEL_WIDTH-1:0] xvec2_md_req_out_sel;
	//wire [`MD_OP_WIDTH-1:0] xvec2_md_req_op;
	wire xvec2_md_resp_valid;
	wire [`VEC_XPR_LEN-1:0] xvec2_md_resp_result;
`endif

	reg [`XPR_LEN-1:0] PC_WB;
	reg [`XPR_LEN-1:0] alu_out_WB;
	reg [`XPR_LEN-1:0] csr_rdata_WB;
	reg [`XPR_LEN-1:0] store_data_WB;

`ifdef XVEC2
	reg [`XPR_LEN-1:0] xvec2_store_data_WB;
	reg [`VEC_XPR_LEN-1:0] xvec2_alu_out_WB;
`endif

	wire kill_WB;
	wire stall_WB;
	reg [`XPR_LEN-1:0] bypass_data_WB;
`ifdef XVEC2
	reg [`VEC_XPR_LEN-1:0] xvec2_bypass_data_WB;
`endif
	wire [`XPR_LEN-1:0] load_data_WB;
	reg [`XPR_LEN-1:0] wb_data_WB;
	wire [`REG_ADDR_WIDTH-1:0] reg_to_wr_WB;
	wire wr_reg_WB;
	wire [`WB_SRC_SEL_WIDTH-1:0] wb_src_sel_WB;
`ifdef XVEC2
	reg [`VEC_XPR_LEN-1:0] xvec2_wb_data_WB;
	reg [`VEC_SIZE-1:0] xvec2_wmask;
	//wire [`REG_ADDR_WIDTH-1:0] xvec2_reg_to_wr_WB;
	wire xvec2_wr_reg_WB;
	//wire [`WB_SRC_SEL_WIDTH-1:0] xvec2_wb_src_sel_WB;
`endif
	reg [`MEM_TYPE_WIDTH-1:0] dmem_type_WB;

	//CSR management
	wire [`CSR_ADDR_WIDTH-1:0] csr_addr;
	wire [`CSR_CMD_WIDTH-1:0] csr_cmd;
	wire csr_imm_sel;
	wire [`PRV_WIDTH-1:0] prv;
	wire illegal_csr_access;
	wire interrupt_pending;
	wire interrupt_taken;
	wire [`XPR_LEN-1:0] csr_wdata;
	wire [`XPR_LEN-1:0] csr_rdata;
	wire retire_WB;
	wire exception_WB;
	wire [`ECODE_WIDTH-1:0] exception_code_WB;
	wire [`XPR_LEN-1:0] handler_PC;
	wire eret;
	wire [`XPR_LEN-1:0] epc;

	vscale_ctrl ctrl (
		.clk(clk),
		.reset(reset),
		.inst_DX(inst_DX),
		.imem_wait(imem_wait),
		.imem_badmem_e(imem_badmem_e),
		.dmem_wait(dmem_wait),
		.dmem_badmem_e(dmem_badmem_e),
		.cmp_true(cmp_true),
		.PC_src_sel(PC_src_sel),
		.imm_type(imm_type),
		.src_a_sel(src_a_sel),
		.src_b_sel(src_b_sel),
		.bypass_rs1(bypass_rs1),
		.bypass_rs2(bypass_rs2),
		.alu_op(alu_op),
		.dmem_en(dmem_en),
		.dmem_wen(dmem_wen),
		.dmem_size(dmem_size),
		.dmem_type(dmem_type),
		.md_req_valid(md_req_valid),
		.md_req_ready(md_req_ready),
		.md_req_op(md_req_op),
		.md_req_in_1_signed(md_req_in_1_signed),
		.md_req_in_2_signed(md_req_in_2_signed),
		.md_req_out_sel(md_req_out_sel),
		.md_resp_valid(md_resp_valid),
		.wr_reg_WB(wr_reg_WB),
		.reg_to_wr_WB(reg_to_wr_WB),
		.wb_src_sel_WB(wb_src_sel_WB),
		.stall_IF(stall_IF),
		.kill_IF(kill_IF),
		.stall_DX(stall_DX),
		.kill_DX(kill_DX),
		.stall_WB(stall_WB),
		.kill_WB(kill_WB),
		.exception_WB(exception_WB),
		.exception_code_WB(exception_code_WB),
		.retire_WB(retire_WB),
		.csr_cmd(csr_cmd),
		.csr_imm_sel(csr_imm_sel),
		.illegal_csr_access(illegal_csr_access),
		.interrupt_pending(interrupt_pending),
		.interrupt_taken(interrupt_taken),
		.prv(prv),
		.eret(eret)
`ifdef XVEC2
		,
		.xvec2_mode_WB(xvec2_mode_WB),
		//.xvec2_src_b_sel(xvec2_src_b_sel),
		.xvec2_bypass_rs1(xvec2_bypass_rs1),
		.xvec2_bypass_rs2(xvec2_bypass_rs2),
		//.xvec2_alu_op(xvec2_alu_op),
		//.xvec2_md_req_valid(xvec2_md_req_valid),
		.xvec2_md_req_ready(xvec2_md_req_ready),
		//.xvec2_md_req_op(xvec2_md_req_op),
		//.xvec2_md_req_in_1_signed(xvec2_md_req_in_1_signed),
		//.xvec2_md_req_in_2_signed(xvec2_md_req_in_2_signed),
		//.xvec2_md_req_out_sel(xvec2_md_req_out_sel),
		.xvec2_md_resp_valid(xvec2_md_resp_valid),
		.xvec2_wr_reg_WB(xvec2_wr_reg_WB)
		//.xvec2_reg_to_wr_WB(xvec2_reg_to_wr_WB),
		//.xvec2_wb_src_sel_WB(xvec2_wb_src_sel_WB)
`endif
	);

	vscale_PC_mux PCmux(
		.PC_src_sel(PC_src_sel),
		.inst_DX(inst_DX),
		.rs1_data(rs1_data_bypassed),
		.PC_IF(PC_IF),
		.PC_DX(PC_DX),
		.handler_PC(handler_PC),
		.epc(epc),
		.PC_PIF(PC_PIF)
	);

	assign imem_addr = PC_PIF;

	always @(posedge clk) begin
		if(reset) begin
			PC_IF <= `XPR_LEN'h200;
		end
		else if(~stall_IF) begin
			PC_IF <= PC_PIF;
		end
	end

	always @(posedge clk) begin
		if(reset) begin
			PC_DX <= 0;
			inst_DX <= `RV_NOP;
		end
		else if(~stall_DX) begin
			if(kill_IF) begin
				inst_DX <= `RV_NOP;
			end
			else begin
				PC_DX <= PC_IF;
				inst_DX <= imem_rdata;
			end
		end
	end

	assign rs1_addr = inst_DX[19:15];
	assign rs2_addr = inst_DX[24:20];

	vscale_regfile regfile (
		.clk(clk),
		.ra1(rs1_addr),
		.rd1(rs1_data),
		.ra2(rs2_addr),
		.rd2(rs2_data),
		.wen(wr_reg_WB),
		.wa(reg_to_wr_WB),
		.wd(wb_data_WB)
	);

`ifdef XVEC2
	xvec2_vscale_vecfile xv_vecfile (
		.clk(clk),
		.ra1(rs1_addr),
		.rd1(xvec2_rs1_data),
		.ra2(rs2_addr),
		.rd2(xvec2_rs2_data),
		.wen(xvec2_wr_reg_WB),
		.wa(reg_to_wr_WB),
		.wmask(xvec2_wmask),
		.wd(xvec2_wb_data_WB)
	);
`endif

	vscale_imm_gen imm_gen (
		.inst(inst_DX),
		.imm_type(imm_type),
		.imm(imm)
	);

	vscale_src_a_mux src_a_mux (
		.src_a_sel(src_a_sel),
		.PC_DX(PC_DX),
		.rs1_data(rs1_data_bypassed),
		.alu_src_a(alu_src_a)
	);

	vscale_src_b_mux src_b_mux (
		.src_b_sel(src_b_sel),
		.imm(imm),
		.rs2_data(rs2_data_bypassed),
		.alu_src_b(alu_src_b)
	);

`ifdef XVEC2
	xvec2_vscale_src_a_mux xv_src_a_mux (
		.src_a_sel(2'h0),
		.rs1_data(xvec2_rs1_data_bypassed),
		.alu_src_a(xvec2_alu_src_a)
	);

	xvec2_vscale_src_b_mux xv_src_b_mux (
		//.src_b_sel(xvec2_src_b_sel),
		.src_b_sel(src_b_sel),
		// TODO: make this concat dependable on VEC_WIDTH?
		.imm({imm, imm, imm, imm}),
		.rs2_data(xvec2_rs2_data_bypassed),
		.alu_src_b(xvec2_alu_src_b)
	);
`endif

	assign rs1_data_bypassed = bypass_rs1? bypass_data_WB : rs1_data;
	assign rs2_data_bypassed = bypass_rs2? bypass_data_WB : rs2_data;
`ifdef XVEC2
	assign xvec2_rs1_data_bypassed = xvec2_bypass_rs1? xvec2_bypass_data_WB : xvec2_rs1_data;
	assign xvec2_rs2_data_bypassed = xvec2_bypass_rs2? xvec2_bypass_data_WB : xvec2_rs2_data;
`endif

	vscale_alu alu (
		.op(alu_op),
		.in1(alu_src_a),
		.in2(alu_src_b),
		.out(alu_out)
	);

	vscale_mul_div md (
		.clk(clk),
		.reset(reset),
		.req_valid(md_req_valid),
		.req_ready(md_req_ready),
		.req_in_1_signed(md_req_in_1_signed),
		.req_in_2_signed(md_req_in_2_signed),
		.req_out_sel(md_req_out_sel),
		.req_op(md_req_op),
		.req_in_1(rs1_data_bypassed),
		.req_in_2(rs2_data_bypassed),
		.resp_valid(md_resp_valid),
		.resp_result(md_resp_result)
	);

`ifdef XVEC2
	xvec2_vscale_alu xv_alu (
		//.op(xvec2_alu_op),
		.op(alu_op),
		.in1(xvec2_alu_src_a),
		.in2(xvec2_alu_src_b),
		.out(xvec2_alu_out)
	);

	xvec2_vscale_mul_div xv_md (
		.clk(clk),
		.reset(reset),
		//.req_valid(xvec2_md_req_valid),
		.req_valid(md_req_valid),
		//.req_ready(xvec2_md_req_ready),
		.req_ready(xvec2_md_req_ready),
		//.req_in_1_signed(xvec2_md_req_in_1_signed),
		//.req_in_2_signed(xvec2_md_req_in_2_signed),
		.req_in_1_signed(md_req_in_1_signed),
		.req_in_2_signed(md_req_in_2_signed),
		//.req_out_sel(xvec2_md_req_out_sel),
		.req_out_sel(md_req_out_sel),
		//.req_op(xvec2_md_req_op),
		.req_op(md_req_op),
		.req_in_1(xvec2_rs1_data_bypassed),
		.req_in_2(xvec2_rs2_data_bypassed),
		.resp_valid(xvec2_md_resp_valid),
		.resp_result(xvec2_md_resp_result)
	);
`endif

	assign cmp_true = alu_out[0];

	assign dmem_addr = alu_out;

	always @(posedge clk) begin
		if(reset) begin
`ifndef SYNTHESIS
			PC_WB <= $random;
			store_data_WB <= $random;
			alu_out_WB <= $random;
`ifdef XVEC2
			xvec2_store_data_WB <= $random;
			xvec2_alu_out_WB <= $random;
`endif
`endif
		end
		else if(~stall_WB) begin
			PC_WB <= PC_DX;
			store_data_WB <= rs2_data_bypassed;
`ifdef XVEC2
			// TODO: logic operations could be used instead of modulo and product
			xvec2_store_data_WB <= xvec2_rs2_data_bypassed >> ((rs2_addr % `VEC_SIZE) * `XPR_LEN);
`endif
			alu_out_WB <= alu_out;
			csr_rdata_WB <= csr_rdata;
			dmem_type_WB <= dmem_type;
`ifdef XVEC2
			xvec2_alu_out_WB <= xvec2_alu_out;
`endif
		end
	end

	always @(*) begin
		case(wb_src_sel_WB)
			`WB_SRC_CSR: bypass_data_WB = csr_rdata_WB;
			`WB_SRC_MD: bypass_data_WB = md_resp_result;
			default: bypass_data_WB = alu_out_WB;
		endcase

`ifdef XVEC2
		case(wb_src_sel_WB)
			//`WB_SRC_CSR: xvec2_bypass_data_WB = csr_rdata_WB;
			`WB_SRC_MD: xvec2_bypass_data_WB = xvec2_md_resp_result;
			default: xvec2_bypass_data_WB = xvec2_alu_out_WB;
		endcase
`endif
	end

	assign load_data_WB = load_data(alu_out_WB, dmem_rdata, dmem_type_WB);

	always @(*) begin
		case(wb_src_sel_WB)
			`WB_SRC_ALU: wb_data_WB = bypass_data_WB;
			`WB_SRC_MEM: wb_data_WB = load_data_WB;
			`WB_SRC_CSR: wb_data_WB = bypass_data_WB;
			`WB_SRC_MD: wb_data_WB = bypass_data_WB;
			default: wb_data_WB = bypass_data_WB;
		endcase

`ifdef XVEC2
		case(wb_src_sel_WB)
			`WB_SRC_ALU:
				begin
					xvec2_wb_data_WB = xvec2_bypass_data_WB;
					xvec2_wmask = `VEC_SIZE'hf;
				end
			`WB_SRC_MEM:
				begin
					// TODO: logic operations could be used instead of modulo and product
					xvec2_wb_data_WB = load_data_WB << ((reg_to_wr_WB % `VEC_SIZE) * `XPR_LEN);
					xvec2_wmask = 1 << (reg_to_wr_WB % `VEC_SIZE);
				end
			//`WB_SRC_CSR: wb_data_WB = bypass_data_WB;
			`WB_SRC_MD:
				begin
					xvec2_wb_data_WB = xvec2_bypass_data_WB;
					xvec2_wmask = `VEC_SIZE'hf;
				end
			default:
				begin
					xvec2_wb_data_WB = xvec2_bypass_data_WB;
					xvec2_wmask = `VEC_SIZE'hf;
				end
		endcase
`endif
	end

`ifndef XVEC2
	assign dmem_wdata_delayed = store_data(alu_out_WB, store_data_WB, dmem_type_WB);
`else
	assign dmem_wdata_delayed = xvec2_mode_WB?
		store_data(alu_out_WB, xvec2_store_data_WB, dmem_type_WB) :
		store_data(alu_out_WB, store_data_WB, dmem_type_WB);
`endif

	// CSR
	assign csr_addr = inst_DX[31:20];
	assign csr_wdata = (csr_imm_sel) ? inst_DX[19:15] : rs1_data_bypassed;

	vscale_csr_file csr(
		.clk(clk),
		.ext_interrupts(ext_interrupts),
		.reset(reset),
		.addr(csr_addr),
		.cmd(csr_cmd),
		.wdata(csr_wdata),
		.prv(prv),
		.illegal_access(illegal_csr_access),
		.rdata(csr_rdata),
		.retire(retire_WB),
		.exception(exception_WB),
		.exception_code(exception_code_WB),
		.exception_load_addr(alu_out_WB),
		.exception_PC(PC_WB),
		.epc(epc),
		.eret(eret),
		.handler_PC(handler_PC),
		.interrupt_pending(interrupt_pending),
		.interrupt_taken(interrupt_taken),
		.htif_reset(htif_reset),
		.htif_pcr_req_valid(htif_pcr_req_valid),
		.htif_pcr_req_ready(htif_pcr_req_ready),
		.htif_pcr_req_rw(htif_pcr_req_rw),
		.htif_pcr_req_addr(htif_pcr_req_addr),
		.htif_pcr_req_data(htif_pcr_req_data),
		.htif_pcr_resp_valid(htif_pcr_resp_valid),
		.htif_pcr_resp_ready(htif_pcr_resp_ready),
		.htif_pcr_resp_data(htif_pcr_resp_data)
	);

endmodule
