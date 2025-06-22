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

    // Interfaz FIFO de entrada 1
    input  logic                                            in1_wr_en,
    input  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       in1_data_in,
    output logic                                            in1_full,

    // Interfaz FIFO de entrada 2
    input  logic                                            in2_wr_en,
    input  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       in2_data_in,
    output logic                                            in2_full,

    // Interfaz FIFO de salida
    input  logic                                            out_rd_en,
    output logic                                            out_empty,
    output logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]       out_data_out,
    output logic                                            out_full,

    // Operación y control
    input  logic [3:0]                                      op_code,        ///< Código de operación
    input  logic [31:0]                                     num_bands,      ///< Número de bandas/componentes (1..32)
    input  logic                                            start,          ///< Señal para iniciar operación

    // Señales de estado y error
    output logic                                            pixel_done,     ///< Indica pixel procesado y escrito
    output logic [3:0]                                      error_code      ///< 0 = OK, otros = error
);

    /// Señales internas para control de lectura/escritura de las FIFOs
    logic                                           in1_rd_en, in2_rd_en, out_wr_en;
    logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0]      in1_data_out, in2_data_out, out_data_in;
    logic                                           in1_empty, in2_empty;

    // Instanciación de FIFO de entrada 1 (ancho dinámico según num_bands, pero tamaño fijo máximo)
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_in1 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(in1_wr_en), .rd_en(in1_rd_en),
        .data_in(in1_data_in), .data_out(in1_data_out),
        .full(in1_full), .empty(in1_empty)
    );

    // Instanciación de FIFO de entrada 2
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_in2 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(in2_wr_en), .rd_en(in2_rd_en),
        .data_in(in2_data_in), .data_out(in2_data_out),
        .full(in2_full), .empty(in2_empty)
    );

    // Instanciación de FIFO de salida
    fifo_cache #(.WIDTH(COMPONENT_WIDTH*COMPONENTS_MAX), .DEPTH(FIFO_DEPTH)) fifo_out (
        .clk(clk), .rst_n(rst_n),
        .wr_en(out_wr_en), .rd_en(out_rd_en),
        .data_in(out_data_in), .data_out(out_data_out),
        .full(out_full), .empty(out_empty)
    );

    // Estados de la FSM
    typedef enum logic [3:0] {
        IDLE    = 4'd0,
        CAPTURE = 4'd1,
        READ    = 4'd2,
        COMPUTE = 4'd3,
        WRITE   = 4'd4,
        WRITE_DONE = 4'd5,
        ERROR   = 4'd6
    } state_t;


    // Códigos de operación
    // OP_CROSS: Producto vectorial (cross-product) para 3 bandas
    // OP_DOT: Producto punto (dot-product) para cualquier número de bandas

    localparam OP_CROSS                     = 4'd1;
    localparam OP_DOT                       = 4'd2;

    state_t state, next_state;

    // Vectores internos de componentes (máximo COMPONENTS_MAX bandas)
    logic signed [COMPONENT_WIDTH-1:0] vec1 [0:COMPONENTS_MAX-1];
    logic signed [COMPONENT_WIDTH-1:0] vec2 [0:COMPONENTS_MAX-1];
    logic signed [COMPONENT_WIDTH-1:0] result [0:COMPONENTS_MAX-1];

    integer i;

    // Error codes
    localparam ERR_NONE                 = 4'd0;
    localparam ERR_OP                   = 4'd1;
    localparam ERR_INPUT_FIFO_EMPTY     = 4'd2;
    localparam ERR_OUTPUT_FIFO_FULL     = 4'd3;
    localparam ERR_BANDS                = 4'd4;
    localparam ERR_INVALID_FSM          = 4'd4;

    // Secuencial principal
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            in1_rd_en  <= 1'b0;
            in2_rd_en  <= 1'b0;
            out_wr_en  <= 1'b0;
            pixel_done <= 1'b0;
            error_code <= ERR_NONE;
        end else begin
            in1_rd_en  <= 1'b0;
            in2_rd_en  <= 1'b0;
            out_wr_en  <= 1'b0;
            pixel_done <= 1'b0;
            error_code <= ERR_NONE;

            state <= next_state;

            case (state)
                IDLE: begin
                    pixel_done <= !out_empty;
                    error_code <= ERR_NONE;
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

    // FSM combinacional
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
