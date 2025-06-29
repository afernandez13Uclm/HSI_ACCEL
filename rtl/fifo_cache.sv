/**
 * @file fifo_cache.sv
 * @brief Módulo FIFO Cache para procesamiento de datos HSI en X-HEEP
 * 
 * @details
 * Este módulo implementa una memoria FIFO síncrona con capacidad de escritura y lectura
 * controladas, indicadores de lleno/vacío y manejo de punteros con bit de fase. Está
 * diseñado para ser utilizado como caché temporal en flujos de procesamiento paralelos,
 * como los presentes en aplicaciones HSI (Hyperspectral Imaging).
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
 * @brief Módulo FIFO Cache para procesamiento de datos HSI en X-HEEP
 * @details
 *  Este módulo implementa una memoria FIFO síncrona con capacidad de escritura y lectura
 *  controladas, indicadores de lleno/vacío y manejo de punteros con bit de fase.
 *  Está diseñado para ser utilizado como caché temporal en flujos de procesamiento paralelos,
 *  como los presentes en aplicaciones HSI (Hyperspectral Imaging).
*/
module fifo_cache #(
    /**
     * @param WIDTH Ancho de los datos en bits. Valor por defecto: 16
     * @param DEPTH Profundidad de la FIFO. Debe ser una potencia de 2. Valor por defecto: 16
     */
    parameter int WIDTH = 16,
    parameter int DEPTH = 16
) (
    input  logic                  clk,       ///< Señal de reloj
    input  logic                  rst_n,     ///< Reset asíncrono activo en bajo
    input  logic                  wr_en,     ///< Habilitación de escritura
    input  logic                  rd_en,     ///< Habilitación de lectura
    input  logic [WIDTH-1:0]      data_in,   ///< Datos de entrada a escribir
    output logic [WIDTH-1:0]      data_out,  ///< Datos de salida leídos
    output logic                  full,      ///< Indicador de FIFO lleno
    output logic                  empty      ///< Indicador de FIFO vacío
);

    /**
     * @brief Punteros internos de lectura y escritura con bit de fase
     * 
     * - `wr_ptr`: puntero de escritura (log2(DEPTH)+1 bits)
     * - `rd_ptr`: puntero de lectura (log2(DEPTH)+1 bits)
     */
    logic [$clog2(DEPTH):0] wr_ptr, rd_ptr;

    /**
     * @brief Memoria interna de la FIFO
     * Vector de DEPTH entradas, cada una de WIDTH bits.
     */
    logic [WIDTH-1:0] fifo_mem [0:DEPTH-1];

    /**
     * @brief Lógica combinacional para los indicadores `full` y `empty`
     * 
     * - `full`: los punteros apuntan a la misma dirección, pero los bits de fase difieren.
     * - `empty`: los punteros son completamente iguales.
     */
    assign full  = (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0])
                && (wr_ptr[$clog2(DEPTH)]     != rd_ptr[$clog2(DEPTH)]);
    assign empty = (wr_ptr == rd_ptr);

    /**
     * @brief Lógica secuencial de lectura y escritura
     * 
     * - Reset asíncrono activo en bajo.
     * - Escritura: se realiza si `wr_en` está activo y la FIFO no está llena.
     * - Lectura: se realiza si `rd_en` está activo y la FIFO no está vacía.
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            data_out <= '0;
        end else begin
            if (wr_en && !full) begin
                fifo_mem[ wr_ptr[$clog2(DEPTH)-1:0] ] <= data_in;
                wr_ptr <= wr_ptr + 1;
            end
            if (rd_en && !empty) begin
                data_out <= fifo_mem[ rd_ptr[$clog2(DEPTH)-1:0] ];
                rd_ptr   <= rd_ptr + 1;
            end
        end
    end

endmodule
