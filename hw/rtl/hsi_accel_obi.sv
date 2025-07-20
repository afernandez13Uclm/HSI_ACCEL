/**
 * @file hsi_accel_obi.sv
 * @brief Módulo top para la integración del wrapper OBI y el núcleo HSI Vector Core.
 *
 * @details
 * Este archivo top conecta el wrapper `hsi_vector_core_wrapper` con el núcleo `hsi_vector_core`.
 * Expone una interfaz OBI para facilitar su integración dentro de plataformas como X-HEEP.
 * 
 * El wrapper maneja la configuración del núcleo (op_code, num_bands, start) y proporciona acceso
 * al estado del procesamiento. Los vectores de entrada/salida deben conectarse externamente.
 *
 * @author
 * Alejandro Fernández Rodríguez, UCLM
 * @version 1.0
 * @date 2025
 */

module hsi_accel_obi #(
    parameter int COMPONENT_WIDTH = 16,
    parameter int FIFO_DEPTH      = 16,
    parameter int COMPONENTS_MAX  = 3
)(
    // Señales de reloj y reset
    input  logic                          clk_i,
    input  logic                          rst_ni,

    // Interfaz OBI (slave)
    input  logic                          req_i,
    input  logic                          we_i,
    input  logic [3:0]                    be_i,
    input  logic [31:0]                   addr_i,
    input  logic [31:0]                   wdata_i,
    output logic                          gnt_o,
    output logic                          rvalid_o,
    output logic [31:0]                   rdata_o,
    output logic                          err_o,

    // Interfaz externa para datos (FIFO)
    input  logic                          in1_wr_en_i,
    input  logic                          in2_wr_en_i,
    input  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] in1_data_i,
    input  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] in2_data_i,
    input  logic                          out_rd_en_i,
    output logic                          out_empty_o,
    output logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] out_data_o
);

    // Señales internas
    logic [3:0]  op_code;
    logic [31:0] num_bands;
    logic        start;

    logic        pixel_done;
    logic [3:0]  error_code;

    logic        in1_full, in2_full;
    logic        out_full;

    logic        in1_empty, in2_empty;
    

    // ============================================================================
    // Instancia del wrapper
    // ============================================================================
    assign in1_empty = 1'b0;
    assign in2_empty = 1'b0;

    hsi_vector_core_wrapper #(
        .OP_CODE_WIDTH(4),
        .NUM_BANDS_WIDTH(32),
        .ERR_WIDTH(4),
        .READ_CLEAR_DONE(0),
        .EXPOSE_FIFO_STATUS(1)
    ) i_wrapper (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        // Bus OBI
        .req_i(req_i),
        .we_i(we_i),
        .be_i(be_i),
        .addr_i(addr_i),
        .wdata_i(wdata_i),
        .gnt_o(gnt_o),
        .rvalid_o(rvalid_o),
        .rdata_o(rdata_o),
        .err_o(err_o),

        // Señales de control hacia el core
        .op_code_o(op_code),
        .num_bands_o(num_bands),
        .start_o(start),

        // Desde core
        .pixel_done_i(pixel_done),
        .error_code_i(error_code),

        // Estado FIFO (desde core)
        .in1_full_i(in1_full),
        .in2_full_i(in2_full),
        .out_full_i(out_full),
        .out_empty_i(out_empty_o),
        .in1_empty_i(in1_empty),
        .in2_empty_i(in2_empty)
    );

    // ============================================================================
    // Instancia del núcleo vectorial
    // ============================================================================
    hsi_vector_core #(
        .COMPONENT_WIDTH(COMPONENT_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .COMPONENTS_MAX(COMPONENTS_MAX)
    ) i_hsi_core (
        .clk(clk_i),
        .rst_n(rst_ni),

        .in1_wr_en(in1_wr_en_i),
        .in1_data_in(in1_data_i),
        .in1_full(in1_full),

        .in2_wr_en(in2_wr_en_i),
        .in2_data_in(in2_data_i),
        .in2_full(in2_full),

        .out_rd_en(out_rd_en_i),
        .out_data_out(out_data_o),
        .out_empty(out_empty_o),
        .out_full(out_full),

        .op_code(op_code),
        .num_bands(num_bands),
        .start(start),
        .pixel_done(pixel_done),
        .error_code(error_code)
    );

endmodule
