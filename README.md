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
├── sim/
│   └── sim_main.cpp                # Verilator simulation driver (C++)
├── Makefile                        # Build and simulation automation
├── hsi_accel.core                  # Package core file for x-heep integration
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

4. **Update the memory map in config/gr-heep-cfg.hjson**
    ```json
    ext_xbar_slaves: {
        hsi_accel: {
        offset: "0x00010000",
        length: "0x00010000"
        }
    }
    ext_periph: {
        hsi_accel: {
            offset: "0x00010000",
            length: "0x00001000"
        }
    }

    external_interrupts: 1

5. **Instantiate the accelerator in hw/peripherals/gr_heep_peripherals.sv.tpl**
    ```SystemVerilog
    module gr_heep_peripherals (
        /* verilator lint_off UNUSED */

        input logic clk_i,
        input logic rst_ni,

        // External peripherals master ports
        output obi_pkg::obi_req_t  [gr_heep_pkg::ExtXbarNMasterRnd-1:0] gr_heep_master_req_o,
        input  obi_pkg::obi_resp_t [gr_heep_pkg::ExtXbarNMasterRnd-1:0] gr_heep_master_resp_i,

        // External peripherals slave ports
        input  obi_pkg::obi_req_t  [gr_heep_pkg::ExtXbarNSlaveRnd-1:0]  gr_heep_slave_req_i,
        output obi_pkg::obi_resp_t [gr_heep_pkg::ExtXbarNSlaveRnd-1:0]  gr_heep_slave_resp_o,

        // External peripherals configuration ports
        input  reg_pkg::reg_req_t  [gr_heep_pkg::ExtPeriphNSlaveRnd-1:0] gr_heep_peripheral_req_i,
        output reg_pkg::reg_rsp_t  [gr_heep_pkg::ExtPeriphNSlaveRnd-1:0] gr_heep_peripheral_rsp_o,

        /* verilator lint_on UNUSED */

        // External peripherals interrupt ports
        output logic [gr_heep_pkg::ExtInterruptsRnd-1:0] gr_heep_peripheral_int_o
    );

    // Assign default values to the output signals. To be modified if the
    // peripherals are instantiated.
    assign gr_heep_master_req_o = '0;
    assign gr_heep_peripheral_rsp_o = '0;
    assign gr_heep_peripheral_int_o = '0;

    // Instantiate here the external peripherals
    hsi_accel_obi #(
        .AW(32),
        .DW(32)
    ) u_hsi_accel (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .req_i     (gr_heep_slave_req_i[0]),
        .addr_i    (gr_heep_slave_req_i[0].addr),
        .we_i      (gr_heep_slave_req_i[0].we),
        .wdata_i   (gr_heep_slave_req_i[0].wdata),
        .rdata_o   (gr_heep_slave_resp_o[0].rdata),
        .rvalid_o  (gr_heep_slave_resp_o[0].rvalid)
    );
    endmodule

6. **add de dependence to file "peripherals.core"**
    ```bash
    - uclm:hsi:hsi_accel:1.0.0

7. **Compile project HW modules again**
    ```bash
    make gr-heep-gen-force

8. **Compile the example project to verify the installation (replace the architecture and compiler with the desired)**
    ```bash
    make app PROJECT=example COMPILER_PREFIX=riscv32-corev- ARCH=rv32imfc_zicsr
    make verilator-sim


## License

This project is released under the MIT License.