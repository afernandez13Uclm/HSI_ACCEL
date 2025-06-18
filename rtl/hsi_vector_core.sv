/**
 * @file hsi_vector_core.sv
 * @brief Módulo HSI Vector Core para cálculo de cross-product entre vectores HSI.
 *
 * @details
 * Este módulo implementa una unidad de procesamiento que lee vectores HSI desde dos FIFOs de entrada,
 * realiza el cálculo de producto vectorial (cross-product) cuando el código de operación es `OP_CROSS`,
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

`include "fifo_cache.sv"

module hsi_vector_core #(
    /**
     * @param COMPONENT_WIDTH Ancho de cada componente H, S o I en bits (por defecto 16)
     * @param FIFO_DEPTH Profundidad de las FIFOs internas (potencia de 2, por defecto 16)
     * @param OPC_WIDTH Número de bits del código de operación
     * @param OP_CROSS Código que representa la operación de producto vectorial
     */
    parameter int COMPONENT_WIDTH = 16,
    parameter int FIFO_DEPTH      = 16,
    parameter int OPC_WIDTH       = 2,
    parameter logic [OPC_WIDTH-1:0] OP_CROSS = 'd1
)(
    input  logic                              clk,            ///< Señal de reloj principal
    input  logic                              rst_n,          ///< Reset asíncrono activo en bajo

    // Interfaz FIFO de entrada 1
    input  logic                              in1_wr_en,      ///< Habilita escritura en FIFO 1
    input  logic [3*COMPONENT_WIDTH-1:0]      in1_data_in,    ///< Datos de entrada para FIFO 1
    output logic                              in1_full,       ///< FIFO 1 llena

    // Interfaz FIFO de entrada 2
    input  logic                              in2_wr_en,      ///< Habilita escritura en FIFO 2
    input  logic [3*COMPONENT_WIDTH-1:0]      in2_data_in,    ///< Datos de entrada para FIFO 2
    output logic                              in2_full,       ///< FIFO 2 llena

    // Interfaz FIFO de salida
    input  logic                              out_rd_en,      ///< Habilita lectura de FIFO de salida
    output logic                              out_empty,      ///< FIFO de salida vacía
    output logic [3*COMPONENT_WIDTH-1:0]      out_data_out,   ///< Datos concatenados de salida (x3,y3,z3)
    output logic                              out_full,       ///< FIFO de salida llena

    // Operación
    input  logic [OPC_WIDTH-1:0]              op_code         ///< Código de operación
);

    /// Señales internas para control de lectura/escritura de las FIFOs
    logic                              in1_rd_en, in2_rd_en, out_wr_en;
    logic [3*COMPONENT_WIDTH-1:0]      in1_data_out, in2_data_out, out_data_in;
    logic                              in1_empty, in2_empty;

    /// Instanciación de FIFO para el vector de entrada 1
    fifo_cache #(.WIDTH(3*COMPONENT_WIDTH), .DEPTH(FIFO_DEPTH)) fifo_in1 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(in1_wr_en), .rd_en(in1_rd_en),
        .data_in(in1_data_in), .data_out(in1_data_out),
        .full(in1_full), .empty(in1_empty)
    );

    /// Instanciación de FIFO para el vector de entrada 2
    fifo_cache #(.WIDTH(3*COMPONENT_WIDTH), .DEPTH(FIFO_DEPTH)) fifo_in2 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(in2_wr_en), .rd_en(in2_rd_en),
        .data_in(in2_data_in), .data_out(in2_data_out),
        .full(in2_full), .empty(in2_empty)
    );

    /// Instanciación de FIFO de salida
    fifo_cache #(.WIDTH(3*COMPONENT_WIDTH), .DEPTH(FIFO_DEPTH)) fifo_out (
        .clk(clk), .rst_n(rst_n),
        .wr_en(out_wr_en), .rd_en(out_rd_en),
        .data_in(out_data_in), .data_out(out_data_out),
        .full(out_full), .empty(out_empty)
    );

    /// Máquina de estados finita (FSM) para control de flujo
    typedef enum logic [1:0] {
        IDLE    = 2'd0, ///< Espera datos y código válido
        READ    = 2'd1, ///< Lectura de vectores
        COMPUTE = 2'd2, ///< Cálculo del producto vectorial
        WRITE   = 2'd3  ///< Escritura del resultado
    } state_t;

    state_t state, next_state;

    /// Registros para componentes individuales de entrada y resultado
    logic signed [COMPONENT_WIDTH-1:0] a1, b1, c1;
    logic signed [COMPONENT_WIDTH-1:0] a2, b2, c2;
    logic signed [COMPONENT_WIDTH-1:0] x3, y3, z3;

    /**
     * @brief Lógica secuencial de control de estado y señales
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            in1_rd_en  <= 1'b0;
            in2_rd_en  <= 1'b0;
            out_wr_en  <= 1'b0;
        end else begin
            state <= next_state;
            in1_rd_en <= 1'b0;
            in2_rd_en <= 1'b0;
            out_wr_en <= 1'b0;

            case (state)
                IDLE: begin
                    if (op_code == OP_CROSS && !in1_empty && !in2_empty && !out_full) begin
                        in1_rd_en <= 1'b1;
                        in2_rd_en <= 1'b1;
                    end
                end
                READ: begin
                    {a1, b1, c1} <= in1_data_out;
                    {a2, b2, c2} <= in2_data_out;
                end
                COMPUTE: begin
                    x3 <= b1*c2 - c1*b2;
                    y3 <= c1*a2 - a1*c2;
                    z3 <= a1*b2 - b1*a2;
                end
                WRITE: begin
                    out_data_in <= {x3, y3, z3};
                    out_wr_en   <= 1'b1;
                end
            endcase
        end
    end

    /**
     * @brief Lógica combinacional para la transición de estados de la FSM
     */
    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (in1_rd_en && in2_rd_en) next_state = READ;
            READ:    next_state = COMPUTE;
            COMPUTE: next_state = WRITE;
            WRITE:   next_state = IDLE;
        endcase
    end

endmodule
