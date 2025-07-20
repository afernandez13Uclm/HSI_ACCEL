`timescale 1ns/1ps
/**
 * ------------------------------------------------------------------
 * Testbench: hsi_vector_core_wrapper_tb.sv
 * Project    : Aceleración de procesamiento de datos HSI en X-Heep
 * Author     : Alejandro Fernández Rodríguez, UCLM
 * Version    : 1.0
 * Date       : 2025
 * License    : MIT
 * Copyright (c) 2025 Alejandro Fernández Rodríguez
 * ------------------------------------------------------------------
 * @file hsi_vector_core_wrapper_tb.sv
 * @brief Testbench para verificar el módulo hsi_vector_core_wrapper.
 *
 * @details
 * Este testbench simula el comportamiento del wrapper del núcleo HSI vectorial,
 * validando la correcta operación del protocolo OBI, el control de señales hacia el núcleo
 * y la gestión del estado interno. Utiliza tareas reutilizables `obi_write` y `obi_read`,
 * y comprueba condiciones específicas para asegurar la conformidad con los requisitos funcionales.
 *
 * @test
 * Lista de requisitos verificados:
 * | Requisito | Descripción                                                                 |
 * |-----------|-----------------------------------------------------------------------------|
 * | R1        | Estado tras reset: OP_CODE = 0, NUM_BANDS = 0, STATUS = 0                  |
 * | R2        | Escritura y lectura correcta de OP_CODE                                    |
 * | R3        | Escritura con byte enable sobre NUM_BANDS                                  |
 * | R4        | Activación correcta de start_o y estado BUSY al emitir comando START       |
 * | R5        | Señal start_o no se mantiene más de un ciclo y no se reactiva en BUSY      |
 * | R6        | Señales DONE y BUSY actualizadas al finalizar la operación                 |
 * | R7        | Comando CLEAR_DONE limpia la bandera DONE                                  |
 * | R8        | Captura de ERROR_CODE al producirse un error y liberación de BUSY          |
 * | R9        | Comando CLEAR_ERROR limpia el campo ERROR_CODE                             |
 * | R10       | Señal err_o se activa ante acceso a dirección inválida y no altera estado  |
 * | R11       | Puede reiniciarse una operación una vez limpiado DONE                      |
 * | R12       | start_o no se activa de nuevo indebidamente en estado ocupado              *
 *
 * @note Las pruebas usan tareas automatizadas para simular accesos OBI y monitorizan
 * cambios en señales clave como `start_o`, `op_code_o`, `gnt_o`, `rvalid_o`.
 *
 */

module hsi_vector_core_wrapper_tb;

    // ---------------------- Macros ----------------------
    `define INC_ERR(MSG) begin $error(MSG); error_count = error_count + 1; end

    // ---------------------- Señales DUT ----------------------
    logic clk;
    logic rst_ni;
    logic req_i;
    logic we_i;
    logic [3:0]  be_i;
    logic [31:0] addr_i;
    logic [31:0] wdata_i;
    logic        gnt_o;
    logic        rvalid_o;
    logic [31:0] rdata_o;
    logic        err_o;

    // Hacia core (salidas del wrapper)
    logic [3:0]  op_code_o;
    logic [31:0] num_bands_o;
    logic        start_o;

    // Desde core (entradas al wrapper - simuladas aquí)
    logic        pixel_done_i;
    logic [3:0]  error_code_i;

    // Variables auxiliares globales
    integer error_count = 0;
    logic [31:0] data_rd;
    logic [31:0] prev_opcode;

    // Para monitorizar cambios y evitar UNUSED
    logic [3:0]  op_code_o_d;
    logic [31:0] num_bands_o_d;
    logic gnt_o_d, rvalid_o_d;

    // Instancia del wrapper
    hsi_vector_core_wrapper #(
        .OP_CODE_WIDTH(4),
        .NUM_BANDS_WIDTH(32),
        .ERR_WIDTH(4),
        .READ_CLEAR_DONE(0),
        .EXPOSE_FIFO_STATUS(0)
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
        .op_code_o(op_code_o),
        .num_bands_o(num_bands_o),
        .start_o(start_o),
        .pixel_done_i(pixel_done_i),
        .error_code_i(error_code_i),
        .in1_full_i(1'b0),
        .in2_full_i(1'b0),
        .out_full_i(1'b0),
        .out_empty_i(1'b0),
        .in1_empty_i(1'b0),
        .in2_empty_i(1'b0)
    );

    // ---------------------- Clock & Reset ----------------------
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    initial begin
        rst_ni = 0;
        req_i = 0; we_i = 0; be_i = 4'h0; addr_i = '0; wdata_i = '0;
        pixel_done_i = 0; error_code_i = 0;
        repeat (5) @(posedge clk);
        rst_ni = 1;
    end

    // ---------------------- Utilidades ----------------------
    task automatic obi_write(input [31:0] addr, input [31:0] data, input [3:0] be, input [0:0] checkStart, input [0:0] checkErr);
        begin
            @(posedge clk);
            addr_i = addr; wdata_i = data; be_i = be; we_i = 1'b1; req_i = 1'b1;
            @(posedge clk); // aceptación
            if(checkStart == 1'b1) begin
              if(!start_o) `INC_ERR("[ERROR] start_o no se activo")
            end
            if(checkErr == 1'b1) begin
              if(!err_o) `INC_ERR("[ERROR] err_o no se activo")
            end
            req_i = 0; we_i = 0; be_i = 4'h0; addr_i = 32'h0; wdata_i = 32'h0;
            @(posedge clk); // respuesta
        end
    endtask

    task automatic obi_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            addr_i = addr; we_i = 1'b0; req_i = 1'b1; be_i = 4'hF; wdata_i = 32'h0;
            @(posedge clk);
            req_i = 0; addr_i = 32'h0; be_i = 4'h0;

            // Esperar a rvalid_o == 1
            wait (rvalid_o === 1);
            data = rdata_o;
        end
  endtask
  


    function automatic [31:0] rd_status();
        reg [31:0] tmp; begin obi_read(32'h0C, tmp); rd_status = tmp; end
    endfunction

  // ---------------------- Monitor pulso start ----------------------
  reg start_o_d;
  always @(posedge clk) begin
      start_o_d <= start_o;
      if (start_o && start_o_d) begin
          $error("[R4/R5/R12] start_o ancho >1 ciclo");
          error_count <= error_count + 1;
      end
  end


    // Monitor de salidas para evitar UNUSED y posible debug
    always @(posedge clk) begin
        op_code_o_d   <= op_code_o;
        num_bands_o_d <= num_bands_o;
        gnt_o_d       <= gnt_o;
        rvalid_o_d    <= rvalid_o;
        if (op_code_o_d != op_code_o)     $display("[MON] OP_CODE -> %0d (t=%0t)", op_code_o, $time);
        if (num_bands_o_d != num_bands_o) $display("[MON] NUM_BANDS -> 0x%08h (t=%0t)", num_bands_o, $time);
        if (gnt_o && !gnt_o_d)            $display("[MON] gnt_o high (t=%0t)", $time);
        if (rvalid_o && !rvalid_o_d)      $display("[MON] rvalid_o high (t=%0t)", $time);
    end

    // ---------------------- Secuencia Principal ----------------------
    initial begin : main_sequence
        wait(rst_ni==1);
        @(posedge clk);

        obi_read(32'h00, data_rd); if (data_rd[3:0] !== 4'h0)      `INC_ERR("[R1] OP_CODE tras reset !=0")
        obi_read(32'h04, data_rd); if (data_rd       !== 32'h0)    `INC_ERR("[R1] NUM_BANDS tras reset !=0")
        data_rd = rd_status();
        if (data_rd[0]   !== 1'b0) `INC_ERR("[R1] DONE tras reset !=0")
        if (data_rd[4:1] !== 4'h0) `INC_ERR("[R1] ERROR_CODE tras reset !=0")
        if (data_rd[8]   !== 1'b0) `INC_ERR("[R1] BUSY tras reset !=0")

        obi_write(32'h00, 32'h0000_0002, 4'h1, 1'b0, 1'b0);
        obi_read(32'h00, data_rd); if (data_rd[3:0] !== 4'd2)      `INC_ERR("[R2] OP_CODE readback incorrecto")

        obi_write(32'h04, 32'hA5A5_5A5A, 4'hF, 1'b0, 1'b0);
        obi_read(32'h04, data_rd); if (data_rd !== 32'hA5A55A5A)   `INC_ERR("[R3] NUM_BANDS full write mismatch")
        obi_write(32'h04, 32'h0000_00FF, 4'h1, 1'b0, 1'b0);
        obi_read(32'h04, data_rd); if (data_rd !== 32'hA5A55AFF)   `INC_ERR("[R3] NUM_BANDS BE lower byte fail")
        obi_write(32'h04, 32'h0000_5600, 4'h2, 1'b0, 1'b0);
        obi_read(32'h04, data_rd); if (data_rd !== 32'hA5A556FF)   `INC_ERR("[R3] NUM_BANDS BE second byte fail")

        $display("Escritura con comprobacion de start en [R4]");
        obi_write(32'h08, 32'h0000_0001, 4'h1, 1'b1, 1'b0);
        data_rd = rd_status();
        if (data_rd[8] !== 1'b1)          `INC_ERR("[R4] BUSY no activo tras START")
        if (data_rd[0] !== 1'b0)          `INC_ERR("[R4] DONE inesperado tras START")


        obi_write(32'h08, 32'h0000_0001, 4'h1, 1'b0, 1'b0);
        @(posedge clk);
        if (start_o)                      `INC_ERR("[R5] start_o reactivado mientras BUSY")

        pixel_done_i = 1'b1; @(posedge clk); pixel_done_i = 1'b0;
        data_rd = rd_status();
        if (data_rd[0] !== 1'b1)          `INC_ERR("[R6] DONE no se puso a 1")
        if (data_rd[8] !== 1'b0)          `INC_ERR("[R6] BUSY no se liberó")

        obi_write(32'h08, 32'h0000_0002, 4'h1, 1'b0, 1'b0);
        data_rd = rd_status(); if (data_rd[0] !== 1'b0) `INC_ERR("[R7] DONE no se limpió")

        obi_write(32'h08, 32'h0000_0001, 4'h1, 1'b0, 1'b0); 
        @(posedge clk);
        error_code_i = 4'h5; @(posedge clk);
        data_rd = rd_status();
        if (data_rd[4:1] !== 4'h5)        `INC_ERR("[R8] ERROR_CODE no capturado")
        if (data_rd[8]   !== 1'b0)        `INC_ERR("[R8] BUSY no se liberó tras error")
        @(posedge clk); error_code_i = 4'h0;

        obi_write(32'h08, 32'h0000_0004, 4'h1, 1'b0, 1'b0);
        data_rd = rd_status(); if (data_rd[4:1] !== 4'h0) `INC_ERR("[R9] ERROR_CODE no se limpió")

        obi_read(32'h00, prev_opcode);
        $display("Escritura con comprobacion de señal err_o para [R10]");
        obi_write(32'h20, 32'hDEAD_BEEF, 4'hF, 1'b0, 1'b1);
        obi_read(32'h00, data_rd); if (data_rd !== prev_opcode) `INC_ERR("[R10] OP_CODE cambió tras acceso inválido")

        obi_write(32'h08, 32'h0000_0002, 4'h1, 1'b0, 1'b0);
        $display("Escritura con comprobacion de start en [R11]");
        obi_write(32'h08, 32'h0000_0001, 4'h1, 1'b1, 1'b0);
        @(posedge clk);
        data_rd = rd_status(); if (data_rd[8] !== 1'b1) `INC_ERR("[R11] BUSY no activo tras restart")

        obi_write(32'h08, 32'h0000_0001, 4'h1, 1'b0, 1'b0);
        @(posedge clk); if (start_o)           `INC_ERR("[R12] start_o reactivado indebidamente")

        pixel_done_i = 1'b1; @(posedge clk); pixel_done_i = 1'b0;

        if (error_count==0) begin
            $display("============================= ALL TESTS PASSED =============================");
        end else begin
            $display("============================= TESTS COMPLETED WITH %0d ERRORS =============================", error_count);
        end
        #50; $finish;
    end

endmodule
