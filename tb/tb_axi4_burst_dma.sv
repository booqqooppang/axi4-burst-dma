`timescale 1ns / 1ps

module tb_dma_burst_top;

localparam int DATA_DEPTH = 32;
localparam int ADDR_DEPTH = 8;
localparam int TRANSFER_UNIT = 4;
localparam int BYTES_PER_BEAT	= 4;
localparam int BURST_BEATS		= 4;
localparam int MEM_SIZE = 4096;

localparam time ACLK_PERIOD = 10ns;

logic aclk;
logic arstn;

logic [ADDR_DEPTH-1:0] awaddr;
logic awvalid;
logic awready;

logic [DATA_DEPTH-1:0] wdata;
logic wvalid;
logic wready;
logic [(DATA_DEPTH/8)-1:0] wstrb;

logic bvalid;
logic bready;
logic [1:0] bresp;

logic [ADDR_DEPTH-1:0] araddr;
logic arvalid;
logic arready;

logic [DATA_DEPTH-1:0] rdata;
logic rvalid;
logic rready;
logic [1:0] rresp;

// Read Address
logic [31:0]	m_axi_araddr;
logic [7:0]		m_axi_arlen;
logic [2:0]		m_axi_arsize;
logic [1:0]		m_axi_arburst;
logic				m_axi_arvalid;
logic				m_axi_arready;
	
// Read Data
logic [31:0]	m_axi_rdata;
logic	[1:0]		m_axi_rresp;
logic				m_axi_rlast;
logic				m_axi_rvalid;
logic				m_axi_rready;
	
// Write Address
logic	[31:0]	m_axi_awaddr;
logic	[7:0]		m_axi_awlen;
logic	[2:0]		m_axi_awsize;
logic	[1:0]		m_axi_awburst;
logic				m_axi_awvalid;
logic				m_axi_awready;
	
// Write Data
logic	[31:0]	m_axi_wdata;
logic	[3:0]		m_axi_wstrb;
logic				m_axi_wlast;
logic				m_axi_wvalid;
logic				m_axi_wready;
	
// Write Response
logic	[1:0]		m_axi_bresp;
logic				m_axi_bvalid;
logic				m_axi_bready;


logic [31:0] mem_map[0:MEM_SIZE-1];

dma_top #(
	.DATA_DEPTH(DATA_DEPTH),
	.ADDR_DEPTH(ADDR_DEPTH),
	.TRANSFER_UNIT(TRANSFER_UNIT),
	.BYTES_PER_BEAT(BYTES_PER_BEAT),
	.BURST_BEATS(BURST_BEATS)
)u_dma_top(

	.aclk(aclk),
	.arstn(arstn),
	
	.awaddr(awaddr),
	.awvalid(awvalid),
	.awready(awready),
	
	.wdata(wdata),
	.wvalid(wvalid),
	.wready(wready),
	.wstrb(wstrb),
	
	.bvalid(bvalid),
	.bready(bready),
	.bresp(bresp),
	
	.araddr(araddr),
	.arvalid(arvalid),
	.arready(arready),
	
	.rdata(rdata),
	.rvalid(rvalid),
	.rready(rready),
	.rresp(rresp),
	
	// Read Address
	.m_axi_araddr(m_axi_araddr),
	.m_axi_arlen(m_axi_arlen),
	.m_axi_arsize(m_axi_arsize),
	.m_axi_arburst(m_axi_arburst),
	.m_axi_arvalid(m_axi_arvalid),
	.m_axi_arready(m_axi_arready),
	
	// Read Data
	.m_axi_rdata(m_axi_rdata),
	.m_axi_rresp(m_axi_rresp),
	.m_axi_rlast(m_axi_rlast),
	.m_axi_rvalid(m_axi_rvalid),
	.m_axi_rready(m_axi_rready),
	
	// Write Address
	.m_axi_awaddr(m_axi_awaddr),
	.m_axi_awlen(m_axi_awlen),
	.m_axi_awsize(m_axi_awsize),
	.m_axi_awburst(m_axi_awburst),
	.m_axi_awvalid(m_axi_awvalid),
	.m_axi_awready(m_axi_awready),
	
	// Write Data
	.m_axi_wdata(m_axi_wdata),
	.m_axi_wstrb(m_axi_wstrb),
	.m_axi_wlast(m_axi_wlast),
	.m_axi_wvalid(m_axi_wvalid),
	.m_axi_wready(m_axi_wready),
	
	// Write Response
	.m_axi_bresp(m_axi_bresp),
	.m_axi_bvalid(m_axi_bvalid),
	.m_axi_bready(m_axi_bready)
);

// assertions
dma_axi_assertions u_assertions(
    .aclk(aclk),
	.arstn(arstn),

    // Read Address
	.m_axi_araddr(m_axi_araddr),
	.m_axi_arlen(m_axi_arlen),
	.m_axi_arsize(m_axi_arsize),
	.m_axi_arburst(m_axi_arburst),
	.m_axi_arvalid(m_axi_arvalid),
	.m_axi_arready(m_axi_arready),
	
	// Read Data
	.m_axi_rdata(m_axi_rdata),
	.m_axi_rresp(m_axi_rresp),
	.m_axi_rlast(m_axi_rlast),
	.m_axi_rvalid(m_axi_rvalid),
	.m_axi_rready(m_axi_rready),
	
	// Write Address
	.m_axi_awaddr(m_axi_awaddr),
	.m_axi_awlen(m_axi_awlen),
	.m_axi_awsize(m_axi_awsize),
	.m_axi_awburst(m_axi_awburst),
	.m_axi_awvalid(m_axi_awvalid),
	.m_axi_awready(m_axi_awready),
	
	// Write Data
	.m_axi_wdata(m_axi_wdata),
	.m_axi_wstrb(m_axi_wstrb),
	.m_axi_wlast(m_axi_wlast),
	.m_axi_wvalid(m_axi_wvalid),
	.m_axi_wready(m_axi_wready),
	
	// Write Response
	.m_axi_bresp(m_axi_bresp),
	.m_axi_bvalid(m_axi_bvalid),
	.m_axi_bready(m_axi_bready)
);

initial begin
	aclk = 1'b0;
	forever # (ACLK_PERIOD/2) aclk = ~aclk;
end

task automatic axi_write(
	input logic [ADDR_DEPTH-1:0] addr,
	input logic [DATA_DEPTH-1:0] data
);

	@(posedge aclk);
	awvalid = 1'b1;
	wvalid = 1'b1;
	awaddr = addr;
	wdata = data;
	wstrb = 4'b1111;
	bready = 1'b0;
	
	fork
		begin
			do begin
				@(posedge aclk);
			end while(!(awvalid && awready));
			awvalid = 1'b0;
		end
		begin
			do begin
				@(posedge aclk);
			end while(!(wvalid && wready));
			wvalid = 1'b0;
		end
	join
	
	bready = 1'b1;
	
	do begin
		@(posedge aclk);
	end while(!(bvalid && bready));
	bready = 1'b0;

endtask

task automatic axi_read(
	input logic [ADDR_DEPTH-1:0] addr
);
	
	@(posedge aclk);
	arvalid = 1'b1;
	araddr = addr;
	rready = 1'b1;
	
	do begin
		@(posedge aclk);
	end while(!(arvalid && arready));
	arvalid = 1'b0;
	
	do begin
		@(posedge aclk);
	end while(!(rvalid && rready));
	rready = 1'b0;
	
endtask

// mem_map initial
initial begin
	for(int i=0; i<MEM_SIZE; i++) begin
		mem_map[i] = '0;
	end
	
	/* mem_map['h400] = 32'h1111_1111;
	mem_map['h401] = 32'h2222_2222;
	mem_map['h402] = 32'h3333_3333;
	mem_map['h403] = 32'h4444_4444;
	mem_map['h404] = 32'h5555_5555;
	mem_map['h405] = 32'h6666_6666;
	mem_map['h406] = 32'h7777_7777;
	mem_map['h407] = 32'h8888_8888; */
	mem_map['h3FD] = 32'hAAAA_AAAA;  // 0x0FF4
	mem_map['h3FE] = 32'hBBBB_BBBB;  // 0x0FF8
	mem_map['h3FF] = 32'hCCCC_CCCC;  // 0x0FFC
	mem_map['h400] = 32'hDDDD_DDDD;  // 0x1000
end

// mem axi burst Read
initial begin
	int unsigned start_index;
	int unsigned beat_count;
	
	m_axi_arready = 1'b0;
	m_axi_rvalid = 1'b0;
	m_axi_rlast = 1'b0;
	m_axi_rresp = 2'b00;
	
	
	forever begin
	
		m_axi_arready = 1'b1;
		
		do begin
			@(posedge aclk);
		end while(!(m_axi_arvalid && m_axi_arready));
		start_index = m_axi_araddr >> 2;
		beat_count = m_axi_arlen + 1;
		m_axi_arready = 1'b0;
		
		for(int i=0; i<beat_count; i++) begin
			m_axi_rvalid = 1'b1;
			m_axi_rdata = mem_map[start_index];
			m_axi_rlast = (i == beat_count-1);
			do begin
				@(posedge aclk);
			end while(!(m_axi_rvalid && m_axi_rready));
			start_index = start_index + 1;
		end
		
		m_axi_rvalid = 1'b0;
		m_axi_rlast = 1'b0;
		m_axi_rdata = '0;
		
	end
end

// mem axi burst Write
initial begin
	logic [31:0] m_axi_wdata_buf;
	logic [3:0] m_axi_wstrb_buf;
	logic m_axi_wlast_buf;
	int unsigned start_index;
	int unsigned beat_count;
	int unsigned write_count;
	
	m_axi_awready = 1'b0;
	m_axi_wready = 1'b0;
	m_axi_bvalid = 1'b0;
	m_axi_bresp = 2'b00;
	
	forever begin
		
		m_axi_awready = 1'b1;
		
		do begin
			@(posedge aclk);
		end while(!(m_axi_awvalid && m_axi_awready));
		m_axi_awready = 1'b0;
		start_index = m_axi_awaddr >> 2;
		beat_count = m_axi_awlen + 1;
		write_count = 0;
		
		m_axi_wready = 1'b1;
		
		forever begin
			
			do begin
				@(posedge aclk);
			end while(!(m_axi_wvalid && m_axi_wready));
			m_axi_wdata_buf = m_axi_wdata;
			m_axi_wstrb_buf = m_axi_wstrb;
			m_axi_wlast_buf = m_axi_wlast;
			
			if(m_axi_wstrb_buf[0]) mem_map[start_index][7:0] = m_axi_wdata_buf[7:0];
			if(m_axi_wstrb_buf[1]) mem_map[start_index][15:8] = m_axi_wdata_buf[15:8];
			if(m_axi_wstrb_buf[2]) mem_map[start_index][23:16] = m_axi_wdata_buf[23:16];
			if(m_axi_wstrb_buf[3]) mem_map[start_index][31:24] = m_axi_wdata_buf[31:24];
			start_index++;
			write_count++;
			
			if(m_axi_wlast_buf) begin
				if(write_count == beat_count) begin
					m_axi_bresp = 2'b00;
				end else begin
					m_axi_bresp = 2'b10; // SLVERR
            end
            break;
			end
			
			if(write_count >= beat_count) begin
				m_axi_bresp = 2'b10;
				break;
			end
			
		end
		
		m_axi_wready = 1'b0;
		
		m_axi_bvalid = 1'b1;
		
		do begin
			@(posedge aclk);
		end while(!(m_axi_bvalid && m_axi_bready));
		m_axi_bvalid = 1'b0;

	end
end

// main
initial begin
	arstn   = 1'b0;
   awaddr  = '0;
   awvalid = 1'b0;
   wdata   = '0;
   wstrb   = '0;
   wvalid  = 1'b0;
   bready  = 1'b0;
   araddr  = '0;
   arvalid = 1'b0;
   rready  = 1'b0;
	
	#100ns;
	arstn   = 1'b1;
	#100ns;
	
	@(posedge aclk);
	axi_write(8'h08, 32'h0000_0ff4);
	axi_write(8'h10, 32'h0000_2000);
	axi_write(8'h18, 32'd32);
	
	
	axi_write(8'h00, 32'h0000_0001);
	
	wait(u_dma_top.hw_ioc_irq_set == 1'b1);
	$display("[%0t] DMA completed ", $time);

	
	if(mem_map['h800] !== 32'hAAAA_AAAA) begin
		$fatal(1, "FAIL : dst 0x2000");
	end
	if(mem_map['h801] !== 32'hBBBB_BBBB) begin
		$fatal(1, "FAIL : dst 0x2004");
	end
	if(mem_map['h802] !== 32'hCCCC_CCCC) begin
		$fatal(1, "FAIL : dst 0x2008");
	end
	if(mem_map['h803] !== 32'hDDDD_DDDD) begin
		$fatal(1, "FAIL : dst 0x200C");
	end
	
	$display("success");
	
	@(posedge aclk);
	axi_write(8'h00, 32'h0000_0000);

end

endmodule


