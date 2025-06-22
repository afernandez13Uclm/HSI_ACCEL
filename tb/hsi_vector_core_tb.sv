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
 * Functional Requirements:
 * R1: El core debe calcular correctamente el producto vectorial de dos 
 *      vectores de 3 componentes con signo.
 * R1.2: (1,0,0)x(0,1,0) -> (0,0,1)
 * R1.3: (0,0,1)x(1,0,0) -> (0,1,0)
 * R1.4: (1,2,3)x(4,5,6) -> (-3,6,-3)
 * R1.5: Componentes negativas correctamente: (-1,0,0)x(0,1,0) -> (0,0,-1)
 * -------------------------------------------------------------------------
 */
`timescale 1ns/1ps

module hsi_vector_core_tb;

  // ---------------------------------------------------------------------------
  // Parámetros y constantes
  // ---------------------------------------------------------------------------
  parameter int COMPONENT_WIDTH = 16;
  parameter int OPC_WIDTH       = 2;
  localparam logic [OPC_WIDTH-1:0] OP_CROSS = 2'b01;

  // ---------------------------------------------------------------------------
  // Señales
  // ---------------------------------------------------------------------------
  // reloj y reset
  logic clk = 0;
  logic rst_n;

  // entradas DUT
  logic                  in1_wr_en, in2_wr_en;
  logic [3*COMPONENT_WIDTH-1:0] in1_data_in, in2_data_in;
  /* verilator lint_off UNUSEDSIGNAL */
  logic                  in1_full, in2_full;
  /* verilator lint_on UNUSEDSIGNAL */

  // salidas DUT
  logic                  out_rd_en;
  /* verilator lint_off UNUSEDSIGNAL */
  logic                  out_empty, out_full;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [3*COMPONENT_WIDTH-1:0] out_data_out;

  // opcode
  logic [OPC_WIDTH-1:0] op_code;

  // flags de verificación
  logic passed2, passed3, passed4, passed5;

  // ---------------------------------------------------------------------------
  // Instanciación del DUT
  // ---------------------------------------------------------------------------
  hsi_vector_core #(
    .COMPONENT_WIDTH(COMPONENT_WIDTH),
    .FIFO_DEPTH     (8),
    .OPC_WIDTH      (OPC_WIDTH)
  ) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .in1_wr_en     (in1_wr_en),
    .in1_data_in   (in1_data_in),
    .in1_full      (in1_full),
    .in2_wr_en     (in2_wr_en),
    .in2_data_in   (in2_data_in),
    .in2_full      (in2_full),
    .out_rd_en     (out_rd_en),
    .out_empty     (out_empty),
    .out_data_out  (out_data_out),
    .out_full      (out_full),
    .op_code       (op_code)
  );

  `ifndef VERILATOR
    /* verilator lint_off DECLFILENAME */
    /* verilator lint_off COVERIGN */
    covergroup cg_vector @(posedge clk);
      // componentes de in1
      coverpoint in1_data_in[3*COMPONENT_WIDTH-1 -: COMPONENT_WIDTH] {
        bins neg   = { -1 };
        bins zero  = { 0 };
        bins pos   = { 1 };
      }
      coverpoint in1_data_in[2*COMPONENT_WIDTH-1 -: COMPONENT_WIDTH] {
        bins neg   = { -1 };
        bins zero  = { 0 };
        bins pos   = { 1 };
      }
      coverpoint in1_data_in[COMPONENT_WIDTH-1 -: COMPONENT_WIDTH] {
        bins neg   = { -1 };
        bins zero  = { 0 };
        bins pos   = { 1 };
      }
      // componentes de in2
      coverpoint in2_data_in[3*COMPONENT_WIDTH-1 -: COMPONENT_WIDTH] {
        bins neg   = { -1 };
        bins zero  = { 0 };
        bins pos   = { 1 };
      }
      coverpoint in2_data_in[2*COMPONENT_WIDTH-1 -: COMPONENT_WIDTH] {
        bins neg   = { -1 };
        bins zero  = { 0 };
        bins pos   = { 1 };
      }
      coverpoint in2_data_in[COMPONENT_WIDTH-1 -: COMPONENT_WIDTH] {
        bins neg   = { -1 };
        bins zero  = { 0 };
        bins pos   = { 1 };
      }
      // opcode
      coverpoint op_code {
        bins cross = { OP_CROSS };
      }
      // salida
      coverpoint rx;
      coverpoint ry;
      coverpoint rz;
      // cruce de interés
      cross in1_data_in, in2_data_in, rz;
    endgroup

    fifo_cvg cg = new();
    /* verilator lint_on COVERIGN */
  `endif

  // ---------------------------------------------------------------------------
  // Generación de reloj
  // ---------------------------------------------------------------------------
  always #5 clk = ~clk;

  // ---------------------------------------------------------------------------
  // Muestreo de cobertura al leer salida
  // ---------------------------------------------------------------------------
  `ifndef VERILATOR
  always @(posedge clk) begin
    if (out_rd_en)
      cg.sample();
  end
  `endif
  function automatic signed [COMPONENT_WIDTH-1:0] get_comp(
    input logic [3*COMPONENT_WIDTH-1:0] vec,
    input int idx
  );
    get_comp = vec[3*COMPONENT_WIDTH-1 - idx*COMPONENT_WIDTH -: COMPONENT_WIDTH];
  endfunction

  task push_vectors(
    input signed [COMPONENT_WIDTH-1:0] a1, b1, c1,
    input signed [COMPONENT_WIDTH-1:0] a2, b2, c2
  );
    logic [3*COMPONENT_WIDTH-1:0] v1, v2;
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

  initial begin
    // inicializar señales
    in1_wr_en = 0; in2_wr_en = 0; out_rd_en = 0;
    op_code   = OP_CROSS;
    passed2 = 0; passed3 = 0; passed4 = 0; passed5 = 0;

    // reset
    rst_n = 0;
    #20;
    rst_n = 1;
    @(posedge clk);

    // --- Test R1.2: (1,0,0)x(0,1,0) -> (0,0,1) ---
    push_vectors(1,0,0, 0,1,0);
    wait (!out_empty);
    @(posedge clk) out_rd_en = 1;
    @(posedge clk) out_rd_en = 0;
    begin
      logic signed [COMPONENT_WIDTH-1:0] rx = get_comp(out_data_out,0);
      logic signed [COMPONENT_WIDTH-1:0] ry = get_comp(out_data_out,1);
      logic signed [COMPONENT_WIDTH-1:0] rz = get_comp(out_data_out,2);
      if (rx==0 && ry==0 && rz==1) begin
        passed2 = 1;
        $display("R1.2 PASSED: (%0d,%0d,%0d)", rx, ry, rz);
      end else $error("R1.2 FAILED: got (%0d,%0d,%0d)", rx, ry, rz);
    end

    // --- Test R1.3: (0,0,1)x(1,0,0) -> (0,1,0) ---
    push_vectors(0,0,1, 1,0,0);
    wait (!out_empty);
    @(posedge clk) out_rd_en = 1;
    @(posedge clk) out_rd_en = 0;
    begin
      logic signed [COMPONENT_WIDTH-1:0] rx = get_comp(out_data_out,0);
      logic signed [COMPONENT_WIDTH-1:0] ry = get_comp(out_data_out,1);
      logic signed [COMPONENT_WIDTH-1:0] rz = get_comp(out_data_out,2);
      if (rx==0 && ry==1 && rz==0) begin
        passed3 = 1;
        $display("R1.3 PASSED: (%0d,%0d,%0d)", rx, ry, rz);
      end else $error("R1.3 FAILED: got (%0d,%0d,%0d)", rx, ry, rz);
    end

    // --- Test R1.4: (1,2,3)x(4,5,6) -> (-3,6,-3) ---
    push_vectors(1,2,3, 4,5,6);
    wait (!out_empty);
    @(posedge clk) out_rd_en = 1;
    @(posedge clk) out_rd_en = 0;
    begin
      logic signed [COMPONENT_WIDTH-1:0] rx = get_comp(out_data_out,0);
      logic signed [COMPONENT_WIDTH-1:0] ry = get_comp(out_data_out,1);
      logic signed [COMPONENT_WIDTH-1:0] rz = get_comp(out_data_out,2);
      if (rx==-3 && ry==6 && rz==-3) begin
        passed4 = 1;
        $display("R1.4 PASSED: (%0d,%0d,%0d)", rx, ry, rz);
      end else $error("R1.4 FAILED: got (%0d,%0d,%0d)", rx, ry, rz);
    end

    // --- Test R1.5: (-1,0,0)x(0,1,0) -> (0,0,-1) ---
    push_vectors(-1,0,0, 0,1,0);
    wait (!out_empty);
    @(posedge clk) out_rd_en = 1;
    @(posedge clk) out_rd_en = 0;
    begin
      logic signed [COMPONENT_WIDTH-1:0] rx = get_comp(out_data_out,0);
      logic signed [COMPONENT_WIDTH-1:0] ry = get_comp(out_data_out,1);
      logic signed [COMPONENT_WIDTH-1:0] rz = get_comp(out_data_out,2);
      if (rx==0 && ry==0 && rz==-1) begin
        passed5 = 1;
        $display("R1.5 PASSED: (%0d,%0d,%0d)", rx, ry, rz);
      end else $error("R1.5 FAILED: got (%0d,%0d,%0d)", rx, ry, rz);
    end

    // --- Verificación final R1 ---
    if (passed2 && passed3 && passed4 && passed5) begin
      $display("R1 PASSED: Todas las pruebas de producto vectorial fueron correctas.");
    end else begin
      $error("R1 FAILED: Alguna prueba de cross product falló.");
    end

    $finish;
  end

endmodule
