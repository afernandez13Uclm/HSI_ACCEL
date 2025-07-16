/**
 * @file hsi_accel_obi.sv
 * @brief Módulo top-level del acelerador HSI con interfaz OBI.
 *
 * @details
 * Este módulo integra el núcleo vectorial HSI con su wrapper OBI, conectando las señales
 * de control y estado entre ellos. Expone la interfaz de bus OBI y las señales de FIFO
 * para conexión externa con DMA u otro controlador.
 *
 * @author Alejandro Fernández Rodríguez, UCLM
 * @version 1.0
 * @date 2025
 * @copyright Copyright (c) 2025 Alejandro Fernández Rodríguez
 * @license Licencia MIT
 */

/**
 * @section signals Descripción de señales de entrada y salida
 * | Señal            | Dirección | Descripción                                                                |
 * |------------------|-----------|----------------------------------------------------------------------------|
 * | clk_i            | input     | Reloj principal del sistema.                                               |
 * | rst_ni           | input     | Reset asíncrono activo en bajo.                                            |
 * | req_i            | input     | Solicitud de transferencia del bus OBI.                                    |
 * | we_i             | input     | Habilitación de escritura (1=escritura, 0=lectura).                        |
 * | be_i             | input     | Habilitación de byte (no utilizado en esta implementación).                |
 * | addr_i           | input     | Dirección de acceso del bus.                                               |
 * | wdata_i          | input     | Datos de escritura del bus.                                                |
 * | gnt_o            | output    | Concesión de transferencia.                                                |
 * | rvalid_o         | output    | Indicador de respuesta válida.                                             |
 * | rdata_o          | output    | Datos de lectura del bus.                                                  |
 * | err_o            | output    | Indicador de error en la transacción.                                      |
 * | in1_wr_en_i      | input     | Habilitación de escritura para FIFO de entrada.                            |
 * | in1_data_i       | input     | Datos de entrada al núcleo.                                                |
 * | out_rd_en_i      | input     | Habilitación de lectura para FIFO de salida.                               |
 * | out_data_o       | output    | Datos de salida del núcleo.                                                |
 * | out_data_valid_o | output    | Indicador de datos válidos en la salida.                                   |
 */

/**
 * @brief Módulo top-level del acelerador HSI con interfaz OBI.
 *
 * @details
 * Instancia y conecta:
 * - hsi_vector_core_wrapper: Interfaz de bus OBI para configuración y control
 * - hsi_vector_core: Núcleo de procesamiento vectorial HSI
 *
 * Las FIFOs de entrada/salida se conectan directamente al núcleo para máxima eficiencia.
 * El wrapper solo provee la interfaz de control vía bus, no interviene en el flujo de datos.
 *
 * @param OP_CODE_WIDTH   Ancho del código de operación (bits)
 * @param NUM_BANDS_WIDTH Ancho del parámetro num_bands (bits)
 * @param ERR_WIDTH       Ancho del código de error (bits)
 * @param DATA_WIDTH      Ancho de datos (bits)
 */
module hsi_accel_obi #(
    parameter int OP_CODE_WIDTH   = 8,   ///< Ancho del código de operación
    parameter int NUM_BANDS_WIDTH = 8,   ///< Ancho del número de bandas
    parameter int ERR_WIDTH       = 8,   ///< Ancho del código de error
    parameter int DATA_WIDTH      = 32   ///< Ancho de datos
) (
    input  logic                    clk_i,          ///< Reloj del sistema
    input  logic                    rst_ni,         ///< Reset asíncrono (activo bajo)

    // Interfaz OBI (conexión al bus del sistema)
    input  logic                    req_i,          ///< Solicitud de transferencia
    input  logic                    we_i,           ///< Habilitación de escritura
    input  logic [3:0]              be_i,           ///< Habilitación de byte
    input  logic [31:0]             addr_i,         ///< Dirección de acceso
    input  logic [31:0]             wdata_i,        ///< Datos de escritura
    output logic                    gnt_o,          ///< Concesión de transferencia
    output logic                    rvalid_o,       ///< Respuesta válida
    output logic [31:0]             rdata_o,        ///< Datos de lectura
    output logic                    err_o,          ///< Indicador de error

    // Interfaces FIFO para entrada/salida de datos (conexión a DMA)
    input  logic                    in1_wr_en_i,    ///< Habilitación de escritura FIFO entrada
    input  logic [DATA_WIDTH-1:0]   in1_data_i,     ///< Datos de entrada al núcleo
    input  logic                    out_rd_en_i,    ///< Habilitación de lectura FIFO salida
    output logic [DATA_WIDTH-1:0]   out_data_o,     ///< Datos de salida del núcleo
    output logic                    out_data_valid_o ///< Dato de salida válido
);

    // Señales de interconexión entre wrapper y núcleo
    logic [OP_CODE_WIDTH-1:0]   op_code_sig;       ///< Código de operación al núcleo
    logic [NUM_BANDS_WIDTH-1:0] num_bands_sig;     ///< Número de bandas al núcleo
    logic                       start_sig;         ///< Señal de inicio al núcleo
    logic                       pixel_done_sig;    ///< Señal de procesamiento completado
    logic [ERR_WIDTH-1:0]       error_code_sig;    ///< Código de error del núcleo

    /**
     * @brief Instancia del wrapper OBI para el núcleo vectorial
     *
     * @details
     * Proporciona la interfaz de bus OBI para configurar y controlar el núcleo.
     * Conecta las señales de control y estado entre el bus y el núcleo.
     */
    hsi_vector_core_wrapper #(
        .OP_CODE_WIDTH(OP_CODE_WIDTH),
        .NUM_BANDS_WIDTH(NUM_BANDS_WIDTH),
        .ERR_WIDTH(ERR_WIDTH)
    ) wrapper_i (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        // Interfaz de bus
        .req_i       (req_i),
        .we_i        (we_i),
        .be_i        (be_i),
        .addr_i      (addr_i),
        .wdata_i     (wdata_i),
        .gnt_o       (gnt_o),
        .rvalid_o    (rvalid_o),
        .rdata_o     (rdata_o),
        .err_o       (err_o),
        // Señales de control al núcleo
        .op_code_o   (op_code_sig),
        .num_bands_o (num_bands_sig),
        .start_o     (start_sig),
        // Señales de estado del núcleo
        .pixel_done_i(pixel_done_sig),
        .error_code_i(error_code_sig)
    );

    /**
     * @brief Instancia del núcleo vectorial HSI
     *
     * @details
     * Implementa el procesamiento de vectores HSI (producto vectorial y punto).
     * Recibe configuración del wrapper y datos a través de las FIFOs.
     */
    hsi_vector_core core_i (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        // Entradas de control
        .op_code_i    (op_code_sig),
        .num_bands_i  (num_bands_sig),
        .start_i      (start_sig),
        // Interfaces FIFO
        .in1_wr_en_i  (in1_wr_en_i),
        .in1_data_i   (in1_data_i),
        .out_rd_en_i  (out_rd_en_i),
        .out_data_o   (out_data_o),
        .out_data_valid_o (out_data_valid_o),
        // Salidas de estado
        .pixel_done_o (pixel_done_sig),
        .error_code_o (error_code_sig)
    );

endmodule
