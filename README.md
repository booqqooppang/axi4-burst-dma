# axi4-burst-dma
SystemVerilog AXI4 DMA subsystem with an AXI4-Lite-style control/status register bank, AXI4 INCR burst transfers, 4KB-aware burst splitting, and self-checking verification.

<br>

## Overview
This project is a DMA engine `simple_dma_axi_burst` that copies data from one memory address to another using an AXI4 master interface. A separate control/status register block `csr_register_bank` lets a CPU control it through an AXI4-Lite slave interface. In a typical use case, a CPU writes the source address, destination address, and transfer length into these registers, starts the DMA, and then checks (or gets interrupted) when the transfer finishes or an error happens.
The two modules are kept separate on purpose. The CSR block holds all the state that software can see. The DMA engine is just a datapath and state machine — it reacts to simple signals (`dma_run_stop`, `dma_reset`, and the address/length values) and sends simple status signals back to the CSR block.

<br>

## Key Features

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
