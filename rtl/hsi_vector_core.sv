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
 * @version 1.1
 * @date 2025
 * 
 * @copyright
 * Copyright (c) 2025 Alejandro Fernández Rodríguez
 * Licensed under the MIT License.
 */

`include "fifo_cache.sv"
/**
 * @class hsi_vector_core
 * @brief Módulo HSI Vector Core para cálculo de cross-product y dot-product entre vectores HSI.
 * @file hsi_vector_core.sv
 */
module hsi_vector_core #(
    /**
     * @param COMPONENT_WIDTH Ancho de cada componente H, S o I en bits (por defecto 16)
     * @param FIFO_DEPTH Profundidad de las FIFOs internas (potencia de 2, por defecto 16)
     * @param COMPONENTS_MAX Máximo número de componentes (bandas) soportadas (por defecto 3)
     */
    parameter int COMPONENT_WIDTH = 16,
    parameter int FIFO_DEPTH      = 16,
    parameter int COMPONENTS_MAX  = 3 
)(
    input  logic                                            clk,
    input  logic                                            rst_n,

    /**
     * @brief Interfaz FIFO de entrada 1
     * Esta FIFO recibe vectores HSI de entrada para el cálculo.
     * Cada vector tiene un ancho de `COMPONENT_WIDTH * COMPONENTS_MAX` bits.
     * - `in1_wr_en`: habilitación de escritura en la FIFO de entrada 1
     * - `in1_data_in`: datos de entrada (vector HSI) a escribir
     * - `in1_full`: indicador de FIFO llena
     */
    input  logic                                            in1_wr_en,
    input  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       in1_data_in,
    output logic                                            in1_full,

    /**
     * @brief Interfaz FIFO de entrada 2
     * Esta FIFO recibe vectores HSI de entrada para el cálculo.
     * Cada vector tiene un ancho de `COMPONENT_WIDTH * COMPONENTS_MAX` bits.
     * - `in2_wr_en`: habilitación de escritura en la FIFO de entrada 1
     * - `in2_data_in`: datos de entrada (vector HSI) a escribir
     * - `in2_full`: indicador de FIFO llena
     */
    input  logic                                            in2_wr_en,
    input  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       in2_data_in,
    output logic                                            in2_full,

    /**
     * @brief Interfaz FIFO de salida
     * Esta FIFO almacena los resultados del cálculo de vectores.
     * Cada vector tiene un ancho de `COMPONENT_WIDTH * COMPONENTS_MAX` bits.
     * - `out_rd_en`: habilitación de lectura de la FIFO de salida
     * - `out_data_out`: datos de salida (vector HSI resultado) leídos
     * - `out_empty`: indicador de FIFO vacía
     * - `out_full`: indicador de FIFO llena
     */
    input  logic                                            out_rd_en,
    output logic                                            out_empty,
    output logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       out_data_out,
    output logic                                            out_full,

    /**
     * @brief Señales de control y configuración
     * - `op_code`: código de operación para seleccionar el tipo de cálculo (cross-product o dot-product)
     * - `num_bands`: número de bandas/componentes a procesar (1..32)
     * - `start`: señal para iniciar la operación
     */
    input  logic [3:0]                                      op_code,        ///< Código de operación
    input  logic [31:0]                                     num_bands,      ///< Número de bandas/componentes (1..32)
    input  logic                                            start,          ///< Señal para iniciar operación

    /**
     * @brief Señales de salida
     * - `pixel_done`: indicador de que el pixel ha sido procesado y escrito
     * - `error_code`: código de error (0 = OK, otros = error)
     */
    output logic                                            pixel_done,     ///< Indica pixel procesado y escrito
    output logic [3:0]                                      error_code      ///< 0 = OK, otros = error
);

    /**
     * @brief Señales internas de control de FIFOs
     * - `in1_rd_en`: habilitación de lectura de la FIFO de entrada 1
     * - `in2_rd_en`: habilitación de lectura de la FIFO de entrada 2
     * - `out_wr_en`: habilitación de escritura en la FIFO de salida
     * - `in1_data_out`, `in2_data_out`, `out_data_in`: datos leídos/escritos en las FIFOs
     * - `in1_empty`, `in2_empty`: indicadores de FIFO vacía para entradas
     */
    logic                                           in1_rd_en, in2_rd_en, out_wr_en;
    logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]      in1_data_out, in2_data_out, out_data_in;
    logic                                           in1_empty, in2_empty;

    /**
     * @brief FIFO de entrada 1, FIFO de entrada 2 y FIFO de salida
     * Estas FIFOs almacenan los vectores HSI de entrada y salida.
     * Utilizan el módulo `fifo_cache` genérico para manejar la lógica de lectura/escritura.
     */
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_in1 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(in1_wr_en), .rd_en(in1_rd_en),
        .data_in(in1_data_in), .data_out(in1_data_out),
        .full(in1_full), .empty(in1_empty)
    );
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_in2 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(in2_wr_en), .rd_en(in2_rd_en),
        .data_in(in2_data_in), .data_out(in2_data_out),
        .full(in2_full), .empty(in2_empty)
    );
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_out (
        .clk(clk), .rst_n(rst_n),
        .wr_en(out_wr_en), .rd_en(out_rd_en),
        .data_in(out_data_in), .data_out(out_data_out),
        .full(out_full), .empty(out_empty)
    );

    /**
     * @brief Máquina de estados del núcleo HSI Vector Core.
     * Esta FSM controla el flujo de lectura de vectores, cálculo del producto (cruz o punto),
     * escritura de resultados y gestión de errores.
     * 
     * - IDLE: Estado inicial, espera a recibir start.
     * - CAPTURE: Captura datos de entrada.
     * - READ: Lee los vectores de las FIFOs de entrada.
     * - COMPUTE: Realiza el cálculo del producto vectorial o punto.
     * - WRITE: Prepara el resultado para escribir en la FIFO de salida.
     * - WRITE_DONE: Finaliza la escritura en la FIFO de salida.
     * - ERROR: Maneja errores detectados durante la operación.
     * \dot
     * digraph FSM {
     *   rankdir=LR;
     *   node [shape=ellipse, style=filled, fillcolor=lightgray];
     *   IDLE -> CAPTURE     [label="start && valid && !in1_empty && !in2_empty && !out_full"];
     *   IDLE -> ERROR       [label="start && error_code != ERR_NONE"];
     *   CAPTURE -> READ;
     *   READ -> COMPUTE;
     *   COMPUTE -> WRITE    [label="(OP_CROSS) || (OP_DOT && i >= num_bands)"];
     *   WRITE -> WRITE_DONE;
     *   WRITE_DONE -> CAPTURE [label="!in1_empty && !in2_empty"];
     *   WRITE_DONE -> IDLE    [label="otherwise"];
     *   ERROR -> IDLE         [label="!start"];
     *   default -> ERROR;
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
     * @brief Códigos de operación
     * 
     * - OP_CROSS: Producto vectorial (cross-product) para 3 bandas.
     * - OP_DOT: Producto punto (dot-product) para cualquier número de bandas.
     */
    typedef enum logic [3:0] {
        OP_CROSS = 4'd0, ///< Producto vectorial (cross-product)
        OP_DOT   = 4'd1  ///< Producto punto (dot-product)
    } op_code_t;

    /**
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

    /**
     * @brief Variable para almacenar el código de error actual
     * 
     * Se inicializa a ERR_NONE y se actualiza según las condiciones de error detectadas.
     */
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
                        vec1[num_bands - 1 - i] <= in1_data_out[(i*COMPONENT_WIDTH) +: COMPONENT_WIDTH];
                        vec2[num_bands - 1 - i] <= in2_data_out[(i*COMPONENT_WIDTH) +: COMPONENT_WIDTH];
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
    /**
     * @brief Lógica combinacional para determinar el siguiente estado de la FSM
     * 
     * La lógica evalúa el estado actual y las señales de control para decidir el siguiente estado.
     * Se asegura de que se transite correctamente entre los estados según las condiciones del sistema.
     */
    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (start && error_code == ERR_NONE && ((op_code == OP_CROSS && num_bands == 3) || (op_code == OP_DOT && num_bands > 0)) && !in1_empty && !in2_empty && !out_full) next_state = CAPTURE;
                     else if (start && error_code != ERR_NONE) next_state = ERROR;
            CAPTURE: next_state = READ;
            READ:    next_state = COMPUTE;
            COMPUTE: if((op_code == OP_CROSS) || (op_code == OP_DOT && i >= num_bands)) next_state = WRITE;
            WRITE:   next_state = WRITE_DONE;
            WRITE_DONE: if(!in1_empty && !in2_empty) next_state = CAPTURE;
                        else next_state = IDLE;
            ERROR:   if (!start) next_state = IDLE;
            default: next_state = ERROR;
        endcase
    end

endmodule

