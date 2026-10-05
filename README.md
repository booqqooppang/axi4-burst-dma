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
|  |  - Address / Alignment / AXI Error Status         |  |
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
- This version should not be considered fully parameterized
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

### Typical Operation Sequence

1. Software writes the source address, destination address, transfer length, and control register, then sets `DMA_CR.RUN_STOP = 1`.
2. DMA validates the request (alignment, non-zero length, SG disabled) and calculates the current burst length (see [4KB Boundary Handling](#4kb-boundary-handling)).
3. DMA issues an AXI4 read burst, buffers the incoming data, and checks `RRESP`/`RLAST`.
4. DMA issues an AXI4 write burst from the buffered data.
5. DMA checks `BRESP` — on success, it updates the addresses/remaining length and starts the next burst or completes; on error, it enters `HALTED`.

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

## Error Handling

| Condition | DMA Behavior | CSR Status Behavior |
|---|---|---|
| Source/destination upper address is non-zero | DMA enters `HALTED` | `ERR_ADDR` is set |
| Unaligned address | DMA enters `HALTED` | `ERR_ALIGN` is set |
| Zero transfer length | DMA enters `HALTED` | `ERR_ALIGN` is set |
| Transfer length not divisible by 4 | DMA enters `HALTED` | `ERR_ALIGN` is set |
| Scatter-gather enabled | DMA enters `HALTED` | No dedicated SG error flag in current register map |
| `RRESP != OKAY` | DMA drains response channel and enters `HALTED` | `ERR_AXI` is set |
| `BRESP != OKAY` | DMA enters `HALTED` | `ERR_AXI` is set |
| Early or missing/late `RLAST` | DMA enters `HALTED`; drain is used for missing/late `RLAST` | `ERR_AXI` is set |

<br>

## Design Decisions

### Independent CSR Write Channels

The control interface handles AXI write address and write data channels independently. The `csr_register_bank` supports both simultaneous and independent AXI4-Lite write-address and write-data handshakes. It captures `AWADDR` and `WDATA/WSTRB` independently, commits the register write after both handshakes have completed, and then asserts `BVALID`.

`AWREADY` and `WREADY` are deasserted while a previous write is still waiting on `BVALID`, so writes are processed one at a time (no back-to-back write pipelining).

```text
AWVALID && AWREADY
    -> Capture write address

WVALID && WREADY
    -> Capture write data and write strobes

Address captured AND data captured
    -> Commit register write
    -> Assert BVALID
```

This behavior matches the independent AXI write-address and write-data channel model.

### Burst Buffer Architecture

The DMA receives an entire read burst before issuing the corresponding write burst.

```text
AXI Read Burst
      |
      v
Internal Burst Buffer
      |
      v
AXI Write Burst
```

This design keeps the read and write steps separate, which makes the DMA flow and error handling easier to understand. The DMA finishes reading one burst before it starts writing that burst, so it is designed for simplicity and reliable operation rather than maximum memory bandwidth.

### Read-Response Drain

If an AXI read response error occurs or the expected final read beat arrives without `RLAST`, the DMA keeps `RREADY` asserted in the `READ_DRAIN` state.

The controller discards remaining read data until it receives `RLAST`, then enters `HALTED`. This prevents the DMA from leaving an AXI read transaction incomplete and blocking the read-data channel.

<br>

## Verification

The project uses a directed, self-checking SystemVerilog testbench.

The testbench configures `dma_top` through the control-register interface, models an AXI4 memory slave, initializes source memory, starts DMA operation, waits for completion or halt, and compares destination memory against expected source data.

| Test Case | Description | Expected Result | Status |
|---|---|---|---|
| CSR register write/read | Writes DMA configuration and reads back register values | Register data matches expected values | PASS |
| Byte-enable write | Uses `WSTRB` to update selected register bytes | Only selected register bytes change | PASS |
| Basic 16-byte transfer | One 4-beat read burst and one 4-beat write burst | Data copied correctly; DMA enters DONE | PASS |
| Multiple burst transfer | 32-byte transfer using two 4-beat bursts | Data copied correctly across two bursts | PASS |
| Partial final burst | Transfer has a final burst shorter than four beats | Correct dynamic `ARLEN`, `AWLEN`, `RLAST`, and `WLAST` behavior | PASS |
| AXI backpressure | Delayed READY/VALID responses on AXI channels | DMA maintains valid data/control until handshake | PASS |
| Source 4KB split | Source begins near 4KB boundary | Read burst is split before crossing boundary | PASS |
| Destination 4KB split | Destination begins near 4KB boundary | Write burst is split before crossing boundary | PASS |
| Read response error | Memory model returns non-OKAY `RRESP` | DMA drains read channel and enters HALTED | PASS |
| Write response error | Memory model returns non-OKAY `BRESP` | DMA enters HALTED | PASS |
| Early `RLAST` | Read slave asserts `RLAST` too early | DMA detects error and enters HALTED | PASS |
| Missing/late `RLAST` | Expected final read beat has no `RLAST` | DMA enters READ_DRAIN, waits for `RLAST`, then halts | PASS |
| Alignment error | Unaligned source/destination or invalid transfer length | DMA enters HALTED and sets alignment error flag | PASS |
| Unsupported SG mode | `SG_EN = 1` | DMA enters HALTED | PASS |

See [verification_plan.md](docs/verification_plan.md) for detailed test objectives and [test_results.md](docs/test_results.md) for simulation output, waveform locations, and executed test conditions.

<br>

## Synthesis Results

## How to Simulate

Example Questa/ModelSim simulation flow:

```bash
vlib work

vlog -sv rtl/csr_register_bank.sv
vlog -sv rtl/simple_dma_axi_burst.sv
vlog -sv rtl/dma_top.sv
vlog -sv tb/tb_dma_top.sv

vsim -c tb_dma_top -do "run -all; quit"
```

<br>

## Directory Structure

```text
.
├── LICENSE
├── README.md
├── .gitignore
├── rtl/
│   ├── dma_top.sv
│   ├── csr_register_bank.sv
│   └── simple_dma_axi_burst.sv
├── tb/
│   └── tb_dma_top.sv
├── docs/
│   ├── architecture.md
│   ├── verification_plan.md
│   ├── test_results.md
│   └── register_map.xlsx
└── sim/
    └── README.md
```

## remained task
1. readme 수정
2. simulation 파형 첨부
3. verification 문서 수정
4. synthesis result 추가
5. tb 수정
6. architecture 만들기
7. 
