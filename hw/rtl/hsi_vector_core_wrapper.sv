/**
 * @file hsi_vector_core_wrapper.sv
 * @brief Módulo wrapper con interfaz OBI para control del núcleo hsi_vector_core.
 *
 * @details
 * Este módulo actúa como envoltorio del núcleo de cálculo vectorial `hsi_vector_core`,
 * proporcionando una interfaz estilo OBI para configurar, lanzar operaciones y leer
 * los resultados. Implementa una pequeña lógica de decodificación de direcciones para
 * lectura y escritura de registros de control, tamaño de píxel, estado y resultado.
 * La señal `start` se genera como un pulso de un ciclo para cada escritura en el registro CTRL.
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
 * @class hsi_vector_core_wrapper
 * @brief Módulo Wrapper con interfaz OBI para el núcleo de cálculo vectorial HSI.
 *
 * @details
 * Este módulo actúa como interfaz de control entre un sistema de procesamiento y el núcleo `hsi_vector_core`,
 * proporcionando una capa de abstracción mediante una interfaz OBI-like. Permite configurar parámetros del cálculo,
 * iniciar operaciones y consultar el estado o el resultado del procesado. La escritura y lectura se realiza mediante
 * acceso a registros mapeados por dirección. Internamente gestiona los registros `start`, `op_code` y `pixel_size`,
 * generando las señales necesarias para activar el núcleo vectorial.
 *
 * @section registers Mapa de registros
 * | Dirección | Nombre           | Acceso | Descripción                                      |
 * |-----------|------------------|--------|--------------------------------------------------|
 * | 0x00      | CTRL             | W      | Bit 0: start, Bits 2:1: op_code                  |
 * | 0x04      | PIXEL_SIZE       | W      | Tamaño del vector en píxeles                    |
 * | 0x08      | STATUS           | R      | 0: IDLE, 1: BUSY, 2: DONE                       |
 * | 0x0C      | RESULT           | R      | Resultado de la operación (16 bits)            |
 * | 0x10      | PIXEL_DONE       | R      | Bit 0 indica si el pixel ha sido procesado     |
 *
 * @section signals Descripción de señales de entrada y salida
 * | Señal         | Dirección | Descripción                                                             |
 * |---------------|-----------|-------------------------------------------------------------------------|
 * | clk_i         | input     | Reloj del sistema.                                                      |
 * | rst_ni        | input     | Reset asíncrono activo en bajo.                                        |
 * | req_i         | input     | Señal de solicitud desde el maestro OBI.                               |
 * | addr_i        | input     | Dirección del registro al que se accede.                               |
 * | we_i          | input     | Señal de escritura (1) o lectura (0).                                  |
 * | wdata_i       | input     | Datos de entrada para escritura.                                       |
 * | rdata_o       | output    | Datos de salida durante lectura.                                       |
 * | rvalid_o      | output    | Señal que indica que `rdata_o` es válido (1 ciclo).                    |
 * | start_o       | output    | Pulso de inicio hacia el núcleo `hsi_vector_core`.                     |
 * | op_code_o     | output    | Código de operación: 00 = dot-product, 01 = cross-product.             |
 * | pixel_size_o  | output    | Tamaño de los vectores de entrada.                                     |
 * | result_i      | input     | Resultado de la operación desde el núcleo.                             |
 * | valid_result_i| input     | Indica si el resultado es válido.                                      |
 * | pixel_done_i  | input     | Señal que indica finalización del procesamiento de un píxel.           |
 * | busy_i        | input     | Indica que el núcleo está ocupado procesando.                          |
 *
 * @section usage Ejemplo de instanciación
 *
 * @code{.sv}
 * hsi_vector_core_wrapper hsi_wrapper_inst (
 *     .clk_i(clk),
 *     .rst_ni(rst_n),
 *     .req_i(req),
 *     .addr_i(addr),
 *     .we_i(we),
 *     .wdata_i(wdata),
 *     .rdata_o(rdata),
 *     .rvalid_o(rvalid),
 *     .start_o(start),
 *     .op_code_o(op_code),
 *     .pixel_size_o(pixel_size),
 *     .result_i(result),
 *     .valid_result_i(valid_result),
 *     .pixel_done_i(pixel_done),
 *     .busy_i(busy)
 * );
 * @endcode
 */

