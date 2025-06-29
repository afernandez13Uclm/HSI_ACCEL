/*
 * -------------------------------------------------------------------------
 * Testbench: tb_hsi_vector_core.sv
 * Project    : Aceleración de procesamiento de datos HSI en X-Heep
 * Author     : Alejandro Fernández Rodríguez, UCLM
 * Version    : 1.0
 * Date       : 2025
 * License    : MIT
 * Copyright (c) 2025 Alejandro Fernández Rodríguez
 *
 * -------------------------------------------------------------------------
 * Requisitos funcionales:
 * R1: El core debe calcular correctamente el producto vectorial de dos 
 *      vectores de 3 componentes con signo.
 * R1.2: (1,0,0)x(0,1,0) -> (0,0,1)
 * R1.3: (0,0,1)x(1,0,0) -> (0,1,0)
 * R1.4: (1,2,3)x(4,5,6) -> (-3,6,-3)
 * R1.5: Componentes negativas correctamente: (-1,0,0)x(0,1,0) -> (0,0,-1)
 * R2: El core debe calcular correctamente el producto punto de dos 
 *      vectores de 3 componentes con signo.
 * R2.1: (1,0,0)·(0,1,0) = 0
 * R2.2: (1,2,3)·(4,5,6) = 32
 * R2.3: (-1,0,0)·(0,1,0) = 0
 * R3: El core debe gestionar correctamente los errores:
 * R3.1: Si se recibe un código de operación OP_CROSS pero num_bands != 3, debe generar ERR_OP.
 * R3.2: Si num_bands > COMPONENTS_MAX, debe generar ERR_BANDS.
 * -------------------------------------------------------------------------
 */
`timescale 1ns/1ps
module hsi_vector_core_tb;

  //---------------------------------------------------------------------------
  // Parámetros y constantes
  //---------------------------------------------------------------------------
  parameter int COMPONENT_WIDTH = 16;
  parameter int COMPONENTS_MAX  = 3;      
  parameter int FIFO_DEPTH      = 8;

  localparam logic [3:0] OP_CROSS = 4'd1;
  localparam logic [3:0] OP_DOT   = 4'd2;

  // Códigos de error RTL:
  localparam ERR_NONE   = 4'd0;
  localparam ERR_OP     = 4'd1;
  localparam ERR_BANDS  = 4'd4;

  //---------------------------------------------------------------------------
  // Señales
  //---------------------------------------------------------------------------
  // reloj y reset
  logic clk = 0;
  logic rst_n;

  // Entradas DUT
  logic                       in1_wr_en,  in2_wr_en;
  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] in1_data_in, in2_data_in;
  /* verilator lint_off UNUSEDSIGNAL */
  logic                       in1_full,    in2_full;
  /* verilator lint_on UNUSEDSIGNAL */

  // Salidas DUT
  logic                       out_rd_en;
  /* verilator lint_off UNUSEDSIGNAL */
  logic                       out_empty,   out_full;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] out_data_out;

  // Control
  logic [3:0]  op_code;
  logic [31:0] num_bands;                
  logic        start      = 1'b0;

  // Estado / error
  logic        pixel_done;
  logic [3:0]  error_code;

  // Flags para verificación
  logic passed2, passed3, passed4, passed5;     // R1 (cross)
  logic passed6, passed7, passed8;              // R2 (dot)
  logic passed_err1, passed_err2;               // R3 (errores)

  //---------------------------------------------------------------------------
  // Instancia del DUT
  //---------------------------------------------------------------------------
  hsi_vector_core #(
      .COMPONENT_WIDTH(COMPONENT_WIDTH),
      .FIFO_DEPTH     (FIFO_DEPTH),
      .COMPONENTS_MAX (COMPONENTS_MAX)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .in1_wr_en(in1_wr_en),
      .in1_data_in(in1_data_in),
      .in1_full(in1_full),
      .in2_wr_en(in2_wr_en),
      .in2_data_in(in2_data_in),
      .in2_full(in2_full),
      .out_rd_en(out_rd_en),
      .out_empty(out_empty),
      .out_data_out(out_data_out),
      .out_full(out_full),
      .op_code(op_code),
      .num_bands(num_bands),
      .start(start),
      .pixel_done(pixel_done),
      .error_code(error_code)
  );

  //---------------------------------------------------------------------------
  // Reloj
  //---------------------------------------------------------------------------
  always #5 clk = ~clk;

  //---------------------------------------------------------------------------
  // Funciones auxiliares
  //---------------------------------------------------------------------------
  function automatic signed [COMPONENT_WIDTH-1:0] get_comp(
      input logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] vec,
      input int idx
  );
      get_comp = vec[(COMPONENTS_MAX-idx-1)*COMPONENT_WIDTH +: COMPONENT_WIDTH];
  endfunction

  task push_vectors(
      input signed [COMPONENT_WIDTH-1:0] a1, b1, c1,
      input signed [COMPONENT_WIDTH-1:0] a2, b2, c2
  );
      logic [COMPONENT_WIDTH*COMPONENTS_MAX-1:0] v1, v2;
      begin
          v1 = {a1, b1, c1};
          v2 = {a2, b2, c2};
          @(posedge clk);
              in1_data_in = v1;
              in2_data_in = v2;
              in1_wr_en   = 1;
              in2_wr_en   = 1;
          @(posedge clk);
              in1_wr_en   = 0;
              in2_wr_en   = 0;
      end
  endtask

  //---------------------------------------------------------------------------
  // Cobertura funcional 
  //---------------------------------------------------------------------------
`ifndef VERILATOR
  covergroup cg_vector @(posedge clk);
      coverpoint op_code      { bins cross = {OP_CROSS}; bins dot = {OP_DOT}; }
      coverpoint error_code   { bins ok[]  = {[0:4]}; } 
      coverpoint pixel_done   { bins pulse = {1}; }
  endgroup
  cg_vector cg = new();
  always @(posedge clk) if (pixel_done) cg.sample();
