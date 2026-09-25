module csr_register_bank #(
	parameter int DATA_DEPTH = 32,
	parameter int ADDR_DEPTH = 8
)(
	input	logic aclk,
	input	logic arstn,
	
	input	logic [ADDR_DEPTH-1:0] awaddr,
	input	logic awvalid,
	output	logic awready,
	
	input	logic [DATA_DEPTH-1:0] wdata,
	input	logic wvalid,
	output	logic wready,
	input	logic [(DATA_DEPTH/8)-1:0] wstrb,
	
	output	logic bvalid,
	input	logic bready,
	output	logic [1:0] bresp,
	
	input	logic [ADDR_DEPTH-1:0] araddr,
	input	logic arvalid,
	output	logic arready,
	
	output	logic [DATA_DEPTH-1:0] rdata,
	output	logic rvalid,
	input	logic rready,
	output	logic [1:0] rresp,
	
	// -------------------------------------------------------------------------
	// Internal Hardware Interface (To/From DMA Core)
	// -------------------------------------------------------------------------
	// Control Registers Output to DMA Engine
	output	logic dma_run_stop,
	output	logic dma_reset,
	output	logic dma_sg_en,
	output	logic dma_ioc_irq_en,
	output	logic dma_err_irq_en,
	output	logic [63:0] dma_src_addr,
	output	logic [63:0] dma_dst_addr,
	output	logic [31:0] dma_trsf_len,
	output	logic [63:0] dma_cur_desc,
	output	logic [63:0] dma_tail_desc,
	
	// Status Inputs from DMA Engine
	input		logic hw_dma_halted,
	input		logic hw_dma_idle,
	input		logic hw_ioc_irq_set,
	input		logic hw_err_addr_set,
	input		logic hw_err_align_set
);

typedef enum logic [0:0] {
	RD_IDLE = 1'b0,
	RD_DATA = 1'b1
} rd_state_t;

rd_state_t rd_state, rd_state_n;

logic [DATA_DEPTH-1:0] slv_reg[11];
logic aw_fire, w_fire;
logic ar_fire;
logic b_fire;
logic write_commit;
logic aw_pending, w_pending;
logic [DATA_DEPTH-1:0] wdata_buf;
logic [ADDR_DEPTH-1:0] awaddr_buf;
logic [(DATA_DEPTH/8)-1:0] wstrb_buf;


localparam logic [ADDR_DEPTH-1:2] ADDR_DMA_CR			= 6'h00;
localparam logic [ADDR_DEPTH-1:2] ADDR_DMA_SR			= 6'h01;
localparam logic [ADDR_DEPTH-1:2] ADDR_SRC_ADDR_L		= 6'h02;
localparam logic [ADDR_DEPTH-1:2] ADDR_SRC_ADDR_H		= 6'h03;
localparam logic [ADDR_DEPTH-1:2] ADDR_DST_ADDR_L		= 6'h04;
localparam logic [ADDR_DEPTH-1:2] ADDR_DST_ADDR_H		= 6'h05;
localparam logic [ADDR_DEPTH-1:2] ADDR_TRSF_LEN		= 6'h06;
localparam logic [ADDR_DEPTH-1:2] ADDR_CUR_DESC_L		= 6'h07;
localparam logic [ADDR_DEPTH-1:2] ADDR_CUR_DESC_H		= 6'h08;
localparam logic [ADDR_DEPTH-1:2] ADDR_TAIL_DESC_L	= 6'h09;
localparam logic [ADDR_DEPTH-1:2] ADDR_TAIL_DESC_H	= 6'h0a;

assign bresp = 2'b00;
assign rresp = 2'b00;
assign dma_run_stop		= slv_reg[ADDR_DMA_CR][0];
assign dma_reset			= slv_reg[ADDR_DMA_CR][1];
assign dma_sg_en			= slv_reg[ADDR_DMA_CR][2];
assign dma_ioc_irq_en	= slv_reg[ADDR_DMA_CR][16];
assign dma_err_irq_en	= slv_reg[ADDR_DMA_CR][17];
assign dma_src_addr		= {slv_reg[ADDR_SRC_ADDR_H], slv_reg[ADDR_SRC_ADDR_L]};
assign dma_dst_addr		= {slv_reg[ADDR_DST_ADDR_H], slv_reg[ADDR_DST_ADDR_L]};
assign dma_trsf_len		= slv_reg[ADDR_TRSF_LEN];
assign dma_cur_desc		= {slv_reg[ADDR_CUR_DESC_H], slv_reg[ADDR_CUR_DESC_L]};
assign dma_tail_desc		= {slv_reg[ADDR_TAIL_DESC_H], slv_reg[ADDR_TAIL_DESC_L]};

