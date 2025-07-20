`timescale 1ns/1ps
/*
 * -------------------------------------------------------------------------
 * Project : Aceleración de procesamiento de datos HSI en X-Heep
 * File    : hsi_accel_obi_tb.sv
 * Author  : Alejandro Fernández Rodríguez, UCLM
 * Version : 1.0
 * Date    : 2025
 * License : MIT License
 *
 * Copyright (c) 2025 Alejandro Fernández Rodríguez
 * -------------------------------------------------------------------------
 * Testbench para hsi_accel_obi: validación funcional del diseño integrado
 * compuesto por el núcleo `hsi_vector_core`, su wrapper OBI y lógica de FIFO.
 *
 * Requisitos validados:
 * R1.1: Escritura de registros OP_CODE y NUM_BANDS a través del bus OBI.
 * R1.2: Ejecución correcta de la operación vectorial CROSS con 3 bandas.
 * R2.1: Ejecución correcta de la operación vectorial DOT con 3 bandas.
 * R2.2: Validación del resultado DOT: sólo componente Z no nulo.
 * R3.1: Detección de error ERR_OP cuando num_bands != 3 para OP_CODE=CROSS.
 * R3.2: Detección de error ERR_BANDS cuando num_bands > COMPONENTS_MAX.
 *
 * Cobertura funcional:
 * - Camino de escritura y lectura por OBI.
 * - Flujo completo de datos vectoriales mediante FIFOs internas.
 * - Manejo de condiciones de error mediante STATUS y ERROR_CODE.
 * - Verificación cruzada de resultados numéricos (producto punto y cruz).
 * -------------------------------------------------------------------------
 */

module hsi_accel_obi_tb;

  // ---------------------------------------
  // Parámetros del diseño
  // ---------------------------------------
  parameter COMPONENT_WIDTH = 16;
  parameter COMPONENTS_MAX  = 3;
  parameter FIFO_DEPTH      = 8;

  localparam [31:0] OP_CROSS = 32'd1;
  localparam [31:0] OP_DOT   = 32'd2;
  /* verilator lint_off UNUSEDPARAM */
  localparam ERR_NONE  = 4'd0;
  /* verilator lint_on UNUSEDPARAM */
  localparam ERR_OP    = 4'd1;
  localparam ERR_BANDS = 4'd4;
  


  // ---------------------------------------
  // Señales del testbench
  // ---------------------------------------
  logic clk = 0;
  logic rst_ni;

  // Bus OBI
  logic req_i, we_i;
  logic [3:0] be_i;
  logic [31:0] addr_i, wdata_i;
  /* verilator lint_off UNUSEDSIGNAL */
  logic gnt_o, rvalid_o, err_o;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0] rdata_o;

  // Datos HSI
  logic in1_wr_en, in2_wr_en;
  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] in1_data_i, in2_data_i;
  logic out_rd_en;
  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] out_data_o;
  logic out_empty_o;

  // Internos
  integer error_count = 0;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] data_rd;
  /* verilator lint_on UNUSEDSIGNAL */

  // ---------------------------------------
  // Instancia del DUT
  // ---------------------------------------
  hsi_accel_obi #(
    .COMPONENT_WIDTH(COMPONENT_WIDTH),
    .COMPONENTS_MAX(COMPONENTS_MAX),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_ni),
    .req_i(req_i),
    .we_i(we_i),
    .be_i(be_i),
    .addr_i(addr_i),
    .wdata_i(wdata_i),
    .gnt_o(gnt_o),
    .rvalid_o(rvalid_o),
    .rdata_o(rdata_o),
    .err_o(err_o),
    .in1_wr_en_i(in1_wr_en),
    .in2_wr_en_i(in2_wr_en),
    .in1_data_i(in1_data_i),
    .in2_data_i(in2_data_i),
    .out_rd_en_i(out_rd_en),
    .out_empty_o(out_empty_o),
    .out_data_o(out_data_o)
  );

  // ---------------------------------------
  // Clock & Reset
  // ---------------------------------------
  always #5 clk = ~clk;

  initial begin
    req_i = 0; we_i = 0; be_i = 0; addr_i = 0; wdata_i = 0;
    in1_wr_en = 0; in2_wr_en = 0; out_rd_en = 0;
    rst_ni = 0;
    repeat (3) @(posedge clk);
    rst_ni = 1;
  end

  // ---------------------------------------
  // Funciones auxiliares
  // ---------------------------------------
  task obi_write(input [31:0] addr, input [31:0] data, input [3:0] be);
    begin
      @(posedge clk);
      addr_i = addr; wdata_i = data; be_i = be; we_i = 1'b1; req_i = 1'b1;
      @(posedge clk);
      req_i = 0; we_i = 0;
    end
  endtask

  task obi_read(input [31:0] addr, output [31:0] data);
    begin
      @(posedge clk);
      addr_i = addr; we_i = 0; req_i = 1'b1; be_i = 4'hF;
      @(posedge clk);
      req_i = 0;
      wait (rvalid_o);
      data = rdata_o;
    end
  endtask

  function automatic signed [COMPONENT_WIDTH-1:0] get_comp(
    input logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] vec,
    input int idx
  );
    get_comp = vec[(COMPONENTS_MAX-idx-1)*COMPONENT_WIDTH +: COMPONENT_WIDTH];
  endfunction

  task push_vectors(
    input signed [COMPONENT_WIDTH-1:0] x1, y1, z1,
    input signed [COMPONENT_WIDTH-1:0] x2, y2, z2
  );
    begin
      @(posedge clk);
      in1_data_i = {x1, y1, z1};
      in2_data_i = {x2, y2, z2};
      in1_wr_en  = 1;
      in2_wr_en  = 1;
      @(posedge clk);
      in1_wr_en  = 0;
      in2_wr_en  = 0;
    end
  endtask

  task wait_result(output signed [COMPONENT_WIDTH-1:0] rx, ry, rz);
    begin
      wait (!out_empty_o);
      @(posedge clk);
      out_rd_en = 1;
      @(posedge clk);
      out_rd_en = 0;
      rx = get_comp(out_data_o, 0);
      ry = get_comp(out_data_o, 1);
      rz = get_comp(out_data_o, 2);
    end
  endtask

  task check_result(input string label, input signed expected0, expected1, expected2,
                    input signed actual0, actual1, actual2);
    begin
      if (expected0 === actual0 && expected1 === actual1 && expected2 === actual2)
        $display("[PASS] %s -> (%0d,%0d,%0d)", label, actual0, actual1, actual2);
      else begin
        $error("[FAIL] %s: esperado (%0d,%0d,%0d) pero obtuve (%0d,%0d,%0d)",
               label, expected0, expected1, expected2, actual0, actual1, actual2);
        error_count++;
      end
    end
  endtask

  // ---------------------------------------
  // Test principal
  // ---------------------------------------
  initial begin : testbench
    logic signed [COMPONENT_WIDTH-1:0] rx;
    logic signed [COMPONENT_WIDTH-1:0] ry;
    logic signed [COMPONENT_WIDTH-1:0] rz;


    // Esperar reset
    wait (rst_ni);
    repeat (2) @(posedge clk);

    // Configurar operación CROSS con 3 bandas
    obi_write(32'h00, OP_CROSS, 4'hF);     // OP_CODE
    obi_write(32'h04, 32'd3, 4'hF);        // NUM_BANDS

    // Cargar vectores: (1,0,0) x (0,1,0) = (0,0,1)
    push_vectors(16'sd1, 0, 0, 0, 16'sd1, 0);
    obi_write(32'h08, 32'h1, 4'hF);        // START

    wait_result(rx, ry, rz);
    check_result("R1.2 (CROSS)", 0, 0, 1, rx, ry, rz);

    // Producto punto: (1,2,3)·(4,5,6) = 1*4+2*5+3*6 = 32
    obi_write(32'h00, OP_DOT, 4'hF);
    push_vectors(1,2,3, 4,5,6);
    obi_write(32'h08, 32'h1, 4'hF);

    wait_result(rx, ry, rz);

    // Verifica también rx y ry (deben ser cero en producto punto)
    if (rx !== 0 || ry !== 0 || rz !== 32) begin
    $error("[FAIL] R2.2 (DOT): resultado (%0d,%0d,%0d), esperado (0,0,32)", rx, ry, rz);
    error_count++;
    end else
    $display("[PASS] R2.2 (DOT): resultado (%0d,%0d,%0d)", rx, ry, rz);


    // Error: OP_CROSS pero num_bands != 3
    obi_write(32'h00, OP_CROSS, 4'hF);
    obi_write(32'h04, 2, 4'hF);
    obi_write(32'h08, 1, 4'hF);
    obi_read(32'h0C, data_rd);
    if (data_rd[4:1] !== ERR_OP)
      $error("[FAIL] R3.1: ERROR_CODE esperado %0d, got %0d", ERR_OP, data_rd[4:1]);
    else
      $display("[PASS] R3.1: ERROR_CODE = %0d", data_rd[4:1]);

    // Error: num_bands > MAX
    obi_write(32'h04, COMPONENTS_MAX + 1, 4'hF);
    obi_write(32'h08, 1, 4'hF);
    obi_read(32'h0C, data_rd);
    if (data_rd[4:1] !== ERR_BANDS)
      $error("[FAIL] R3.2: ERROR_CODE esperado %0d, got %0d", ERR_BANDS, data_rd[4:1]);
    else
      $display("[PASS] R3.2: ERROR_CODE = %0d", data_rd[4:1]);

    if (error_count == 0)
      $display("TEST COMPLETOTODOS LOS REQUISITOS VERIFICADOS CON ÉXITO");
    else
      $display("TEST COMPLETO ERRORES DETECTADOS: %0d", error_count);

    $finish;
  end

endmodule
