/**
 * @file hsi_vector_core.sv
 * @brief Módulo HSI Vector Core para cálculo de cross-product y dot-product entre vectores HSI.
 *
 * @details
 * Este módulo implementa una unidad de procesamiento que lee vectores HSI desde dos FIFOs de entrada,
 * realiza el cálculo de producto vectorial (cross-product) o producto punto (dot-product) según código de operación,
 * y almacena el resultado en una FIFO de salida. Internamente utiliza una FSM con estados IDLE, READ,
 * COMPUTE y WRITE para controlar el flujo de datos.
 *
 * @author
 * Alejandro Fernández Rodríguez, UCLM
 *
 * @version 1.0
 * @date 2025
 * 
 * @copyright
 * Copyright (c) 2025 Alejandro Fernández Rodríguez
 * Licensed under the MIT License.
 */

/**
 * @class hsi_vector_core
 * @brief Módulo HSI Vector Core para cálculo vectorial entre vectores HSI.
 *
 * @details
 * Esta unidad de cálculo vectorial emplea una FSM interna para capturar, leer y procesar
 * vectores HSI de entrada, realizando operaciones matemáticas entre ellos y escribiendo
 * el resultado a una FIFO de salida. Soporta producto vectorial (solo para 3 bandas) y
 * producto escalar (para un número configurable de bandas hasta un máximo). Utiliza tres
 * instancias del módulo `fifo_cache` para gestionar la entrada y salida de datos.
 *
 * @param COMPONENT_WIDTH Ancho de cada componente H/S/I (por defecto: 16 bits).
 * @param FIFO_DEPTH Profundidad de las FIFOs internas (potencia de 2, por defecto: 16).
 * @param COMPONENTS_MAX Máximo número de bandas/componentes HSI (por defecto: 3).
 *
 * @section signals Descripción de señales de entrada y salida
 * | Señal         | Dirección | Descripción                                                              |
 * |---------------|-----------|---------------------------------------------------------------------------|
 * | clk           | input     | Reloj principal del sistema.                                             |
 * | rst_n         | input     | Reset asíncrono activo en bajo.                                          |
 * | in1_wr_en     | input     | Escritura en FIFO de entrada 1.                                          |
 * | in1_data_in   | input     | Datos de entrada (vector HSI) a FIFO 1.                                  |
 * | in1_full      | output    | FIFO de entrada 1 llena.                                                 |
 * | in2_wr_en     | input     | Escritura en FIFO de entrada 2.                                          |
 * | in2_data_in   | input     | Datos de entrada (vector HSI) a FIFO 2.                                  |
 * | in2_full      | output    | FIFO de entrada 2 llena.                                                 |
 * | out_rd_en     | input     | Lectura de FIFO de salida.                                               |
 * | out_data_out  | output    | Resultado vectorial calculado.                                           |
 * | out_empty     | output    | FIFO de salida vacía.                                                    |
 * | out_full      | output    | FIFO de salida llena.                                                    |
 * | op_code       | input     | Código de operación (producto vectorial o escalar).                      |
 * | num_bands     | input     | Número de componentes del vector (1 a COMPONENTS_MAX).                   |
 * | start         | input     | Señal para iniciar la operación.                                         |
 * | pixel_done    | output    | Señal que indica que un resultado está disponible.                       |
 * | error_code    | output    | Código de error, si se produce durante el procesamiento.                 |
 *
 * @section usage Ejemplo de instanciación
 * @code{.sv}
 * hsi_vector_core #(
 *     .COMPONENT_WIDTH(16),
 *     .FIFO_DEPTH(32),
 *     .COMPONENTS_MAX(3)
 * ) hsi_core_inst (
 *     .clk(clk),
 *     .rst_n(rst_n),
 *     .in1_wr_en(in1_wr_en),
 *     .in1_data_in(in1_data_in),
 *     .in1_full(in1_full),
 *     .in2_wr_en(in2_wr_en),
 *     .in2_data_in(in2_data_in),
 *     .in2_full(in2_full),
 *     .out_rd_en(out_rd_en),
 *     .out_data_out(out_data_out),
 *     .out_empty(out_empty),
 *     .out_full(out_full),
 *     .op_code(op_code),
 *     .num_bands(num_bands),
 *     .start(start),
 *     .pixel_done(pixel_done),
 *     .error_code(error_code)
 * );
 * @endcode
 */