assign aw_fire = awvalid && awready;
assign w_fire = wvalid && wready;
assign ar_fire = arvalid && arready;
assign r_fire = rvalid && rready;
assign write_commit = aw_pending && w_pending && !bvalid;
assign b_fire = bvalid && bready;

assign awready = !aw_pending && !bvalid;
assign wready = !w_pending && !bvalid;

always_ff @(posedge aclk or negedge arstn) begin
	if(!arstn) begin
		aw_pending <= 1'b0;
		w_pending <= 1'b0;
		awaddr_buf <= '0;
		wdata_buf <= '0;
		wstrb_buf <= '0;
		bvalid <= 1'b0;
		slv_reg <= '{default: '0};
		
	end else begin
		
		if(aw_fire) begin
			awaddr_buf <= awaddr[ADDR_DEPTH-1:2];
			aw_pending <= 1'b1;
		end
		
		if(w_fire) begin
			wdata_buf <= wdata;
			wstrb_buf <= wstrb;
			w_pending <= 1'b1;
		end
		
		// -----------------------------------------------------------------
		// W1C Status Bit Control Logic
		// (Priority: HW Set > SW W1C Clear)
		// -----------------------------------------------------------------
		// 1) IOC IRQ Flag
		if(hw_ioc_irq_set) begin
			slv_reg[ADDR_DMA_SR][12] <= 1'b1;
		end else if(write_commit && awaddr_buf == ADDR_DMA_SR) begin
			if(wstrb_buf[1] && wdata_buf[12]) slv_reg[ADDR_DMA_SR][12] <= 1'b0;
		end
		
		// 2) ERR Addr Flag
		if(hw_err_addr_set) begin
			slv_reg[ADDR_DMA_SR][16] <= 1'b1;
		end else if(write_commit && awaddr_buf == ADDR_DMA_SR) begin
			if(wstrb_buf[2] && wdata_buf[16]) slv_reg[ADDR_DMA_SR][16] <= 1'b0;
		end
		
		// 3) ERR Align Flag
		if(hw_err_align_set) begin
			slv_reg[ADDR_DMA_SR][17] <= 1'b1;
		end else if(write_commit && awaddr_buf == ADDR_DMA_SR) begin
			if(wstrb_buf[2] && wdata_buf[17]) slv_reg[ADDR_DMA_SR][17] <= 1'b0;
		end
		
		if(b_fire) begin
			bvalid <= 1'b0;
		end
		
		if(write_commit) begin
			case(awaddr_buf)
				ADDR_DMA_CR,
				ADDR_SRC_ADDR_L,
				ADDR_SRC_ADDR_H,
				ADDR_DST_ADDR_L,
				ADDR_DST_ADDR_H,
				ADDR_TRSF_LEN,
				ADDR_CUR_DESC_L,
				ADDR_CUR_DESC_H,
				ADDR_TAIL_DESC_L,
				ADDR_TAIL_DESC_H : begin
					for(int i=0; i<4; i++) begin
						if(wstrb_buf[i]) begin
							slv_reg[awaddr_buf][(i*8)+:8] <= wdata_buf[(i*8)+:8];
						end
					end
				end
				default : ;
			endcase
			aw_pending <= 1'b0;
			w_pending <= 1'b0;
			bvalid <= 1'b1;
		end
	end
end





always_ff @(posedge aclk or negedge arstn) begin
	if(!arstn) begin
		rd_state <= RD_IDLE;
		rdata <= '0;
	end else begin
		rd_state <= rd_state_n;

		if(ar_fire) begin
			case(araddr[ADDR_DEPTH-1:2])
				ADDR_DMA_SR : begin
					rdata <= {slv_reg[ADDR_DMA_SR][DATA_DEPTH-1:2], hw_dma_idle, hw_dma_halted};
				end
				ADDR_DMA_CR,
				ADDR_SRC_ADDR_L,
				ADDR_SRC_ADDR_H,
				ADDR_DST_ADDR_L,
				ADDR_DST_ADDR_H,
				ADDR_TRSF_LEN,
				ADDR_CUR_DESC_L,
				ADDR_CUR_DESC_H,
				ADDR_TAIL_DESC_L,
				ADDR_TAIL_DESC_H : begin
					rdata <= slv_reg[araddr[ADDR_DEPTH-1:2]];
				end
				default : rdata <= '0;
			endcase
		end
	end
end
always_comb begin
	rd_state_n = rd_state;
	arready = 1'b0;
	rvalid = 1'b0;
	
	case(rd_state)
		RD_IDLE : begin
			arready = 1'b1;
			if(arvalid) begin
				rd_state_n = RD_DATA;
			end
		end
		RD_DATA : begin
			rvalid = 1'b1;
			if(rready) begin
				rd_state_n = RD_IDLE;
			end
		end
		default : rd_state_n = RD_IDLE;
	endcase
end
endmodule

