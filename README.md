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
 * R1: Tras reset, la FIFO debe estar vacía (empty == 1).
 * R2: Escritura permitida cuando la FIFO no está llena (wr_en == 1 y full == 0).
 * R3: Señal full debe activarse al alcanzar DEPTH escrituras.
 * R4: Lectura permitida cuando la FIFO no está vacía (rd_en == 1 y empty == 0).
 * R5: Señal empty debe activarse tras leer todos los datos.
 * R6: Escritura cuando full no debe alterar datos ni punteros.
 * R7: Lectura cuando empty no debe alterar datos ni punteros.
 * R8: Integridad de datos: data_out debe coincidir con la secuencia escrita.
 * R9: Operaciones back-to-back de escritura y lectura consecutivas sin errores.
 * R10: Comportamiento robusto bajo secuencias aleatorias sin violaciones.

## Notes

- `fifo_cache` is a parameterized synchronous FIFO module, reusable across designs.
- The design is compatible with SystemVerilog synthesis and simulation tools.
- `sim_main.cpp` uses `VL_MODULE` and `VL_TOP_TYPE` macros for flexible testbench binding.

## License

This project is released under the MIT License.
