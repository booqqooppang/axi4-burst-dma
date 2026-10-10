module dma_top #(
	parameter int DATA_DEPTH,
	parameter int ADDR_DEPTH,
	parameter int TRANSFER_UNIT,
	parameter int BYTES_PER_BEAT,
	parameter int BURST_BEATS
)(
	input		logic aclk,
	input		logic arstn,
	
	input		logic [ADDR_DEPTH-1:0] awaddr,
	input		logic awvalid,
	output	logic awready,
	
	input		logic [DATA_DEPTH-1:0] wdata,
	input		logic wvalid,
	output	logic wready,
	input		logic [(DATA_DEPTH/8)-1:0] wstrb,
	
	output	logic bvalid,
	input		logic bready,
	output	logic [1:0] bresp,
	
	input		logic [ADDR_DEPTH-1:0] araddr,
	input		logic arvalid,
	output	logic arready,
	
	output	logic [DATA_DEPTH-1:0] rdata,
	output	logic rvalid,
	input		logic rready,
	output	logic [1:0] rresp,
	
	// Read Address
	output	logic [31:0]	m_axi_araddr,
	output	logic [7:0]		m_axi_arlen,
	output	logic [2:0]		m_axi_arsize,
	output	logic [1:0]		m_axi_arburst,
	output	logic				m_axi_arvalid,
	input		logic				m_axi_arready,
	
	// Read Data
	input		logic [31:0]	m_axi_rdata,
	input		logic	[1:0]		m_axi_rresp,
	input		logic				m_axi_rlast,
	input		logic				m_axi_rvalid,
	output	logic				m_axi_rready,
	
	// Write Address
	output	logic	[31:0]	m_axi_awaddr,
	output	logic	[7:0]		m_axi_awlen,
	output	logic	[2:0]		m_axi_awsize,
	output	logic	[1:0]		m_axi_awburst,
	output	logic				m_axi_awvalid,
	input		logic				m_axi_awready,
	
	// Write Data
	output	logic	[31:0]	m_axi_wdata,
	output	logic	[3:0]		m_axi_wstrb,
	output	logic				m_axi_wlast,
	output	logic				m_axi_wvalid,
	input		logic				m_axi_wready,
	
	// Write Response
	input		logic	[1:0]		m_axi_bresp,
	input		logic				m_axi_bvalid,
	output	logic				m_axi_bready
);

logic dma_run_stop;
logic dma_reset;
logic dma_sg_en;
logic dma_ioc_irq_en;
logic dma_err_irq_en;
logic [63:0] dma_src_addr;
logic [63:0] dma_dst_addr;
logic [31:0] dma_trsf_len;
logic [63:0] dma_cur_desc;
logic [63:0] dma_tail_desc;

logic hw_dma_halted;
logic hw_dma_idle;
logic hw_ioc_irq_set;
logic hw_err_addr_set;
logic hw_err_align_set;
logic hw_err_axi_set;


csr_register_bank #(
	.DATA_DEPTH(DATA_DEPTH),
	.ADDR_DEPTH(ADDR_DEPTH)
)u_csr_reg_bank(
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
	
	.dma_run_stop(dma_run_stop),
	.dma_reset(dma_reset),
	.dma_sg_en(dma_sg_en),
	.dma_ioc_irq_en(dma_ioc_irq_en),
	.dma_err_irq_en(dma_err_irq_en),
	.dma_src_addr(dma_src_addr),
	.dma_dst_addr(dma_dst_addr),
	.dma_trsf_len(dma_trsf_len),
	.dma_cur_desc(dma_cur_desc),
	.dma_tail_desc(dma_tail_desc),
	
	.hw_dma_halted(hw_dma_halted),
	.hw_dma_idle(hw_dma_idle),
	.hw_ioc_irq_set(hw_ioc_irq_set),
	.hw_err_addr_set(hw_err_addr_set),
	.hw_err_align_set(hw_err_align_set),
	.hw_err_axi_set(hw_err_axi_set)
);



simple_dma_axi_burst #(
	.BYTES_PER_BEAT(BYTES_PER_BEAT),
	.BURST_BEATS(BURST_BEATS)
)u_axi_burst(
	.clk(aclk),
	.rstn(arstn),
	.dma_run_stop(dma_run_stop),
	.dma_reset(dma_reset),
	.dma_sg_en(dma_sg_en),
	
	.dma_src_addr(dma_src_addr),
	.dma_dst_addr(dma_dst_addr),
	.dma_trsf_len(dma_trsf_len),
	
	.hw_dma_halted(hw_dma_halted),
	.hw_dma_idle(hw_dma_idle),
	.hw_ioc_irq_set(hw_ioc_irq_set),
	.hw_err_addr_set(hw_err_addr_set),
	.hw_err_align_set(hw_err_align_set),
	.hw_err_axi_set(hw_err_axi_set),
	
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

endmodule


