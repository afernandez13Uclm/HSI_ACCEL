// Testbench para hsi_vector_core_wrapper
`timescale 1ns/1ps

/**
 * -------------------------------------------------------------------------
 * Testbench: hsi_vector_core_wrapper_tb.sv
 * Project    : Aceleración de procesamiento de datos HSI en X-Heep
 * Author     : Alejandro Fernández Rodríguez, UCLM
 * Version    : 1.0
 * Date       : 2025
 * License    : MIT
 * Copyright (c) 2025 Alejandro Fernández Rodríguez
 *
 * -------------------------------------------------------------------------
 * Testbench para el módulo hsi_vector_core_wrapper
 *
 * Objetivo:
 *  - Validar el funcionamiento del wrapper OBI del core vectorial HSI.
 *  - Verificar mediante asserts los requisitos funcionales R1-R6.
 *  - Aplicar cobertura aleatoria para evaluar el comportamiento ante múltiples configuraciones.
 *
 * Requisitos funcionales comprobados:
 *  R1: Señal start_o se activa tras escritura válida a CTRL
 *  R2: Señal pixel_size_o refleja valor escrito
 *  R3: Señal op_code_o está en rango [0-2]
 *  R4: STATUS refleja correctamente estados busy y valid_result
 *  R5: RESULT refleja correctamente el valor result_i
 *  R6: PIXEL_DONE refleja correctamente pixel_done_i
 */
module hsi_vector_core_wrapper_tb;
  logic clk;
  logic rst_n;

  // Señales OBI simuladas
  logic        req;
  logic [7:0]  addr;
  logic        we;
  logic [31:0] wdata;
  logic [31:0] rdata;
  logic        rvalid;

  // Señales simuladas del core
  logic        start;
  logic [1:0]  op_code;
  logic [15:0] pixel_size;
  logic [15:0] result;
  logic        valid_result;
  logic        pixel_done;
  logic        busy;

  // DUT
  hsi_vector_core_wrapper dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .req_i(req),
    .addr_i(addr),
    .we_i(we),
    .wdata_i(wdata),
    .rdata_o(rdata),
    .rvalid_o(rvalid),
    .start_o(start),
    .op_code_o(op_code),
    .pixel_size_o(pixel_size),
    .result_i(result),
    .valid_result_i(valid_result),
    .pixel_done_i(pixel_done),
    .busy_i(busy)
  );

  // Reloj
  always #5 clk = ~clk;

  task write_reg(input [7:0] a, input [31:0] d);
    begin
      @(posedge clk);
      req   = 1;
      we    = 1;
      addr  = a;
      wdata = d;
      @(posedge clk);
      req = 0;
      @(posedge clk);
      $display("WRITE @ 0x%0h = 0x%08x", a, d);
    end
  endtask

  task write_and_check_start(input [7:0] a, input [31:0] d);
    begin
      @(posedge clk);
      req   = 1;
      we    = 1;
      addr  = a;
      wdata = d;
      @(posedge clk);
      $display("WRITE+CHECK @ 0x%0h = 0x%08x", a, d);
      assert(start === 1'b1) else $fatal("[R1] ERROR: start_o no fue activado en ciclo de escritura");
      $display("[R1] OK: start_o activado correctamente");
      req = 0;
      @(posedge clk);
      assert(start === 1'b0) else $fatal("[R1] ERROR: start_o no volvió a cero");
      $display("[R1] OK: start_o volvió a cero correctamente");
    end
  endtask

  task read_reg(input [7:0] a);
    begin
      @(posedge clk);
      req  = 1;
      we   = 0;
      addr = a;
      @(posedge clk);
      req = 0;
      @(posedge clk); // esperar a rvalid
      $display("READ  @ 0x%0h = 0x%08x (rvalid=%0b)", a, rdata, rvalid);
    end
  endtask
  logic [1:0] op;
  int px;
  int res;
  initial begin
    // Inicialización
    clk = 0;
    rst_n = 0;
    req = 0;
    we = 0;
    wdata = 0;
    addr = 0;
    result = 16'hBEEF;
    valid_result = 0;
    pixel_done = 0;
    busy = 0;

    // Reset
    repeat (2) @(posedge clk);
    rst_n = 1;

    // Prueba determinista
    write_and_check_start(8'h0, 32'b0000_0000_0000_0000_0000_0000_0000_0101);
    write_reg(8'h4, 32'd64);
    $display("OPCODE: %0d, PIXEL_SIZE: %0d", op_code, pixel_size);
    assert(op_code === 2'd2) else $fatal("[R3] ERROR: op_code_o incorrecto (esperado 2)");
    $display("[R3] OK: op_code correcto");
    assert(pixel_size === 16'd64) else $fatal("[R2] ERROR: pixel_size_o incorrecto (esperado 64)");
    $display("[R2] OK: pixel_size correcto");

    busy = 1;
    read_reg(8'h8);
    assert(rdata === 32'd1) else $fatal("[R4] ERROR: STATUS esperado = 1 cuando busy = 1");
    $display("[R4] OK: STATUS ocupado detectado correctamente");

    busy = 0;
    valid_result = 1;
    read_reg(8'h8);
    assert(rdata === 32'd2) else $fatal("[R4] ERROR: STATUS esperado = 2 cuando valid_result = 1");
    $display("[R4] OK: STATUS terminado detectado correctamente");

    read_reg(8'hC);
    assert(rdata === 32'h0000BEEF) else $fatal("[R5] ERROR: RESULT incorrecto (esperado 0x0000BEEF)");
    $display("[R5] OK: RESULT correcto en prueba determinista");

    pixel_done = 1;
    read_reg(8'h10);
    assert(rdata === 32'd1) else $fatal("[R6] ERROR: PIXEL_DONE aleatorio esperado = 1");
      $display("[R6] OK: PIXEL_DONE aleatorio correcto");
    $display("[R6] OK: PIXEL_DONE correcto en prueba determinista");

    // Prueba aleatoria con múltiples valores
    repeat (5) begin
      busy = 0;
      
      op = $urandom % 3;
      px = $urandom % 1024;
      res = $urandom & 32'h0000_FFFF;

      result = res[15:0];
      valid_result = 1;
      pixel_done = 1;

      write_and_check_start(8'h0, {29'd0, op[1:0], 1'b1});
      write_reg(8'h4, px);

      assert(op_code <= 2'd2) else $fatal("[R3] ERROR: op_code fuera de rango");
      $display("[R3] OK: op_code aleatorio en rango");
      assert(pixel_size == px[15:0]) else $fatal("[R2] ERROR: pixel_size no coincide con lo escrito");
      $display("[R2] OK: pixel_size aleatorio correcto");

      read_reg(8'hC);
      assert(rdata[15:0] == res[15:0]) else $fatal("[R5] ERROR: RESULT aleatorio no coincide (esperado 0x%04x)", res);
      $display("[R5] OK: RESULT aleatorio correcto (0x%04x)", res);
      read_reg(8'h10);
      assert(rdata === 32'd1) else $fatal("[R6] ERROR: PIXEL_DONE aleatorio esperado = 1");
    end

    $display("TEST COMPLETO - TODO OK");
        @(posedge clk); // Esperar un ciclo para que se impriman los displays
    $finish;
  end
endmodule