module hsi_vector_core #(
    parameter int COMPONENT_WIDTH = 16,
    parameter int FIFO_DEPTH      = 16,
    parameter int COMPONENTS_MAX  = 3 
)(
    /**
     * @var clk, rst_n
     * @brief Señales de reloj y reset
     */
    input  logic                                            clk,
    input  logic                                            rst_n,

    /**
     * @var in1_wr_en, in1_data_in, in1_full
     * @brief Interfaz FIFO de entrada 1
     * Esta FIFO recibe vectores HSI de entrada para el cálculo.
     * Cada vector tiene un ancho de `COMPONENT_WIDTH * COMPONENTS_MAX` bits.
     */
    input  logic                                            in1_wr_en,
    input  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       in1_data_in,
    output logic                                            in1_full,

    /**
     * @var in2_wr_en, in2_data_in, in2_full
     * @brief Interfaz FIFO de entrada 2
     * Esta FIFO recibe vectores HSI de entrada para el cálculo.
     * Cada vector tiene un ancho de `COMPONENT_WIDTH * COMPONENTS_MAX` bits.
     */
    input  logic                                            in2_wr_en,
    input  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       in2_data_in,
    output logic                                            in2_full,

    /**
     *@ var out_rd_en, out_data_out, out_empty, out_full
     * @brief Interfaz FIFO de salida
     * Esta FIFO almacena los resultados del cálculo de vectores.
     * Cada vector tiene un ancho de `COMPONENT_WIDTH * COMPONENTS_MAX` bits.
     */
    input  logic                                            out_rd_en,
    output logic                                            out_empty,
    output logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       out_data_out,
    output logic                                            out_full,

    /**
     * @var op_code, num_bands, start
     * @brief Señales de control y configuración
     */
    input  logic [3:0]                                      op_code,        ///< Código de operación
    input  logic [31:0]                                     num_bands,      ///< Número de bandas/componentes (1..32)
    input  logic                                            start,          ///< Señal para iniciar operación

    /**
     * @var pixel_done, error_code
     * @brief Señales de salida
     */
    output logic                                            pixel_done,     ///< Indica pixel procesado y escrito
    output logic [3:0]                                      error_code      ///< 0 = OK, otros = error
);

    /**
     * @var in1_rd_en, in2_rd_en, out_wr_en
     * @var in1_data_out, in2_data_out, out_data_in
     * @var in1_empty, in2_empty
     * @brief Señales internas de control de FIFOs
     */
    logic                                           in1_rd_en, in2_rd_en, out_wr_en;
    logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]      in1_data_out, in2_data_out, out_data_in;
    logic                                           in1_empty, in2_empty;

    /**
     * @class FIFO_entrada_1
     * @brief FIFO de entrada 1
     * Esta FIFO almacena los vectores HSI de entrada.
     * Utilizan el módulo `fifo_cache` genérico para manejar la lógica de lectura/escritura.
     */
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_in1 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(in1_wr_en), .rd_en(in1_rd_en),
        .data_in(in1_data_in), .data_out(in1_data_out),
        .full(in1_full), .empty(in1_empty)
    );
    /**
     * @class FIFO_entrada_2
     * @brief FIFO de entrada 2
     * Esta FIFO almacena los vectores HSI de entrada.
     * Utilizan el módulo `fifo_cache` genérico para manejar la lógica de lectura/escritura.
     */
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_in2 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(in2_wr_en), .rd_en(in2_rd_en),
        .data_in(in2_data_in), .data_out(in2_data_out),
        .full(in2_full), .empty(in2_empty)
    );
    /**
     * @class FIFO_salida
     * @brief FIFO de salisa
     * Esta FIFO almacena los vectores HSI de salida.
     * Utilizan el módulo `fifo_cache` genérico para manejar la lógica de lectura/escritura.
     */
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_out (
        .clk(clk), .rst_n(rst_n),
        .wr_en(out_wr_en), .rd_en(out_rd_en),
        .data_in(out_data_in), .data_out(out_data_out),
        .full(out_full), .empty(out_empty)
    );


    /**
    * @class state_t
    * @brief Estados de la máquina de estados finita (FSM)
    * Esta enumeración define los estados de la FSM que controla el flujo de datos y operaciones.
    * - IDLE: Estado inicial. Espera a que se reciba `start` con parámetros válidos para comenzar el procesamiento.
    * - CAPTURE: Espera a que las FIFOs de entrada tengan datos disponibles para iniciar la lectura.
    * - READ: Lee los vectores desde las FIFOs de entrada.
    * - COMPUTE: Realiza el cálculo del producto vectorial (CROSS) o producto punto (DOT).
    * - WRITE: Prepara el resultado del cálculo para escribirlo en la FIFO de salida.
    * - WRITE_DONE: Finaliza la escritura y decide si se continúa procesando o se vuelve a IDLE.
    * - ERROR: Estado de fallo si la configuración de entrada no es válida.
    * \dot
    * digraph FSM {
    *   rankdir=LR;
    *   node [shape=ellipse, style=filled, fillcolor=lightgray];
    *
    *   IDLE -> CAPTURE     [label="start && error_code == ERR_NONE && ((op_code == OP_CROSS && num_bands == 3) || (op_code == OP_DOT && num_bands > 0)) && !out_full"];
    *   IDLE -> ERROR       [label="start && error_code != ERR_NONE"];
    *
    *   CAPTURE -> READ     [label="!in1_empty && !in2_empty"];
    *   READ -> COMPUTE;
    *   COMPUTE -> WRITE    [label="(op_code == OP_CROSS) || (op_code == OP_DOT && i >= num_bands)"];
    *   WRITE -> WRITE_DONE [label="!out_full"];
    *
    *   WRITE_DONE -> CAPTURE [label="!in1_empty && !in2_empty"];
    *   WRITE_DONE -> IDLE    [label="otherwise"];
    *
    *   ERROR -> IDLE         [label="!start"];
    *
    * }
    * \enddot
    */


    typedef enum logic [3:0] {
        IDLE    = 4'd0,
        CAPTURE = 4'd1,
        READ    = 4'd2,
        COMPUTE = 4'd3,
        WRITE   = 4'd4,
        WRITE_DONE = 4'd5,
        ERROR   = 4'd6
    } state_t;

    /**
     * @class op_code_t
     * @brief Códigos de operación
     * 
     * - OP_CROSS: Producto vectorial (cross-product) para 3 bandas.
     * - OP_DOT: Producto punto (dot-product) para cualquier número de bandas.
     */
    typedef enum logic [3:0] {
        OP_CROSS = 4'd1, ///< Producto vectorial (cross-product)
        OP_DOT   = 4'd2  ///< Producto punto (dot-product)
    } op_code_t;

    /**
     * @var state, next_state, vec1, vec2, result, i
     * @brief Variables internas de la FSM
     * 
     * - `state`: Estado actual de la FSM.
     * - `next_state`: Estado siguiente a transitar.
     * - `vec1`, `vec2`, `result`: Vectores internos para almacenar los componentes de entrada y el resultado.
     * - `i`: Contador para iterar sobre las bandas.
     */
    state_t state, next_state;
    logic signed [COMPONENT_WIDTH-1:0] vec1 [0:COMPONENTS_MAX-1];
    logic signed [COMPONENT_WIDTH-1:0] vec2 [0:COMPONENTS_MAX-1];
    logic signed [COMPONENT_WIDTH-1:0] result [0:COMPONENTS_MAX-1];
    integer i;

    /**
     * @class error_code_t
     * @brief Código de error
     * 
     * - ERR_NONE: No hay error.
     * - ERR_OP: Error en el código de operación (por ejemplo, OP_CROSS con num_bands != 3).
     * - ERR_INPUT_FIFO_EMPTY: FIFO de entrada vacía al intentar leer.
     * - ERR_OUTPUT_FIFO_FULL: FIFO de salida llena al intentar escribir.
     * - ERR_BANDS: Número de bandas no válido (mayor que COMPONENTS_MAX).
     * - ERR_INVALID_FSM: Estado desconocido en la FSM.
     */
    typedef enum logic [3:0] {
        ERR_NONE                 = 4'd0, ///< No hay error
        ERR_OP                   = 4'd1, ///< Error en el código de operación
        ERR_INPUT_FIFO_EMPTY     = 4'd2, ///< FIFO de entrada vacía
        ERR_OUTPUT_FIFO_FULL     = 4'd3, ///< FIFO de salida llena
        ERR_BANDS                = 4'd4, ///< Número de bandas no válido
        ERR_INVALID_FSM          = 4'd5  ///< Estado desconocido en la FSM
    } error_code_t;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            in1_rd_en  <= 1'b0;
            in2_rd_en  <= 1'b0;
            out_wr_en  <= 1'b0;
            pixel_done <= 1'b0;
            error_code <= ERR_NONE;
        end else begin

            state <= next_state;

            case (state)
                IDLE: begin
                    pixel_done <= !out_empty;
                    if (start) begin
                        if(num_bands > COMPONENTS_MAX) begin
                            error_code <= ERR_BANDS;
                        end else begin   
                            if ((op_code == OP_CROSS && num_bands == 3) || (op_code == OP_DOT && num_bands > 0)) begin
                                if (!in1_empty && !in2_empty && !out_full) begin
                                    in1_rd_en <= 1'b1;
                                    in2_rd_en <= 1'b1;
                                end else begin
                                    if (in1_empty || in2_empty) begin
                                        error_code <= ERR_INPUT_FIFO_EMPTY;
                                    end else if (out_full) begin
                                        error_code <= ERR_OUTPUT_FIFO_FULL;
                                    end
                                end
                            end else begin
                                error_code <= ERR_OP;
                            end
                        end
                    end
                end
                CAPTURE: begin
                    in1_rd_en <= 1'b0;
                    in2_rd_en <= 1'b0;
                end
                READ: begin
                    for (i = 0; i < num_bands; i = i + 1) begin
                        /* verilator lint_off BLKSEQ */
                        vec1[num_bands - 1 - i] = in1_data_out[(i*COMPONENT_WIDTH) +: COMPONENT_WIDTH];
                        vec2[num_bands - 1 - i] = in2_data_out[(i*COMPONENT_WIDTH) +: COMPONENT_WIDTH];
                        /* verilator lint_on BLKSEQ */
                    end
                    for (i = 0; i < COMPONENTS_MAX; i = i + 1) result[i] <= 0;
                    i = 0;

                end
                COMPUTE: begin
                    if (op_code == OP_CROSS) begin
                        // Producto vectorial solo para 3 bandas
                        result[2] <= vec1[1]*vec2[2] - vec1[2]*vec2[1];
                        result[1] <= vec1[2]*vec2[0] - vec1[0]*vec2[2];
                        result[0] <= vec1[0]*vec2[1] - vec1[1]*vec2[0];
                    end else if (op_code == OP_DOT) begin
                        result[0] <= result[0] + vec1[i]*vec2[i];
                        i = i + 1;
                    end
                end
                WRITE: begin
                    // Concatenar resultado
                    for (i = 0; i < num_bands; i = i + 1) begin
                        out_data_in[i*COMPONENT_WIDTH +: COMPONENT_WIDTH] <= result[i];
                    end
                    out_wr_en   <= 1'b1;
                end
                WRITE_DONE: begin
                    out_wr_en <= 1'b0;
                end
                ERROR: begin
                    // Se mantiene el error hasta nuevo start
                end
                default: begin
                    error_code <= ERR_INVALID_FSM; // Error por estado desconocido
                end
            endcase
        end
    end
    // logica de transición de estados
    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (start && error_code == ERR_NONE && ((op_code == OP_CROSS && num_bands == 3) || (op_code == OP_DOT && num_bands > 0)) && !out_full) next_state = CAPTURE;
                     else if (start && error_code != ERR_NONE) next_state = ERROR;
            CAPTURE: if(!in1_empty && !in2_empty ) next_state = READ;
            READ:    next_state = COMPUTE;
            COMPUTE: if((op_code == OP_CROSS) || (op_code == OP_DOT && i >= num_bands)) next_state = WRITE;
            WRITE:   if(!out_full) next_state = WRITE_DONE;
            WRITE_DONE: if(!in1_empty && !in2_empty) next_state = CAPTURE;
                        else next_state = IDLE;
            ERROR:   if (!start) next_state = IDLE;
            default: next_state = ERROR;
        endcase
    end

endmodule


