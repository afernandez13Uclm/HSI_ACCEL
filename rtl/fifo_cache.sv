/**
 * @file fifo_cache.sv
 * @brief Módulo FIFO Cache para procesamiento de datos HSI en X-HEEP.
 *
 * @details
 * Implementación de una memoria FIFO síncrona que permite escritura y lectura controladas, indicadores 
 * de lleno/vacío y gestión eficiente de punteros mediante bit de fase. Ideal para utilizarse como 
 * caché temporal en flujos paralelos de procesamiento de datos HSI (Hyperspectral Imaging).
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
 * @class fifo_cache
 * @brief Módulo FIFO Cache parametrizable para aplicaciones de procesamiento HSI.
 *
 * @details
 * Memoria FIFO síncrona parametrizable con soporte para escritura y lectura simultánea controlada,
 * indicadores claros de FIFO lleno/vacío y manejo optimizado de punteros con bit de fase. Es especialmente
 * útil en arquitecturas paralelas de procesamiento de imágenes hiperespectrales.
 *
 * @param WIDTH Ancho en bits de los datos almacenados en la FIFO (por defecto: 16).
 * @param DEPTH Profundidad máxima de almacenamiento de la FIFO, debe ser potencia de dos (por defecto: 16).
 *
 * @section signals Descripción de señales de entrada y salida
 * | Señal    | Dirección | Descripción                        |
 * |----------|-----------|------------------------------------|
 * | clk      | input     | Reloj principal del sistema.       |
 * | rst_n    | input     | Reset activo en bajo.              |
 * | wr_en    | input     | Habilitación de escritura.         |
 * | rd_en    | input     | Habilitación de lectura.           |
 * | data_in  | input     | Datos de entrada para la FIFO.     |
 * | data_out | output    | Datos de salida de la FIFO.        |
 * | full     | output    | Indicador de FIFO completamente llena. |
 * | empty    | output    | Indicador de FIFO completamente vacía. |
 *
 * @section usage Ejemplo de instanciación
 *
 * @code{.sv}
 * fifo_cache #( .WIDTH(32), .DEPTH(32) ) fifo_inst (
 *     .clk(clk),
 *     .rst_n(rst_n),
 *     .wr_en(wr_en),
 *     .rd_en(rd_en),
 *     .data_in(data_in),
 *     .data_out(data_out),
 *     .full(full),
 *     .empty(empty)
 * );
 * @endcode
 */
module fifo_cache #(
    parameter int WIDTH = 16,
    parameter int DEPTH = 16
) (
    input  logic                  clk,       ///< Señal de reloj
    input  logic                  rst_n,     ///< Reset asíncrono activo en bajo
    input  logic                  wr_en,     ///< Habilitación de escritura
    input  logic                  rd_en,     ///< Habilitación de lectura
    input  logic [WIDTH-1:0]      data_in,   ///< Datos de entrada a escribir
    output logic [WIDTH-1:0]      data_out,  ///< Datos de salida leídos
    output logic                  full,      ///< Indicador de FIFO llena
    output logic                  empty      ///< Indicador de FIFO vacía
);

    /// Punteros internos con bit de fase para control eficiente de escritura y lectura
    logic [$clog2(DEPTH):0] wr_ptr, rd_ptr;

    /// Almacenamiento interno de la FIFO
    logic [WIDTH-1:0] fifo_mem [0:DEPTH-1];

    /**
     * @brief Cálculo combinacional del estado de los indicadores full y empty.
     *
     * - full: indica que la FIFO está completamente llena.
     * - empty: indica que la FIFO está completamente vacía.
     */
    assign full  = (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0])
                && (wr_ptr[$clog2(DEPTH)] != rd_ptr[$clog2(DEPTH)]);

    assign empty = (wr_ptr == rd_ptr);

    /**
     * @brief Proceso secuencial principal para operaciones de lectura/escritura.
     *
     * - Inicialización al reset.
     * - Manejo eficiente de lectura y escritura según señales y estados internos.
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            data_out <= '0;
        end else begin
            if (wr_en && !full) begin
                fifo_mem[wr_ptr[$clog2(DEPTH)-1:0]] <= data_in;
                wr_ptr <= wr_ptr + 1;
            end
            if (rd_en && !empty) begin
                data_out <= fifo_mem[rd_ptr[$clog2(DEPTH)-1:0]];
                rd_ptr   <= rd_ptr + 1;
            end
        end
    end

endmodule