`endif

  //---------------------------------------------------------------------------
  // Test sequence principal
  //---------------------------------------------------------------------------
  initial begin
      // Inicialización
      in1_wr_en = 0; in2_wr_en = 0; out_rd_en = 0;
      start      = 0;
      passed2=0; passed3=0; passed4=0; passed5=0;
      passed6=0; passed7=0; passed8=0;
      passed_err1=0; passed_err2=0;

      // Reset síncrono activo a bajo
      rst_n = 0; num_bands = 3; op_code = OP_CROSS;
      #20 rst_n = 1;
      @(posedge clk);

      // --------------------------------------------------------------------
      // R1 – Cross-product
      // --------------------------------------------------------------------
      // R1.2  (1,0,0)x(0,1,0) -> (0,0,1)
      cross_test(1,0,0, 0,1,0, 0,0,1, passed2, "R1.2");

      // R1.3  (0,0,1)x(1,0,0) -> (0,1,0)
      cross_test(0,0,1, 1,0,0, 0,1,0, passed3, "R1.3");

      // R1.4  (1,2,3)x(4,5,6) -> (-3,6,-3)
      cross_test(1,2,3, 4,5,6, -3,6,-3, passed4, "R1.4");

      // R1.5  (-1,0,0)x(0,1,0) -> (0,0,-1)
      cross_test(-1,0,0, 0,1,0, 0,0,-1, passed5, "R1.5");

      if (passed2 & passed3 & passed4 & passed5)
          $display("R1 PASSED.");
      else
          $fatal("R1 FAILED.");

      // --------------------------------------------------------------------
      // R2 – Dot-product
      // --------------------------------------------------------------------
      op_code   = OP_DOT;
      num_bands = 3;

      // R2.1  (1,0,0)·(0,1,0) = 0
      dot_test(1,0,0, 0,1,0, 0, passed6, "R2.1");

      // R2.2  (1,2,3)·(4,5,6) = 32
      dot_test(1,2,3, 4,5,6, 32, passed7, "R2.2");

      // R2.3  (-1,0,0)·(0,1,0) = 0
      dot_test(-1,0,0, 0,1,0, 0, passed8, "R2.3");

      if (passed6 & passed7 & passed8)
          $display("R2 PASSED.");
      else
          $fatal("R2 FAILED.");

      // --------------------------------------------------------------------
      // R3 – Gestión de errores
      // --------------------------------------------------------------------
      // R3.1  OP_CROSS pero num_bands != 3  -> ERR_OP
      @(posedge clk);
      op_code   = OP_CROSS;
      num_bands = 2;     // configuración ilegal
      start      = 1; // iniciar operación
      @(posedge clk);
      start      = 0; // finalizar operación
      @(posedge clk);
      if (error_code == ERR_OP) begin
          passed_err1 = 1;
          $display("R3.1 PASSED (ERR_OP detectado).");
      end else $fatal("R3.1 FAILED (error_code=%0d)", error_code);

      // R3.2  num_bands > COMPONENTS_MAX      -> ERR_BANDS
      @(posedge clk);
      op_code   = OP_DOT;
      num_bands = COMPONENTS_MAX + 1;
      start      = 1; // iniciar operación
      @(posedge clk);
      start      = 0; // finalizar operación
      @(posedge clk);
      if (error_code == ERR_BANDS) begin
          passed_err2 = 1;
          $display("R3.2 PASSED (ERR_BANDS detectado).");
      end else $fatal("R3.2 FAILED (error_code=%0d)", error_code);

      if (passed_err1 & passed_err2)
          $display("R3 PASSED.");
      else
          $fatal("R3 FAILED.");

      //---------------------------------------------------------------------
      $display("Todas las verificaciones completadas con éxito.");
      $finish;
  end // initial

  //---------------------------------------------------------------------------
  // Tareas específicas de cada tipo de test
  //---------------------------------------------------------------------------
  task automatic cross_test(
    input  logic signed [COMPONENT_WIDTH-1:0] x1, y1, z1,
    input  logic signed [COMPONENT_WIDTH-1:0] x2, y2, z2,
    input  logic signed [COMPONENT_WIDTH-1:0] exp_x, exp_y, exp_z,
    output logic                            flag,
    input  string                           tag
  );
    // variables locales
    logic signed [COMPONENT_WIDTH-1:0] rx, ry, rz;
    begin
      push_vectors(x1,y1,z1, x2,y2,z2);
      @(posedge clk) start = 1;
      @(posedge clk) start = 0;
      wait (!out_empty);
      @(posedge clk) out_rd_en = 1;
      @(posedge clk) begin
        out_rd_en = 0;
        if (!pixel_done)
          $error("%s FAILED: pixel_done no activo.", tag);

        // extraer componentes
        rx = get_comp(out_data_out, 0);
        ry = get_comp(out_data_out, 1);
        rz = get_comp(out_data_out, 2);

        if (rx==exp_x && ry==exp_y && rz==exp_z && error_code==ERR_NONE) begin
          flag = 1;
          $display("%s PASSED: (%0d,%0d,%0d)", tag, rx, ry, rz);
        end else begin
          flag = 0;
          $error("%s FAILED: got (%0d,%0d,%0d) err=%0d",
                 tag, rx, ry, rz, error_code);
        end
      end
    end
  endtask


  task automatic dot_test(
    input  logic signed [COMPONENT_WIDTH-1:0] x1, y1, z1,
    input  logic signed [COMPONENT_WIDTH-1:0] x2, y2, z2,
    input  logic signed [31:0]               exp,
    output logic                            flag,
    input  string                           tag
  );
    // variable local
    logic signed [COMPONENT_WIDTH-1:0] r;
    begin
      push_vectors(x1,y1,z1, x2,y2,z2);
      @(posedge clk) start = 1;
      @(posedge clk) start = 0;
      wait (!out_empty);
      @(posedge clk) out_rd_en = 1;
      @(posedge clk) begin
        out_rd_en = 0;
        if (!pixel_done)
          $error("%s FAILED: pixel_done no activo.", tag);

        // extraer resultado (solo componente 2)
        r = get_comp(out_data_out, 2);

        if (r == exp[COMPONENT_WIDTH-1:0] && error_code==ERR_NONE) begin
          flag = 1;
          $display("%s PASSED: result=%0d", tag, r);
        end else begin
          flag = 0;
          $error("%s FAILED: result=%0d exp=%0d err=%0d",
                 tag, r, exp, error_code);
        end
      end
    end
  endtask


endmodule
