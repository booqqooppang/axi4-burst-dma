module simple_dma_axi_burst #(
	parameter int BYTES_PER_BEAT = 4,
	parameter int BURST_BEATS = 4
)(
	input	logic		clk,
	input	logic		rstn,
	input	logic		dma_run_stop,
	input	logic		dma_reset,
	input	logic		dma_sg_en,

	input	logic	[63:0]	dma_src_addr,
	input	logic	[63:0]	dma_dst_addr,
	input	logic	[31:0]	dma_trsf_len,
	
	output	logic		hw_dma_halted,
	output	logic		hw_dma_idle,
	output	logic		hw_ioc_irq_set,
	output	logic		hw_err_addr_set,
	output	logic		hw_err_align_set,
	output	logic		hw_err_axi_set,
	
	// Read Address
	output	logic	[31:0]	m_axi_araddr,
	output	logic	[7:0]	m_axi_arlen,
	output	logic	[2:0]	m_axi_arsize,
	output	logic	[1:0]	m_axi_arburst,
	output	logic		m_axi_arvalid,
	input	logic		m_axi_arready,
	
	// Read Data
	input	logic	[31:0]	m_axi_rdata,
	input	logic	[1:0]	m_axi_rresp,
	input	logic		m_axi_rlast,
	input	logic		m_axi_rvalid,
	output	logic		m_axi_rready,
	
	// Write Address
	output	logic	[31:0]	m_axi_awaddr,
	output	logic	[7:0]	m_axi_awlen,
	output	logic	[2:0]	m_axi_awsize,
	output	logic	[1:0]	m_axi_awburst,
	output	logic		m_axi_awvalid,
	input	logic		m_axi_awready,
	
	// Write Data
	output	logic	[31:0]	m_axi_wdata,
	output	logic	[3:0]	m_axi_wstrb,
	output	logic		m_axi_wlast,
	output	logic		m_axi_wvalid,
	input	logic		m_axi_wready,
	
	// Write Response
	input	logic	[1:0]	m_axi_bresp,
	input	logic		m_axi_bvalid,
	output	logic		m_axi_bready

);

typedef enum logic[3:0]{
	IDLE = 4'h0,
	CHECK = 4'h1,
	READ_ADDR = 4'h2,
	READ_DATA_BURST = 4'h3,
	WRITE_ADDR = 4'h4,
	WRITE_DATA_BURST = 4'h5,
	WRITE_B = 4'h6,
	NEXT_BURST = 4'h7,
	DONE = 4'h8,
	HALTED = 4'h9,
	READ_DRAIN = 4'hA
} state_t;

state_t c_state, n_state;

localparam int BURST_BYTES = BYTES_PER_BEAT * BURST_BEATS;
localparam int COUNT_WIDTH = (BURST_BEATS <= 1) ? 1 : $clog2(BURST_BEATS);
localparam int AXI_SIZE = $clog2(BYTES_PER_BEAT);

logic ar_fire, r_fire;
logic aw_fire, w_fire;
logic b_fire;
logic read_error_seen;
logic axi_error_seen;
logic [31:0] dma_src_addr_buf;
logic [31:0] dma_dst_addr_buf;
logic [31:0] burst_data_buf[0:BURST_BEATS-1];
logic [31:0] remaining_bytes;
logic [COUNT_WIDTH-1:0] rd_cnt, wr_cnt;
logic [2:0] current_burst_beats;
logic [4:0] partial_burst_bytes;
logic [12:0] scr_bytes_to_4kb; //0~4096
logic [12:0] dst_bytes_to_4kb; //0~4096
logic [2:0] scr_boundary_beats;
logic [2:0] dst_boundary_beats;
logic [2:0] boundary_limit_beats;
logic [2:0] remaining_limit_beats ;

