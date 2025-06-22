# HSI_ACCEL - Hardware Accelerator for HSI Vector Processing

HSI_ACCEL is a SystemVerilog-based hardware accelerator designed to compute the pixels of HSI (Hue, Saturation, Intensity) vectors efficiently. The architecture includes a modular and configurable elements for HSI processing, fully testable via Verilator simulation.

## Project Structure

```
HSI_ACCEL/
├── rtl/
│   ├── fifo_cache.sv           # Reusable FIFO module
│   └── hsi_vector_core.sv      # HSI core
├── tb/
│   ├── fifo_cache_tb.sv        # FIFO module testbench
│   └── hsi_vector_core_tb.sv   # HSI core testbench
├── sim/
│   └── sim_main.cpp            # Verilator simulation driver (C++)
├── Makefile                    # Build and simulation automation
```

## Requirements

- Verilator v5.x
- GTKWave (optional, for waveform viewing)
- C++ Compiler (g++, clang++)
- GNU Make

## Simulation

This project uses Verilator along with C++ testbench drivers to simulate the RTL modules.

### Build and Run

```bash
make hsi_core     # Build and simulate hsi_vector_core_tb
make fifo_cache   # Build and simulate fifo_cache_tb
```

This will generate:
- dump.vcd → waveform output (for GTKWave)
- coverage.dat → functional coverage report

### View Waveform

```bash
gtkwave dump.vcd
```
### View Coverage

```bash
make coverage
```
Open in a web browser the file `coverage/index.html`

### Project clean

```bash
make clean
```

## Functional Requirements Tested

The testbench `hsi_vector_core_tb.sv` verifies:
- TBD

The testbench `fifo_cache_tb.sv` verifies:
 * R1: After reset, the FIFO must be empty (empty == 1).
 * R2: Write is permitted when the FIFO is not full (wr_en == 1 and full == 0).
 * R3: The full signal must assert once DEPTH writes have been performed.
 * R4: Read is permitted when the FIFO is not empty (rd_en == 1 and empty == 0).
 * R5: The empty signal must assert after all data has been read.
 * R6: Writing when full is asserted must not alter stored data or pointer values.
 * R7: Reading when empty is asserted must not alter stored data or pointer values.
 * R8: Data integrity: data_out must match the sequence that was written.
 * R9: Back-to-back write and read operations must execute consecutively without errors.
 * R10: Robust behavior under random operation sequences, with no protocol violations.

## Notes

- `fifo_cache` is a parameterized synchronous FIFO module, reusable across designs.
- The design is compatible with SystemVerilog synthesis and simulation tools.
- `sim_main.cpp` uses `VL_MODULE` and `VL_TOP_TYPE` macros for flexible testbench binding.

## License

This project is released under the MIT License.
