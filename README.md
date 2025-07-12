# HSI_ACCEL - Hardware Accelerator for HSI Vector Processing

HSI_ACCEL is a SystemVerilog-based hardware accelerator designed to compute the pixels of HSI (Hue, Saturation, Intensity) vectors efficiently. The architecture includes a modular and configurable elements for HSI processing, fully testable via Verilator simulation.

## Project Structure

```
HSI_ACCEL/
├── rtl/
│   ├── fifo_cache.sv               # Reusable FIFO module
│   ├── hsi_vector_core.sv          # HSI core
│   └── hsi_vector_core_wrapper.sv  # Wrapper with OBI-like interface for control
├── tb/
│   ├── fifo_cache_tb.sv            # FIFO module testbench
│   ├── hsi_vector_core_tb.sv       # HSI core testbench
│   └── hsi_vector_core_wrapper_tb.sv # Testbench for wrapper module
├── sim/
│   └── sim_main.cpp                # Verilator simulation driver (C++)
├── Makefile                        # Build and simulation automation
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
make hsi_wrapper  # Build and simulate hsi_vector_core_wrapper_tb
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
 * R1: The core shall correctly compute the vector (cross) product of two signed 3-component vectors.
 * R1.2: (1,0,0)×(0,1,0) → (0,0,1)
 * R1.3: (0,0,1)×(1,0,0) → (0,1,0)
 * R1.4: (1,2,3)×(4,5,6) → (−3,6,−3)
 * R1.5: Correct handling of negative components: (−1,0,0)×(0,1,0) → (0,0,−1)
 * R2: The core shall correctly compute the dot (scalar) product of two signed 3-component vectors.
 * R2.1: (1,0,0)·(0,1,0) = 0
 * R2.2: (1,2,3)·(4,5,6) = 32
 * R2.3: (−1,0,0)·(0,1,0) = 0
 * R3: The core shall correctly handle error conditions:
 * R3.1: If OP_CROSS is received but num_bands != 3, it shall assert ERR_OP.
 * R3.2: If num_bands > COMPONENTS_MAX, it shall assert ERR_BANDS.

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

The testbench `hsi_vector_core_wrapper_tb.sv` verifies:
 * R1: Wrapper interprets start/op_code/pixel_size register writes correctly.
 * R2: Read operations return busy status, valid result and pixel_done correctly.
 * R3: Data written to `hsi_vector_core` triggers the expected behavior.
 * R4: Output result register reflects the result from the core.
 * R5: Wrapper issues single-cycle start pulse on valid control write.

## Notes

- `fifo_cache` is a parameterized synchronous FIFO module, reusable across designs.
- The design is compatible with SystemVerilog synthesis and simulation tools.
- `sim_main.cpp` uses `VL_MODULE` and `VL_TOP_TYPE` macros for flexible testbench binding.


## Integration with GR-HEEP (X-HEEP Extension)

This project can be integrated into the [GR-HEEP](https://github.com/davidmallasen/GR-HEEP) platform, which extends X-HEEP with native support for external accelerators through XAIF and the OpenTitan Vendor system.

### Steps to integrate `HSI_ACCEL`:

1. **Clone GR-HEEP and switch to the `connect-bus` branch:**

   ```bash
   git clone https://github.com/davidmallasen/GR-HEEP.git
   cd GR-HEEP
   git checkout connect-bus

2. **Copy the file hw/vendor/hsi_accel.vendor.hjson into the folder GR-HEEP/hw/vendor**

3. **Inlcude the HSI_ACCEL repo into the project**
    ```bash
    make vendor-update MODULE_NAME=hsi_accel


## License

This project is released under the MIT License.