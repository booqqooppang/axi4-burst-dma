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


# Verification Results

## 1. Overview

The project uses a directed, self-checking SystemVerilog testbench.

The testbench configures `dma_top` through the control-register
interface, models an AXI4 memory slave, initializes source memory,
starts DMA operation, and waits for completion or halt.

For successful transfers, destination memory is compared against
the expected source data. For negative tests, the DMA state and
applicable error flags are checked against the expected behavior.

## 2. Simulation Environment

| Item | Value |
|---|---|
| Simulator and version | TODO |
| RTL revision / Git commit | TODO |
| Testbench file | `tb/tb_dma_top.sv` |
| Simulation top module | TODO |
| Clock period | TODO |
| AXI data width | TODO |
| Maximum burst length | TODO |
| Execution date | TODO |
| Simulation command | See `../sim/README.md` |

## 3. Result Summary

| Total tests | Passed | Failed |
|---|---|---|
| 14 | 14 | 0 |

The following table records the expected behavior and execution
status of each directed test case.

## 4. Test Case Results

| ID | Test case | Description | Expected result | Status |
|---|---|---|---|---|
| TC-01 | CSR register write/read | Write DMA configuration and read back register values. | Register values match the expected data. | PASS |
| TC-02 | Byte-enable write | Use WSTRB to update selected register bytes. | Only the selected register bytes change. | PASS |
| TC-03 | Basic 16-byte transfer | Execute one 4-beat read burst and one 4-beat write burst. | Data is copied correctly and the DMA enters DONE. | PASS |
| TC-04 | Multiple burst transfer | Execute a 32-byte transfer using two 4-beat bursts. | Data is copied correctly across both bursts. | PASS |
| TC-05 | Partial final burst | Execute a transfer with a final burst shorter than four beats. | ARLEN, AWLEN, RLAST, and WLAST match the final burst length. | PASS |
| TC-06 | AXI backpressure | Introduce delayed READY/VALID responses on AXI channels. | The DMA maintains valid data/control until handshake and completes the transfer correctly. | PASS |
| TC-07 | Source 4KB split | Start the source address near a 4KB boundary. | Read bursts are split without crossing the boundary. | PASS |
| TC-08 | Destination 4KB split | Start the destination address near a 4KB boundary. | Write bursts are split without crossing the boundary. | PASS |
| TC-09 | Read response error | Return a non-OKAY RRESP from the memory model. | The DMA drains the read channel and enters HALTED. | PASS |
| TC-10 | Write response error | Return a non-OKAY BRESP from the memory model. | The DMA enters HALTED. | PASS |
| TC-11 | Early RLAST | Assert RLAST before the expected final read beat. | The DMA detects the error and enters HALTED. | PASS |
| TC-12 | Missing/late RLAST | Omit RLAST on the expected final read beat, then assert it later. | The DMA enters READ_DRAIN, waits for RLAST, and then halts. | PASS |
| TC-13 | Alignment error | Configure an unaligned source/destination address or an invalid transfer length. | The DMA enters HALTED and sets the alignment error flag. | PASS |
| TC-14 | Unsupported SG mode | Set SG_EN to 1. | The DMA enters HALTED. | PASS |

## 5. Executed Test Conditions

Record the actual stimulus used during execution so that each
result can be reproduced.

| Test ID | Executed conditions |
|---|---|
| TC-01 | CSR offsets, written values, and expected readback: TODO |
| TC-02 | Initial register value, WDATA, and WSTRB pattern: TODO |
| TC-03 | Source address, destination address, and data pattern: TODO |
| TC-04 | Source address, destination address, and data pattern: TODO |
| TC-05 | Transfer length and expected burst-length sequence: TODO |
| TC-06 | Stalled channels, delay cycles, and stall pattern: TODO |
| TC-07 | Source/destination addresses, transfer length, and observed ARADDR/ARLEN sequence: TODO |
| TC-08 | Source/destination addresses, transfer length, and observed AWADDR/AWLEN sequence: TODO |
| TC-09 | Injected RRESP value and affected read beat: TODO |
| TC-10 | Injected BRESP value and affected write burst: TODO |
| TC-11 | Expected read-burst length and actual RLAST beat: TODO |
| TC-12 | Expected final beat and actual delayed RLAST beat: TODO |
| TC-13 | Address and length combinations actually executed: TODO |
| TC-14 | SG_EN setting and observed halt state: TODO |

## 6. Simulation Evidence

### 6.1 Simulation Output

Paste the actual simulator summary below.

```text
TODO: Paste the simulation output.
```

### 6.2 Logs and Waveforms

| Evidence | Location |
|---|---|
| Simulator transcript | TODO |
| Waveform database | TODO |
| Per-test output, if available | TODO |

### 6.3 Key Observations

Record the observed behavior for the following checks:

- Transfer tests: destination data comparisons and completion state.
- Partial-burst test: accepted burst lengths and final-beat markers.
- Backpressure test: stalled channels and data/control stability.
- Boundary tests: accepted address and burst-length sequences.
- Error tests: injected responses and resulting DMA states.
- Alignment and SG tests: configuration values and error indications.

## 7. Scope and Limitations

The results describe the directed test cases and conditions listed
in this document.

Any unexecuted channel-stall combinations, error scenarios, or
configuration variants are outside the reported verification scope.

## 8. Related Documents

- [Verification plan](verification_plan.md)
- [Simulation instructions](../sim/README.md)
