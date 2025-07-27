# HSI_ACCEL - Hardware Accelerator for HSI Vector Processing

HSI_ACCEL is a SystemVerilog-based hardware accelerator designed to compute the pixels of HSI hyperspectral image vectors efficiently. The architecture includes a modular and configurable elements for HSI processing, fully testable via Verilator simulation.

## Project Structure

```
HSI_ACCEL/
├── hw/
|   ├── rtl/
│   |    ├── fifo_cache.sv               # Reusable FIFO module
│   |    ├── hsi_vector_core.sv          # HSI core
│   |    └── hsi_vector_core_wrapper.sv  # Wrapper with OBI-like interface for control
│   |    └── hsi_accel_obi.sv            # Top file with the links between hsi_vector_core and hsi_vector_core_wrapper
|   ├── vendor/
│   |    └── hsi_accel.vendor.hjson      # file to automate the integration with x-heep (GR-heep version)
├── tb/
│   ├── fifo_cache_tb.sv            # FIFO module testbench
│   ├── hsi_vector_core_tb.sv       # HSI core testbench
│   └── hsi_vector_core_wrapper_tb.sv # Testbench for wrapper module
│   └── hsi_accel_obi_tb.sv         # Testbench for top file
├── sim/
│   └── sim_main.cpp                # Verilator simulation driver (C++)
├── scripts/                        # Project automation scripts
├── Makefile                        # Build and simulation automation
├── hsi_accel.core                  # Package core file for x-heep integration
```

## Requirements

