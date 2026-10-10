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

