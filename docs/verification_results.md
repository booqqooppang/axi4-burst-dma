# Verification Results

## Overview

The DMA subsystem is tested using a directed, self-checking SystemVerilog testbench. The testbench configures `dma_top` through the CSR interface and checks transferred data, DMA states, and error behavior.

<br>

## Simulation Environment

| Item | Value |
|---|---|
| Simulator | Questa Altera Starter FPGA Edition-64 2025.3 |
| DUT | `dma_top` |
| Testbench | `tb_dma_top` |
| AXI memory data width | 32 bits |
| Maximum burst length | 4 beats |
| Assertion module | `dma_axi_assertions` |
| Assertion checking | SystemVerilog Assertions (SVA) enabled during simulation |

<br>

## Test Results

| Test Case | Checked Behavior | Result |
|---|---|---|
| CSR register read/write | Register readback matches written values | PASS |
| Basic 16-byte transfer | Data copied correctly; DMA completes | PASS |
| Byte-enable write | `WSTRB` updates only selected bytes | PASS |
| Multiple-burst transfer | 32-byte transfer completes correctly | PASS |
| Source 4KB split | Read bursts do not cross a 4KB boundary | PASS |
| Destination 4KB split | Write bursts do not cross a 4KB boundary | PASS |
| CSR AW-first write | Register write completes when AW is accepted before W | PASS |
| CSR W-first write | Register write completes when W is accepted before AW | PASS |
| Source address alignment error | An unaligned source address causes the DMA to enter `HALTED` and sets `ERR_ALIGN` | PASS |
| Destination address alignment error | An unaligned destination address causes the DMA to enter `HALTED` and sets `ERR_ALIGN` | PASS |
| Transfer length alignment error | An unaligned transfer length causes the DMA to enter `HALTED` and sets `ERR_ALIGN` | PASS |
| Unsupported address range | Non-zero upper address bits cause the DMA to enter `HALTED` and sets `ERR_ADDR` | PASS |

<br>

## Assertion-Based Verification

| Assertion Group | Checked Behavior | Result |
|---|---|---|
| AXI 4KB boundary | Accepted AR and AW bursts do not cross a 4KB boundary | PASS |
| DMA burst type | Accepted AR and AW requests use INCR bursts | PASS |
| DMA transfer size | Accepted AR and AW requests specify 4 bytes per beat (`ARSIZE/AWSIZE = 2`) | PASS |
| DMA burst length | Accepted AR and AW requests specify 1–4 beats (`ARLEN/AWLEN = 0–3`) | PASS |
| Master channel stability | AR, AW, and W channels keep VALID asserted and retain their payload values while stalled, through the accepting handshake | PASS |
| Response channel stability | R and B channels keep VALID asserted and retain their payload values while stalled, through the accepting handshake | PASS |
| DMA write strobes | Accepted W beats use full-width write strobes (`WSTRB = 4'b1111`) | PASS |
| DMA WLAST timing | For tracked write bursts, WLAST is asserted on the final beat specified by AWLEN and is not asserted on earlier accepted beats | PASS |
| Master payload known-value checks | AR, AW, and W payload signals contain no X/Z values while their respective VALID signals are asserted | PASS |
| Response payload known-value checks | RDATA, RRESP, and RLAST contain no X/Z values while RVALID is asserted; BRESP contains no X/Z values while BVALID is asserted | PASS |