assign ar_fire	= m_axi_arvalid && m_axi_arready;
assign r_fire	= m_axi_rvalid	&& m_axi_rready;
assign aw_fire	= m_axi_awvalid && m_axi_awready;
assign w_fire	= m_axi_wvalid && m_axi_wready;
assign b_fire	= m_axi_bvalid && m_axi_bready;
//assign current_burst_beats = (remaining_bytes >= BURST_BYTES) ? BURST_BEATS : (remaining_bytes / BYTES_PER_BEAT);
assign partial_burst_bytes = current_burst_beats * BYTES_PER_BEAT;
assign scr_bytes_to_4kb = 13'd4096 - {1'b0, dma_src_addr_buf[11:0]};
assign dst_bytes_to_4kb = 13'd4096 - {1'b0, dma_dst_addr_buf[11:0]};
assign scr_boundary_beats = (scr_bytes_to_4kb >= 13'd16) ? 3'd4 : scr_bytes_to_4kb[4:2];
assign dst_boundary_beats = (dst_bytes_to_4kb >= 13'd16) ? 3'd4 : dst_bytes_to_4kb[4:2];
assign boundary_limit_beats = (scr_boundary_beats < dst_boundary_beats) ? scr_boundary_beats : dst_boundary_beats;
assign remaining_limit_beats = (remaining_bytes >= 32'd16) ? 3'd4 : remaining_bytes[4:2];
assign current_burst_beats = (boundary_limit_beats < remaining_limit_beats) ?  boundary_limit_beats : remaining_limit_beats;

assign hw_dma_halted = (c_state == HALTED);
assign hw_dma_idle = (c_state == IDLE) || (c_state == DONE);
assign hw_ioc_irq_set = (n_state == DONE) && (c_state != DONE);
assign hw_err_addr_set = (c_state == CHECK) && (
  			(dma_src_addr[63:32] != 32'b0) ||
  			(dma_dst_addr[63:32] != 32'b0));
assign hw_err_align_set	= (c_state == CHECK) && (
  			(dma_src_addr[1:0] != 2'b00) ||
  			(dma_dst_addr[1:0] != 2'b00) ||
  			(dma_trsf_len[1:0] != 2'b00) ||
  			(dma_trsf_len == 32'b0) ||
  			((dma_trsf_len % BYTES_PER_BEAT) != 0));
assign hw_err_axi_set	= axi_error_seen;
assign m_axi_araddr	= dma_src_addr_buf;
assign m_axi_arlen	= (current_burst_beats != 3'd0) ? {5'd0, current_burst_beats - 3'd1} : 8'd0;
assign m_axi_arsize	= AXI_SIZE[2:0];
assign m_axi_arburst	= 2'b01; // INCR
assign m_axi_arvalid	= (c_state == READ_ADDR);
assign m_axi_rready	= (c_state == READ_DATA_BURST) || (c_state == READ_DRAIN);
assign m_axi_awaddr	= dma_dst_addr_buf;
assign m_axi_awlen	= (current_burst_beats != 3'd0) ? {5'd0, current_burst_beats - 3'd1} : 8'd0;
assign m_axi_awsize	= AXI_SIZE[2:0];
assign m_axi_awburst	= 2'b01; // INCR
assign m_axi_awvalid	= (c_state == WRITE_ADDR);
assign m_axi_wdata	= burst_data_buf[wr_cnt];
assign m_axi_wstrb	= 4'b1111;
assign m_axi_wlast	= (c_state == WRITE_DATA_BURST) && (wr_cnt == current_burst_beats - 3'd1);
assign m_axi_wvalid	= (c_state == WRITE_DATA_BURST);
assign m_axi_bready	= (c_state == WRITE_B);


always_ff @(posedge clk or negedge rstn) begin
	if(!rstn) begin
		c_state <= IDLE;
		dma_src_addr_buf <= 32'b0;
		dma_dst_addr_buf <= 32'b0;
		burst_data_buf <= {default : '0};
		remaining_bytes <= 32'b0;
		rd_cnt <= '0;
		wr_cnt <= '0;
		read_error_seen <= 1'b0;
		axi_error_seen <= 1'b0;
	end else if(dma_reset) begin
		c_state <= IDLE;
		dma_src_addr_buf <= 32'b0;
		dma_dst_addr_buf <= 32'b0;
		burst_data_buf <= {default : '0};
		remaining_bytes <= 32'b0;
		rd_cnt <= '0;
		wr_cnt <= '0;
		read_error_seen <= 1'b0;
		axi_error_seen <= 1'b0;
	end else begin
		c_state <= n_state;
		
		if((c_state == CHECK) && (n_state == READ_ADDR)) begin
			dma_src_addr_buf <= dma_src_addr[31:0];
			dma_dst_addr_buf <= dma_dst_addr[31:0];
			remaining_bytes <= dma_trsf_len;
			axi_error_seen <= 1'b0;
		end
		
		if(ar_fire) begin
			read_error_seen <= 1'b0;
			rd_cnt <= '0;
		end
		
		if(r_fire) begin
			if(c_state == READ_DATA_BURST) begin
				burst_data_buf[rd_cnt] <= m_axi_rdata;
				
				if(m_axi_rresp != 2'b00) begin
					read_error_seen <= 1'b1;
				end
				
				if(m_axi_rlast) begin
					rd_cnt <= '0;
				end else if(rd_cnt == (current_burst_beats - 3'd1)) begin
					rd_cnt <= rd_cnt;
				end else begin
					rd_cnt <= rd_cnt + 1;
				end
			end
			
		end
		
		if(aw_fire) begin
			wr_cnt <= '0;
		end
		
		if(w_fire) begin
			if(m_axi_wlast) begin
				wr_cnt <= '0;
			end else begin
				wr_cnt <= wr_cnt + 1;
			end
		end
		
		if(c_state == NEXT_BURST) begin
			dma_src_addr_buf <= dma_src_addr_buf + partial_burst_bytes;
			dma_dst_addr_buf <= dma_dst_addr_buf + partial_burst_bytes;
			remaining_bytes <= remaining_bytes - partial_burst_bytes;
		end
		
		if(
			c_state == READ_DATA_BURST && (
				(r_fire && (m_axi_rresp != 2'b00)) ||
				(r_fire && m_axi_rlast && (rd_cnt != (current_burst_beats - 3'd1))) ||
				(r_fire && !m_axi_rlast && (rd_cnt == (current_burst_beats - 3'd1)))
			)
		) begin
			axi_error_seen <= 1'b1;
		end
			
		if(b_fire && (m_axi_bresp != 2'b00)) begin
			axi_error_seen <= 1'b1;
		end
	end
end

always_comb begin
	n_state = c_state;
	
	case(c_state)
		IDLE : begin
			if(dma_run_stop) n_state = CHECK;
		end
		CHECK : begin
			if(dma_sg_en) begin
				n_state = HALTED;
			end else if( 
				dma_src_addr[63:32] != 32'b0 ||
				dma_dst_addr[63:32] != 32'b0 ||
				dma_src_addr[1:0] != 2'b00 ||
				dma_dst_addr[1:0] != 2'b00 ||
				dma_trsf_len[1:0] != 2'b00 ||
				dma_trsf_len == 32'b0 ||
				(dma_trsf_len % BYTES_PER_BEAT) != 0) begin
				n_state = HALTED;
			end else begin
				n_state = READ_ADDR;
			end
		end
		READ_ADDR : begin
			if(ar_fire) n_state = READ_DATA_BURST;
		end
		READ_DATA_BURST : begin
			if(r_fire) begin
				if(m_axi_rlast) begin
					if(rd_cnt != (current_burst_beats - 3'd1) || read_error_seen || m_axi_rresp != 2'b00) begin
						n_state = HALTED;
					end else begin
						n_state = WRITE_ADDR;
					end
				end else if(rd_cnt == (current_burst_beats - 3'd1)) begin
					n_state = READ_DRAIN;
				end
			end
		end
		WRITE_ADDR : begin
			if(aw_fire) n_state = WRITE_DATA_BURST;
		end
		WRITE_DATA_BURST : begin
			if(w_fire && m_axi_wlast) begin
				n_state = WRITE_B;
			end
		end
		WRITE_B : begin
			if(b_fire) begin
				if(m_axi_bresp == 2'b00) begin
					n_state = NEXT_BURST;
				end else begin
					n_state = HALTED;
				end
			end
		end
		NEXT_BURST : begin
			if(remaining_bytes == partial_burst_bytes) begin
				n_state = DONE;
			end else if(remaining_bytes > partial_burst_bytes) begin
				n_state = READ_ADDR;
			end else begin
				n_state = HALTED;
			end
		end
		DONE : begin
			if(!dma_run_stop) n_state = IDLE;
		end
		HALTED : begin
			if(!dma_run_stop) n_state = IDLE;
		end
		READ_DRAIN : begin
			if(r_fire && m_axi_rlast) begin
				n_state = HALTED;
			end
		end
		default : n_state = IDLE;
	endcase
end

endmodule