- Verilator v > 4.260 (Fully tested with Verilator 5.036 in TB and Verilator 4.260 in GR-HEEP)
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
make hsi_obi      # Build and simulate hsi_accel_obi_tb
```

This will generate:
- dump.vcd → waveform output (for GTKWave)
- coverage.dat → functional coverage report

### View Waveform

```bash
gtkwave build/dump.vcd
```
### View Coverage

```bash
make coverage
```
Open in a web browser the file `coverage/index.html`

### View Documentation

```bash
make doc
```
Open in a web browser the file `doc/index.html`

### Project clean

```bash
make clean
```

### View Project Help

```bash
make help
```

## Functional Requirements Tested

The testbench `hsi_vector_core_tb.sv` verifies:
 * **R1**: The core shall correctly compute the vector (cross) product of two signed 3-component vectors.
 * R1.2: (1,0,0)×(0,1,0) → (0,0,1)
 * R1.3: (0,0,1)×(1,0,0) → (0,1,0)
 * R1.4: (1,2,3)×(4,5,6) → (−3,6,−3)
 * R1.5: Correct handling of negative components: (−1,0,0)×(0,1,0) → (0,0,−1)
 * **R2**: The core shall correctly compute the dot (scalar) product of two signed 3-component vectors.
 * R2.1: (1,0,0)·(0,1,0) = 0
 * R2.2: (1,2,3)·(4,5,6) = 32
 * R2.3: (−1,0,0)·(0,1,0) = 0
 * **R3**: The core shall correctly handle error conditions:
 * R3.1: If OP_CROSS is received but num_bands != 3, it shall assert ERR_OP.
 * R3.2: If num_bands > COMPONENTS_MAX, it shall assert ERR_BANDS.

The testbench `fifo_cache_tb.sv` verifies:
 * **R1**: After reset, the FIFO must be empty (empty == 1).
 * **R2**: Write is permitted when the FIFO is not full (wr_en == 1 and full == 0).
 * **R3**: The full signal must assert once DEPTH writes have been performed.
 * **R4**: Read is permitted when the FIFO is not empty (rd_en == 1 and empty == 0).
 * **R5**: The empty signal must assert after all data has been read.
 * **R6**: Writing when full is asserted must not alter stored data or pointer values.
 * **R7**: Reading when empty is asserted must not alter stored data or pointer values.
 * **R8**: Data integrity: data_out must match the sequence that was written.
 * **R9**: Back-to-back write and read operations must execute consecutively without errors.
 * **R10**: Robust behavior under random operation sequences, with no protocol violations.

The testbench `hsi_vector_core_wrapper_tb.sv` verifies the following functional requirements:
* **R1**: After reset, all registers are properly cleared:
  - `OP_CODE = 0`
  - `NUM_BANDS = 0`
  - `STATUS = 0` (DONE = 0, ERROR_CODE = 0, BUSY = 0)
* **R2**: The `OP_CODE` register is writable and can be read back correctly.
* **R3**: The `NUM_BANDS` register supports full and partial byte writes using byte enable (`BE`).
* **R4**: Writing `START` to the `COMMAND` register generates a single-cycle `start_o` pulse, and sets `BUSY` high.
* **R5**: While `BUSY` is active, further writes to `COMMAND.START` do not re-trigger `start_o`.
* **R6**: When `pixel_done_i` is asserted:
  - `DONE` is set.
  - `BUSY` is cleared.
* **R7**: Writing `CLEAR_DONE` to `COMMAND` clears the `DONE` flag in `STATUS`.
* **R8**: If `error_code_i` is set while `BUSY` is active:
  - The `ERROR_CODE` is captured.
  - `BUSY` is cleared.
* **R9**: Writing `CLEAR_ERROR` to `COMMAND` clears the `ERROR_CODE` field in `STATUS`.
* **R10**: Accessing an invalid address:
  - Activates `err_o`.
  - Does **not** alter any valid register (e.g., `OP_CODE` remains unchanged).
* **R11**: A new operation can be started after clearing `DONE`, triggering `start_o` again and setting `BUSY`.
* **R12**: `start_o` is a **single-cycle pulse**; multiple cycles are flagged as an error.

The testbench `hsi_accel_obi_tb.sv` verifies:
 * **R1.1**: The wrapper shall correctly store `OP_CODE` and `NUM_BANDS` values written through the OBI interface.
 * **R1.2**: When configured for the CROSS operation with 3 bands, the system shall compute the correct vector cross product.
 * **R2.1**: When configured for the DOT operation with 3 bands, the system shall compute the correct scalar dot product.
 * **R2.2**: In DOT mode, only the Z component shall contain the result, and X/Y components shall be zero.
 * **R3.1**: If `NUM_BANDS` is not equal to 3 when using `OP_CODE=CROSS`, the wrapper shall raise `ERR_OP` in the STATUS register.
 * **R3.2**: If `NUM_BANDS` exceeds the maximum allowed (`COMPONENTS_MAX`), the wrapper shall raise `ERR_BANDS` in the STATUS register.


## Notes

- `fifo_cache` is a parameterized synchronous FIFO module, reusable across designs.
- The design is compatible with SystemVerilog synthesis and simulation tools.
- `sim_main.cpp` uses `VL_MODULE` and `VL_TOP_TYPE` macros for flexible testbench binding.


## Integration with GR-HEEP (X-HEEP Extension)

This project can be integrated into the [GR-HEEP](https://github.com/davidmallasen/GR-HEEP) platform, which extends X-HEEP with native support for external accelerators through XAIF and the OpenTitan Vendor system.

### Notes

This project is only fully tested with the GR-HEEP project into the branch connect-bus with the toolchain COREV.
To dowload the toolchain you can follow the next intructions:

    ```bash
    wget https://buildbot.embecosm.com/job/corev-gcc-ubuntu2204/47/artifact/\
        corev-openhw-gcc-ubuntu2204-20240530.tar.gz
    tar -xvzf corev-openhw-gcc-ubuntu2204-20240530.tar.gz
    cp -r corev-openhw-gcc-ubuntu2204-20240530/ /home/$USER/tools/corev

    export RISCV=/home/$USER/tools/corev
    source .bashrc
    ```

### Steps to integrate `HSI_ACCEL` rtl files:

1. **Clone GR-HEEP and switch to the `connect-bus` branch:**

   ```bash
   git clone https://github.com/davidmallasen/GR-HEEP.git
   cd GR-HEEP
   git checkout connect-bus
   ```

2. **Copy the file vendor/hsi_accel.vendor.hjson into the folder GR-HEEP/hw/vendor**

3. **Inlcude the HSI_ACCEL repo into the project**
    ```bash
    make vendor-update MODULE_NAME=hsi_accel
    ```

4. **Update the memory map in config/gr-heep-cfg.hjson**
    ```json
    ext_xbar_slaves: {
            hsi_accel: {
                offset: "0x00000000"
                length: "0x00010000"
            }
    },

        ext_periph: {
            hsi_accel: {
                offset: "0x00000000"
                length: "0x00001000"
            }
    },

    external_interrupts: 1
    ```

5. **Instantiate the accelerator in hw/peripherals/gr_heep_peripherals.sv.tpl**
    ```SystemVerilog
        module gr_heep_peripherals (
        input logic clk_i,
        input logic rst_ni,

        // External peripherals master ports
        output obi_pkg::obi_req_t  [gr_heep_pkg::ExtXbarNMasterRnd-1:0] gr_heep_master_req_o,
        /* verilator lint_off UNUSED */
        input  obi_pkg::obi_resp_t [gr_heep_pkg::ExtXbarNMasterRnd-1:0] gr_heep_master_resp_i,
        /* verilator lint_on UNUSED */

        // External peripherals slave ports
        input  obi_pkg::obi_req_t  [gr_heep_pkg::ExtXbarNSlaveRnd-1:0]  gr_heep_slave_req_i,
        output obi_pkg::obi_resp_t [gr_heep_pkg::ExtXbarNSlaveRnd-1:0]  gr_heep_slave_resp_o,

        // External peripherals configuration ports
        /* verilator lint_off UNUSED */
        input  reg_pkg::reg_req_t  [gr_heep_pkg::ExtPeriphNSlaveRnd-1:0] gr_heep_peripheral_req_i,
        /* verilator lint_on UNUSED */
        output reg_pkg::reg_rsp_t  [gr_heep_pkg::ExtPeriphNSlaveRnd-1:0] gr_heep_peripheral_rsp_o,

        // External peripherals interrupt ports
        output logic [gr_heep_pkg::ExtInterruptsRnd-1:0] gr_heep_peripheral_int_o
    );

    // ====================================
    // Default assignments for unused ports
    // ====================================
    assign gr_heep_master_req_o = '0;

    for (genvar i = 1; i < gr_heep_pkg::ExtXbarNSlaveRnd; i++) begin
        assign gr_heep_slave_resp_o[i] = '0;
    end

    for (genvar i = 1; i < gr_heep_pkg::ExtPeriphNSlaveRnd; i++) begin
        assign gr_heep_peripheral_rsp_o[i] = '0;
    end

    for (genvar i = 1; i < gr_heep_pkg::ExtInterruptsRnd; i++) begin
        assign gr_heep_peripheral_int_o[i] = 1'b0;
    end

    // ===============================
    // Instancia del acelerador HSI
    // ===============================
    /* verilator lint_off UNUSED */
    logic [47:0] hsi_in1_data, hsi_in2_data;
    logic        hsi_in1_wr_en, hsi_in2_wr_en;
    logic [47:0] hsi_out_data;
    logic        hsi_out_rd_en, hsi_out_empty;
    logic unused_err; // todo: for future implementation
    /* verilator lint_on UNUSED */


    hsi_accel_obi #(
        .COMPONENT_WIDTH(16),
        .FIFO_DEPTH(16),
        .COMPONENTS_MAX(3)
    ) u_hsi_accel_obi (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),

        // Interfaz OBI desde el bus de esclavos externos
        .req_i        (gr_heep_slave_req_i[0].req),
        .we_i         (gr_heep_slave_req_i[0].we),
        .be_i         (gr_heep_slave_req_i[0].be),
        .addr_i       (gr_heep_slave_req_i[0].addr),
        .wdata_i      (gr_heep_slave_req_i[0].wdata),
        .gnt_o        (gr_heep_slave_resp_o[0].gnt),
        .rvalid_o     (gr_heep_slave_resp_o[0].rvalid),
        .rdata_o      (gr_heep_slave_resp_o[0].rdata),
        .err_o        (unused_err),

        // FIFO interface (conectada a cero por ahora)
        .in1_wr_en_i  (hsi_in1_wr_en),
        .in2_wr_en_i  (hsi_in2_wr_en),
        .in1_data_i   (hsi_in1_data),
        .in2_data_i   (hsi_in2_data),
        .out_rd_en_i  (hsi_out_rd_en),
        .out_empty_o  (hsi_out_empty),
        .out_data_o   (hsi_out_data)
    );

    // Dummy assignments for FIFO interfaces (sin uso en esta integración)
    assign hsi_in1_data   = 48'd0;
    assign hsi_in2_data   = 48'd0;
    assign hsi_in1_wr_en  = 1'b0;
    assign hsi_in2_wr_en  = 1'b0;
    assign hsi_out_rd_en  = 1'b0;

    // No se usa interrupción
    assign gr_heep_peripheral_int_o[0] = 1'b0;
    assign gr_heep_peripheral_rsp_o[0] = '0;

    endmodule
    ```


6. **add de dependence to file "peripherals.core"**
    ```bash
    - uclm:hsi:hsi_accel:1.0.0
    ```

7. **Compile project HW modules again**
    ```bash
    make gr-heep-gen-force
    ```

8. **Compile the example project to verify the installation (replace the architecture and compiler with the desired)**
    ```bash
    make app PROJECT=example COMPILER_PREFIX=riscv32-corev- ARCH=rv32imfc_zicsr
    make verilator-sim
    ```
### Steps to integrate `HSI_ACCEL` sw driver:
1. **Go to `HSI_ACCEL` dir**
    ```bash
    cd /your/path/GR-HEEP/hw/vendor/hsi_accel
    ```
2. **Exdcute automatic driver install**
    ```bash
    make gr-heep-driver-install
    ```
3. **Compile project HW modules again**
    ```bash
    make gr-heep-gen-force
    ```
4. **Compile the example project to verify the installation (replace the architecture and compiler with the desired)**
    ```bash
    make app PROJECT=hsi_accel COMPILER_PREFIX=riscv32-corev- ARCH=rv32imfc_zicsr
    make verilator-sim
    ```

## License

This project is released under the MIT License.