# axi4-burst-dma
A SystemVerilog implementation of a memory-to-memory AXI4 DMA engine with **4KB-boundary-aware burst splitting** and an **AXI4-Lite control/status register (CSR) interface.**

<br>

## Overview
This project is a DMA engine `simple_dma_axi_burst` that copies data from one memory address to another using an AXI4 master interface. A separate control/status register block `csr_register_bank` lets a CPU control it through an AXI4-Lite slave interface. In a typical use case, a CPU writes the source address, destination address, and transfer length into these registers, starts the DMA, and then checks (or gets interrupted) when the transfer finishes or an error happens.

The two modules are kept separate on purpose. The CSR block holds all the state that software can see. The DMA engine is just a datapath and state machine — it reacts to simple signals (`dma_run_stop`, `dma_reset`, and the address/length values) and sends simple status signals back to the CSR block.

<br>

## Key Features

- **AXI4 full master interface** (separate AR/R/AW/W/B channels) for the data-movement path, and a fully independent **AXI4-Lite slave interface** for control/status
- **Automatic burst-length calculation** that respects the AXI4 rule that a burst must not cross a 4KB address boundary — computed independently for the source and destination addresses, since they can straddle different pages
- **INCR burst type** generation with beat count and size derived from configurable `BYTES_PER_BEAT` / `BURST_BEATS` parameters
- **Hardware error detection**: unaligned address/length, unsupported 64-bit address range, and AXI `RRESP`/`BRESP` error responses, all latched into dedicated status bits
- **W1C (Write-1-to-Clear) status semantics** with hardware-set-has-priority-over-software-clear behavior, so a fault occurring in the same cycle as a clear write is never silently lost
- **Fault-handling states** (`HALTED`, `READ_DRAIN`) so a protocol violation on the read channel drains any in-flight beats cleanly instead of leaving the AXI interconnect in an undefined state

<br>

## Architecture

```text
       AXI4-Lite-Style Control / Status Interface
                             |
                             v
+----------------------------------------------------------+
|                         dma_top                          |
|                                                          |
|  +----------------------------------------------------+  |
|  |                csr_register_bank                  |  |
|  |                                                    |  |
|  |  Control Registers                                |  |
|  |  - Run/Stop                                       |  |
|  |  - Reset                                          |  |
|  |  - Scatter-Gather Enable                          |  |
|  |  - IOC/Error Interrupt Enable                     |  |
|  |                                                    |  |
|  |  Configuration Registers                          |  |
|  |  - Source Address                                 |  |
|  |  - Destination Address                            |  |
|  |  - Transfer Length                                |  |
|  |  - Current/Tail Descriptor Address                |  |
|  |                                                    |  |
|  |  Status Register                                  |  |
|  |  - Halted / Idle                                  |  |
|  |  - IOC Interrupt Status                           |  |
|  |  - Address / Alignment Error Status               |  |
|  +-----------------------+----------------------------+  |
|                          | DMA configuration             |
|                          v                               |
|  +----------------------------------------------------+  |
|  |              simple_dma_axi_burst                 |  |
|  |                                                    |  |
|  |  Burst-Length / 4KB Boundary Logic                |  |
|  |       |                                            |  |
|  |       v                                            |  |
|  |  AXI4 Read Master --> Internal Burst Buffer       |  |
|  |                                  |                 |  |
|  |                                  v                 |  |
|  |                    AXI4 Write Master              |  |
|  +-----------------------+----------------------------+  |
|                          | DMA status/error              |
+----------------------------------------------------------+
                           |
                           v
                    AXI4 Memory Interface
                           |
              +------------+------------+
              |                         |
              v                         v
        Source Memory             Destination Memory
```

<br>

## Features

| Item | Spec |
|---|---|
| RTL language | SystemVerilog |
| DMA type | Memory-to-memory DMA |
| AXI protocol | AXI4 (master, DMA engine) / AXI4-Lite (slave, CSR) |
| Burst type | INCR burst |
| Data path | 32-bit full-width transfer |
| Bytes per beat | 4 bytes |
| Maximum burst length | 4 beats |
| Maximum burst payload | 16 bytes |
| Read/write architecture | Read burst → internal buffer → write burst |
| Outstanding transactions | Single outstanding transaction |
| Transfer alignment | 4-byte aligned |
| 4KB handling | Source and destination boundary-aware burst splitting |
| Read error handling | RRESP error detection and read-response drain |
| Write error handling | BRESP error detection |
| Read protocol checking | Early and missing/late RLAST detection |
| Scatter-gather mode | Unsupported; controller enters halted state |

<br>

## Module Parameters

| Module | Parameter | Default | Description |
|---|---|---|---|
| `simple_dma_axi_burst` | `BYTES_PER_BEAT` | 4 | Number of bytes transferred per AXI data beat |
| `simple_dma_axi_burst` | `BURST_BEATS` | 4 | Maximum number of beats issued in one AXI burst |
| `csr_register_bank` | `DATA_DEPTH` | 32 | CSR data bus width |
| `csr_register_bank` | `ADDR_DEPTH` | 8 | CSR address bus width |

### Design Constraints

