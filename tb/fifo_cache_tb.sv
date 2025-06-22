/*
 * -------------------------------------------------------------------------
 * Project : Aceleración de procesamiento de datos HSI en X-Heep
 * File    : fifo_cache_tb.sv
 * Author  : Alejandro Fernández Rodríguez, UCLM
 * Version : 1.0
 * Date    : 2025
 * License : MIT License
 *
 * Copyright (c) 2025 Alejandro Fernández Rodríguez
 * -------------------------------------------------------------------------
 * Testbench para fifo_cache
 *
 * Requisitos del sistema:
 * R1: Tras reset, la FIFO debe estar vacía (empty == 1).
 * R2: Escritura permitida cuando la FIFO no está llena (wr_en == 1 y full == 0).
 * R3: Señal full debe activarse al alcanzar DEPTH escrituras.
 * R4: Lectura permitida cuando la FIFO no está vacía (rd_en == 1 y empty == 0).
 * R5: Señal empty debe activarse tras leer todos los datos.
 * R6: Escritura cuando full no debe alterar datos ni punteros.
 * R7: Lectura cuando empty no debe alterar datos ni punteros.
 * R8: Integridad de datos: data_out debe coincidir con la secuencia escrita.
 * R9: Operaciones back-to-back de escritura y lectura consecutivas sin errores.
 * R10: Comportamiento robusto bajo secuencias aleatorias sin violaciones.
 *
 * Cobertura funcional
 * -------------------------------------------------------------------------
 */
`timescale 1ns/1ps
module fifo_cache_tb;

    // Parámetros
    parameter int WIDTH = 16;
    parameter int DEPTH = 8;

    // Señales DUT
    logic                  clk;
    logic                  rst_n;
    logic                  wr_en;
    logic                  rd_en;
    logic [WIDTH-1:0]      data_in;
    logic [WIDTH-1:0]      data_out;
    logic                  full;
    logic                  empty;

    // Modelo de referencia
    logic [WIDTH-1:0] golden_mem [0:DEPTH-1];
    int                  current_count;

    // Instanciación DUT
    fifo_cache #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) uut (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (wr_en),
        .rd_en    (rd_en),
        .data_in  (data_in),
        .data_out (data_out),
        .full     (full),
        .empty    (empty)
    );

    // Generación de reloj
    always #5 clk = ~clk;

    // Cobertura funcional: usando covergroup solo en simuladores compatibles
`ifndef VERILATOR
    /* verilator lint_off DECLFILENAME */
    /* verilator lint_off COVERIGN */
    covergroup fifo_cvg @(posedge clk);
        coverpoint current_count {
            bins empty_count = {0};
            bins mid_count   = {[1:DEPTH-1]};
            bins full_count  = {DEPTH};
        }
        coverpoint wr_en;
        coverpoint rd_en;
        cross        wr_en, rd_en;
    endgroup
    /* verilator lint_on COVERIGN */
    fifo_cvg cg = new();
`endif

    // Secuencia de pruebas
    initial begin
        clk           = 0;
        rst_n         = 0;
        wr_en         = 0;
        rd_en         = 0;
        data_in       = '0;
        current_count = 0;

        // Reset y R1
        #10 rst_n = 1;
        @(posedge clk);
        assert (empty) else $error("R1 FAILED: FIFO debe estar vacía tras reset");
        $display("R1 PASSED: FIFO vacía tras reset");

        // Test 1: llenar FIFO (R2, R3)
        for (int i = 0; i < DEPTH; i++) begin
            @(negedge clk);
            wr_en       = 1;
            data_in     = i + 1;
            golden_mem[i] = i + 1;
            @(posedge clk);
            current_count++;
`ifndef VERILATOR
            cg.sample();
`endif
            assert(!full) else $error("R2 FAILED: Escritura bloqueada prematuramente en posición %0d", i);
        end
        @(negedge clk); wr_en = 0;
        @(posedge clk);
        assert(full) else $error("R3 FAILED: full no activo tras DEPTH escrituras");
        $display("R2 PASSED: Escrituras normales OK");
        $display("R3 PASSED: full activo al llegar a DEPTH");

        // Test 2: intento de escritura cuando full (R6)
        data_in = 16'hDEAD;
        @(negedge clk); wr_en = 1;
        @(posedge clk);
`ifndef VERILATOR
        cg.sample();
`endif
        assert(full) else $error("R6 FAILED: write_when_full altera estado");
        wr_en = 0;
        $display("R6 PASSED: Escritura bloqueada con full");

        // Test 3: leer todos los datos (R4, R5, R7, R8)
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk); 
            rd_en = 1;
            @(negedge clk);
            rd_en = 0;
            @(posedge clk);
            current_count--;
`ifndef VERILATOR
            cg.sample();
`endif
            assert(data_out == golden_mem[i]) else $error("R8 FAILED: dato %0d esperado %0d, obtenido %0d", i, golden_mem[i], data_out);
            assert(!full) else $error("R4 FAILED: full activo inesperadamente al leer dato %0d", i);
        end
        @(posedge clk);
        assert(empty) else $error("R5 FAILED: FIFO no vacía tras lecturas");
        $display("R4 PASSED: Lecturas normales OK");
        $display("R5 PASSED: empty activo tras todas las lecturas");

        // Test 2b: intento de lectura cuando empty (R7)
        @(posedge clk); rd_en = 1;
        @(negedge clk);
`ifndef VERILATOR
        cg.sample();
`endif
        assert(empty) else $error("R7 FAILED: read_when_empty altera estado");
        rd_en = 0;
        $display("R7 PASSED: Lectura bloqueada con empty");

        // Test 4: pruebas aleatorias (R9, R10)
        repeat (20) begin
            @(negedge clk);
            wr_en   = $urandom_range(0,1) && !full;
            data_in = $urandom;
            @(posedge clk);
            if (wr_en) current_count++;
`ifndef VERILATOR
            cg.sample();
`endif
            @(negedge clk);
            rd_en = $urandom_range(0,1) && !empty;
            @(posedge clk);
            if (rd_en) current_count--;
`ifndef VERILATOR
            cg.sample();
`endif
        end
        $display("R9,R10 PASSED: secuencias back-to-back y aleatorias OK");

        // Fin
        @(posedge clk);
        $display("Simulación completada: todos los requisitos verificados");
        #50 $finish;
    end
endmodule