module hsi_vector_core_wrapper (
  /**
   * @var clk_i, rst_ni
   * @brief Señales de reloj y reset
   */
  input  logic        clk_i,       ///< Reloj del sistema
  input  logic        rst_ni,      ///< Reset asíncrono activo en bajo

  /**
   * @section obi Interfaz OBI-like
   * @var req_i, addr_i, we_i, wdata_i, rdata_o, rvalid_o
   * @brief Señales de control de bus para configuración y lectura
   */
  input  logic        req_i,       ///< Petición de acceso al wrapper
  input  logic [7:0]  addr_i,      ///< Dirección de registro
  input  logic        we_i,        ///< Indica operación de escritura
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [31:0] wdata_i,     ///< Datos de entrada para escritura
  /* verilator lint_on UNUSEDSIGNAL */
  output logic [31:0] rdata_o,     ///< Datos de salida tras lectura
  output logic        rvalid_o,    ///< Lectura válida (1 ciclo)

  /**
   * @section core Señales al núcleo hsi_vector_core
   * @var start_o, op_code_o, pixel_size_o, result_i, valid_result_i, pixel_done_i, busy_i
   * @brief Señales para lanzar operaciones y capturar resultados
   */
  output logic        start_o,        ///< Pulso de inicio de operación
  output logic [1:0]  op_code_o,      ///< Código de operación (00 dot, 01 cross)
  output logic [15:0] pixel_size_o,   ///< Tamaño de los vectores de entrada
  input  logic [15:0] result_i,       ///< Resultado del cálculo
  input  logic        valid_result_i, ///< Resultado disponible
  input  logic        pixel_done_i,   ///< Finalización de operación
  input  logic        busy_i          ///< Núcleo ocupado
);

  /**
   * @section addrs Direcciones internas de registros
   */
  localparam CTRL_ADDR        = 8'h0;   ///< Dirección para control y op_code
  localparam PIXEL_SIZE_ADDR  = 8'h4;   ///< Dirección para tamaño de píxel
  localparam STATUS_ADDR      = 8'h8;   ///< Dirección para estado del core
  localparam RESULT_ADDR      = 8'hC;   ///< Dirección para resultado del cálculo
  localparam PIXEL_DONE_ADDR  = 8'h10;  ///< Dirección para estado de pixel_done

  /**
   * @section regs Registros internos del wrapper
   */
  logic        start_reg;        ///< Registro temporal de start (pulso)
  logic [1:0]  op_code_reg;      ///< Código de operación
  logic [15:0] pixel_size_reg;   ///< Tamaño del vector/píxel
  logic        rvalid_d;         ///< Retardo de validación de lectura

  /**
   * @section write Escritura de registros mediante interfaz OBI
   */
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      start_reg      <= 1'b0;
      op_code_reg    <= 2'b00;
      pixel_size_reg <= 16'd0;
    end else if (req_i && we_i) begin
      case (addr_i)
        CTRL_ADDR: begin
          start_reg   <= wdata_i[0];
          op_code_reg <= wdata_i[2:1];
        end
        PIXEL_SIZE_ADDR: begin
          pixel_size_reg <= wdata_i[15:0];
        end
        default: begin
          // Escritura ignorada para direcciones no válidas
        end
      endcase
    end else begin
      start_reg <= 1'b0; // Pulso de un ciclo
    end
  end

  /**
   * @section read Lógica combinacional de lectura
   * Devuelve datos del estado o resultado del núcleo según la dirección
   */
  always_comb begin
    rdata_o = 32'd0;
    case (addr_i)
      STATUS_ADDR:
        rdata_o = valid_result_i ? 32'd2 : (busy_i ? 32'd1 : 32'd0);
      RESULT_ADDR:
        rdata_o = {16'd0, result_i};
      PIXEL_DONE_ADDR:
        rdata_o = {31'd0, pixel_done_i};
      default:
        rdata_o = 32'd0;
    endcase
  end

  /**
   * @section rvalid Pulso de validación de lectura (1 ciclo)
   */
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      rvalid_d <= 1'b0;
    else
      rvalid_d <= req_i && !we_i;
  end

  assign rvalid_o      = rvalid_d;
  assign start_o       = start_reg;
  assign op_code_o     = op_code_reg;
  assign pixel_size_o  = pixel_size_reg;

endmodule
