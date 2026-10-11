`timescale 1ns / 1ps

module dma_axi_assertions (
    input logic        aclk,
    input logic        arstn,

    // Read address channel
    input logic [31:0] m_axi_araddr,
    input logic [7:0]  m_axi_arlen,
    input logic [2:0]  m_axi_arsize,
    input logic [1:0]  m_axi_arburst,
    input logic        m_axi_arvalid,
    input logic        m_axi_arready,

    // Read data channel
    input logic [31:0] m_axi_rdata,
    input logic [1:0]  m_axi_rresp,
    input logic        m_axi_rlast,
    input logic        m_axi_rvalid,
    input logic        m_axi_rready,

    // Write address channel
    input logic [31:0] m_axi_awaddr,
    input logic [7:0]  m_axi_awlen,
    input logic [2:0]  m_axi_awsize,
    input logic [1:0]  m_axi_awburst,
    input logic        m_axi_awvalid,
    input logic        m_axi_awready,

    // Write data channel
    input logic [31:0] m_axi_wdata,
    input logic [3:0]  m_axi_wstrb,
    input logic        m_axi_wlast,
    input logic        m_axi_wvalid,
    input logic        m_axi_wready,

    // Write response channel
    input logic [1:0]  m_axi_bresp,
    input logic        m_axi_bvalid,
    input logic        m_axi_bready
);

    localparam logic [1:0] AXI_BURST_INCR = 2'b01;
    localparam logic [2:0] AXI_SIZE_4BYTE = 3'd2;
    localparam logic [1:0] AXI_RESP_OKAY  = 2'b00;

    // ------------------------------------------------------------
    // 4KB boundary checks
    // burst bytes = (AxLEN + 1) * (2 ** AxSIZE)
    // ------------------------------------------------------------

	property p_ar_no_4kb_cross;
		@(posedge aclk) disable iff(!arstn)
		(m_axi_arvalid && m_axi_arready) |->
		(
			{1'b0, m_axi_araddr[11:0]} + (({1'b0, m_axi_arlen} + 1'b1) << m_axi_arsize)
			<= 13'd4096
		);
	endproperty
	assert property(p_ar_no_4kb_cross)
	else $fatal(1,
		"[AXI SVA] AR burst crossed 4KB boundary : ARADDR=0x%08h ARLEN=%0d ARSIZE=%0d",
		m_axi_araddr, m_axi_arlen, m_axi_arsize
	);
	
    property p_aw_no_4kb_cross;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_awvalid && m_axi_awready)
        |->
        (
            {1'b0, m_axi_awaddr[11:0]} +
            (({1'b0, m_axi_awlen} + 9'd1) << m_axi_awsize)
            <= 13'd4096
        );
    endproperty

    assert property (p_aw_no_4kb_cross)
    else $fatal(1,
        "[AXI SVA] AW burst crosses 4KB boundary: AWADDR=0x%08h AWLEN=%0d AWSIZE=%0d",
        m_axi_awaddr, m_axi_awlen, m_axi_awsize
    );

    // ------------------------------------------------------------
    // Current DMA implementation restrictions
    // - INCR burst only
    // - 32-bit full-width transfer: AxSIZE = 2 (4 bytes)
    // - Maximum four beats: AxLEN = 0 to 3
    // ------------------------------------------------------------

    property p_ar_incr_only;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_arvalid && m_axi_arready)
        |-> (m_axi_arburst == AXI_BURST_INCR);
    endproperty

    assert property (p_ar_incr_only)
    else $fatal(1, "[AXI SVA] Unsupported ARBURST: %b", m_axi_arburst);

    property p_aw_incr_only;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_awvalid && m_axi_awready)
        |-> (m_axi_awburst == AXI_BURST_INCR);
    endproperty

    assert property (p_aw_incr_only)
    else $fatal(1, "[AXI SVA] Unsupported AWBURST: %b", m_axi_awburst);

    property p_ar_4byte_transfer;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_arvalid && m_axi_arready)
        |-> (m_axi_arsize == AXI_SIZE_4BYTE);
    endproperty

    assert property (p_ar_4byte_transfer)
    else $fatal(1, "[AXI SVA] Unsupported ARSIZE: %0d", m_axi_arsize);

    property p_aw_4byte_transfer;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_awvalid && m_axi_awready)
        |-> (m_axi_awsize == AXI_SIZE_4BYTE);
    endproperty

    assert property (p_aw_4byte_transfer)
    else $fatal(1, "[AXI SVA] Unsupported AWSIZE: %0d", m_axi_awsize);

    property p_arlen_max_4beats;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_arvalid && m_axi_arready)
        |-> (m_axi_arlen <= 8'd3);
    endproperty

    assert property (p_arlen_max_4beats)
    else $fatal(1, "[AXI SVA] ARLEN exceeds 4-beat limit: %0d", m_axi_arlen);

    property p_awlen_max_4beats;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_awvalid && m_axi_awready)
        |-> (m_axi_awlen <= 8'd3);
    endproperty

    assert property (p_awlen_max_4beats)
    else $fatal(1, "[AXI SVA] AWLEN exceeds 4-beat limit: %0d", m_axi_awlen);

    // ------------------------------------------------------------
    // Address channel stability under backpressure
    // ------------------------------------------------------------

    property p_ar_stable_while_stalled;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_arvalid && !m_axi_arready)
        |=> (
            m_axi_arvalid &&
            $stable(m_axi_araddr) &&
            $stable(m_axi_arlen)  &&
            $stable(m_axi_arsize) &&
            $stable(m_axi_arburst)
        );
    endproperty

    assert property (p_ar_stable_while_stalled)
    else $fatal(1, "[AXI SVA] AR channel changed while ARVALID=1 and ARREADY=0");

    property p_aw_stable_while_stalled;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_awvalid && !m_axi_awready)
        |=> (
            m_axi_awvalid &&
            $stable(m_axi_awaddr) &&
            $stable(m_axi_awlen)  &&
            $stable(m_axi_awsize) &&
            $stable(m_axi_awburst)
        );
    endproperty

    assert property (p_aw_stable_while_stalled)
    else $fatal(1, "[AXI SVA] AW channel changed while AWVALID=1 and AWREADY=0");

    // ------------------------------------------------------------
    // Write data channel stability under backpressure
    // ------------------------------------------------------------

    property p_w_stable_while_stalled;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_wvalid && !m_axi_wready)
        |=> (
            m_axi_wvalid &&
            $stable(m_axi_wdata) &&
            $stable(m_axi_wstrb) &&
            $stable(m_axi_wlast)
        );
    endproperty

    assert property (p_w_stable_while_stalled)
    else $fatal(1, "[AXI SVA] W channel changed while WVALID=1 and WREADY=0");

    // ------------------------------------------------------------
    // WSTRB check
    // Current DMA supports full-width 32-bit writes only.
    // ------------------------------------------------------------

    property p_wstrb_full_width;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_wvalid && m_axi_wready)
        |-> (m_axi_wstrb == 4'b1111);
    endproperty

    assert property (p_wstrb_full_width)
    else $fatal(1, "[AXI SVA] WSTRB is not full-width: %b", m_axi_wstrb);

    // ------------------------------------------------------------
    // WLAST tracking
    // Captures AWLEN at AW handshake.
    // Checks that WLAST arrives exactly on final write data beat.
    // This DMA issues one write burst at a time.
    // ------------------------------------------------------------

    logic [7:0] expected_wbeats;
    logic [7:0] observed_wbeats;
    logic       write_burst_active;

    always_ff @(posedge aclk or negedge arstn) begin
        if (!arstn) begin
            expected_wbeats   <= 8'd0;
            observed_wbeats   <= 8'd0;
            write_burst_active <= 1'b0;
        end
        else begin
            if (m_axi_awvalid && m_axi_awready) begin
                expected_wbeats    <= m_axi_awlen + 8'd1;
                observed_wbeats    <= 8'd0;
                write_burst_active <= 1'b1;
            end

            if (m_axi_wvalid && m_axi_wready && write_burst_active) begin
                observed_wbeats <= observed_wbeats + 8'd1;

                if (m_axi_wlast) begin
                    write_burst_active <= 1'b0;
                end
            end
        end
    end

    property p_wlast_only_on_final_beat;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_wvalid && m_axi_wready && write_burst_active && m_axi_wlast)
        |-> ((observed_wbeats + 8'd1) == expected_wbeats);
    endproperty

    assert property (p_wlast_only_on_final_beat)
    else $fatal(1,
        "[AXI SVA] WLAST asserted at wrong beat: observed=%0d expected=%0d",
        observed_wbeats + 8'd1,
        expected_wbeats
    );

    property p_wlast_present_on_final_beat;
        @(posedge aclk) disable iff (!arstn)
        (m_axi_wvalid && m_axi_wready && write_burst_active &&
         ((observed_wbeats + 8'd1) == expected_wbeats))
        |-> m_axi_wlast;
    endproperty

    assert property (p_wlast_present_on_final_beat)
    else $fatal(1,
        "[AXI SVA] WLAST missing on final write beat: expected=%0d",
        expected_wbeats
    );
	
	// ------------------------------------------------------------
	// Read data channel stability
	// R channel source is AXI slave / memory model.
	// ------------------------------------------------------------

	property p_r_stable_while_stalled;
		@(posedge aclk) disable iff (!arstn)
		(m_axi_rvalid && !m_axi_rready)
		|=> (
			m_axi_rvalid &&
			$stable(m_axi_rdata) &&
			$stable(m_axi_rresp) &&
			$stable(m_axi_rlast)
		);
	endproperty

	assert property (p_r_stable_while_stalled)
	else $fatal(1,
		"[AXI SVA] R channel changed while RVALID=1 and RREADY=0"
	);

	// ------------------------------------------------------------
	// Write response channel stability
	// B channel source is AXI slave / memory model.
	// ------------------------------------------------------------

	property p_b_stable_while_stalled;
		@(posedge aclk) disable iff (!arstn)
		(m_axi_bvalid && !m_axi_bready)
		|=> (
			m_axi_bvalid &&
			$stable(m_axi_bresp)
		);
	endproperty

	assert property (p_b_stable_while_stalled)
	else $fatal(1,
		"[AXI SVA] B channel changed while BVALID=1 and BREADY=0"
	);

	// ------------------------------------------------------------
	// No X/Z on active response channels
	// ------------------------------------------------------------

	property p_r_channel_known_when_valid;
		@(posedge aclk) disable iff (!arstn)
		m_axi_rvalid |-> !$isunknown(
			{m_axi_rdata, m_axi_rresp, m_axi_rlast}
		);
	endproperty

	assert property (p_r_channel_known_when_valid)
	else $fatal(1,
		"[AXI SVA] RDATA/RRESP/RLAST contains X or Z while RVALID=1"
	);

	property p_bresp_known_when_valid;
		@(posedge aclk) disable iff (!arstn)
		m_axi_bvalid |-> !$isunknown(m_axi_bresp);
	endproperty

	assert property (p_bresp_known_when_valid)
	else $fatal(1,
		"[AXI SVA] BRESP contains X or Z while BVALID=1"
	);

	// ------------------------------------------------------------
	// No X/Z on active master-driven channels
	// ------------------------------------------------------------

	property p_ar_channel_known_when_valid;
		@(posedge aclk) disable iff (!arstn)
		m_axi_arvalid |-> !$isunknown(
			{m_axi_araddr, m_axi_arlen, m_axi_arsize, m_axi_arburst}
		);
	endproperty

	assert property (p_ar_channel_known_when_valid)
	else $fatal(1,
		"[AXI SVA] AR channel contains X or Z while ARVALID=1"
	);

	property p_aw_channel_known_when_valid;
		@(posedge aclk) disable iff (!arstn)
		m_axi_awvalid |-> !$isunknown(
			{m_axi_awaddr, m_axi_awlen, m_axi_awsize, m_axi_awburst}
		);
	endproperty

	assert property (p_aw_channel_known_when_valid)
	else $fatal(1,
		"[AXI SVA] AW channel contains X or Z while AWVALID=1"
	);

	property p_w_channel_known_when_valid;
		@(posedge aclk) disable iff (!arstn)
		m_axi_wvalid |-> !$isunknown(
			{m_axi_wdata, m_axi_wstrb, m_axi_wlast}
		);
	endproperty

	assert property (p_w_channel_known_when_valid)
	else $fatal(1,
		"[AXI SVA] W channel contains X or Z while WVALID=1"
	);

endmodule