- The currently verified configuration is `BYTES_PER_BEAT = 4` and `BURST_BEATS = 4`.
- The current RTL uses a 32-bit AXI data path and 4-bit write strobes.
- Transfers must be full-width and 4-byte aligned.
- This version should not be considered fully parameterized — see [Limitations & Future Work](#limitations--future-work).
- Only AXI4 INCR bursts are supported.
- Scatter-gather operation is not supported.

<br>

## Interface

The DMA engine (`simple_dma_axi_burst`) exposes a control/status interface and AXI4 memory-master interfaces; `csr_register_bank` exposes these same control/status signals through its AXI4-Lite register map (see [Register Map](#register-map-axi4-lite-csr)).

| Signal group | Direction | Description |
|---|---|---|
| `clk`, `rstn` | Input | DMA clock and active-low reset |
| `dma_run_stop` | Input | Starts or stops DMA operation |
| `dma_reset` | Input | Resets DMA control/status state |
| `dma_sg_en` | Input | Scatter-gather enable; unsupported in the current implementation |
| `dma_src_addr` | Input | Source memory start address |
| `dma_dst_addr` | Input | Destination memory start address |
| `dma_trsf_len` | Input | Requested transfer length in bytes |
| `m_axi_ar*` | Output/Input | AXI4 read-address channel |
| `m_axi_r*` | Input/Output | AXI4 read-data channel |
| `m_axi_aw*` | Output/Input | AXI4 write-address channel |
| `m_axi_w*` | Output/Input | AXI4 write-data channel |
| `m_axi_b*` | Input/Output | AXI4 write-response channel |
| `hw_dma_idle` | Output | DMA idle/transfer-complete status |
| `hw_dma_halted` | Output | DMA halted/error status |
| `hw_err_addr_set` | Output | Source/destination address exceeds the supported 32-bit range |
| `hw_err_align_set` | Output | Unaligned address/length or zero-length transfer |
| `hw_err_axi_set` | Output | AXI protocol or response error indication |
| `hw_ioc_irq_set` | Output | Completion interrupt indication |

<br>

## DMA Engine FSM

| State | Description |
|---|---|
| `IDLE` | Waiting for `dma_run_stop` |
| `CHECK` | Validates address range / alignment / length before starting |
| `READ_ADDR` | Issues the AXI4 read address (`AR`) for the current burst |
| `READ_DATA_BURST` | Captures read data beats into an internal buffer |
| `WRITE_ADDR` | Issues the AXI4 write address (`AW`) for the current burst |
| `WRITE_DATA_BURST` | Drives write data beats from the internal buffer |
| `WRITE_B` | Waits for the write response (`B`) channel |
| `NEXT_BURST` | Advances addresses/remaining length, decides next burst or completion |
| `DONE` | Transfer complete, waiting for `dma_run_stop` to deassert |
| `HALTED` | Fault state (address/align/AXI error), waiting for `dma_run_stop` to deassert |
| `READ_DRAIN` | Absorbs remaining in-flight read beats after a protocol violation, before moving to `HALTED` |

<br>

## DMA Operation

```text
1. Configure DMA registers through the control interface:
   - Source address
   - Destination address
   - Transfer length
   - Control register

2. Set DMA_CR.RUN_STOP = 1.

3. DMA validates the request:
   - Scatter-gather disabled
   - Upper source/destination address words equal zero
   - Source address aligned to 4 bytes
   - Destination address aligned to 4 bytes
   - Transfer length is non-zero
   - Transfer length is a multiple of 4 bytes

4. DMA calculates current burst length:
   - Remaining transfer length
   - Maximum configured burst length
   - Source 4KB boundary limit
   - Destination 4KB boundary limit

5. DMA issues AXI4 read burst:
   - ARADDR
   - ARLEN
   - ARSIZE
   - ARBURST = INCR

6. DMA receives read data:
   - Stores each beat in the internal burst buffer
   - Checks RRESP
   - Checks RLAST position

7. DMA issues AXI4 write burst:
   - AWADDR
   - AWLEN
   - AWSIZE
   - AWBURST = INCR

8. DMA writes buffered data:
   - WDATA
   - WSTRB = 4'b1111
   - WLAST on the final beat

9. DMA checks BRESP:
   - On OKAY, updates addresses and remaining length
   - Starts the next burst or enters DONE
   - On error, enters HALTED
```

<br>

## 4KB Boundary Handling

AXI4 bursts must not cross a 4KB address boundary.

For every DMA burst, the controller calculates the number of legal beats using the minimum of:

- Remaining DMA transfer beats
- Configured maximum burst beats
- Source-side beats remaining before the next 4KB boundary
- Destination-side beats remaining before the next 4KB boundary

```text
current_burst_beats =
    min(
        remaining_transfer_beats,
        BURST_BEATS,
        source_boundary_limit_beats,
        destination_boundary_limit_beats
    )
```

### Example: Source Boundary Split

```text
Source address:      0x0000_0FF4
Destination address: 0x0000_1000
Transfer length:     16 bytes
Bytes per beat:      4
```

The source-side first burst can contain only three beats.

```text
Burst #1
  ARADDR = 0x0000_0FF4
  ARLEN  = 2
  Beats  = 3
  Read addresses:
    0x0000_0FF4
    0x0000_0FF8
    0x0000_0FFC

Burst #2
  ARADDR = 0x0000_1000
  ARLEN  = 0
  Beats  = 1
  Read address:
    0x0000_1000
```

The complete 16-byte DMA request succeeds through two legal AXI bursts.

<br>
