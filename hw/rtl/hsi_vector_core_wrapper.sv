/**
 * @file hsi_vector_core_wrapper.sv
 * @brief Wrapper OBI para el núcleo vectorial HSI.
 *
 * @details
 * Este módulo implementa una interfaz de bus OBI de 32 bits para el núcleo vectorial HSI.
 * Proporciona registros mapeados en memoria para señales de control (op_code, num_bands, start)
 * y señales de estado (pixel_done, error_code). No maneja los datos de las FIFOs de entrada/salida,
 * solo proporciona una interfaz de configuración.
 *
 * @author Alejandro Fernández Rodríguez, UCLM
 * @version 1.0
 * @date 2025
 * @copyright Copyright (c) 2025 Alejandro Fernández Rodríguez
 * @license Licencia MIT
 */

/**
 * @brief Wrapper OBI para el núcleo vectorial HSI.
 *
 * @details
 * Implementa una interfaz de bus OBI (Open Bus Interface) para controlar el núcleo vectorial HSI.
 * El wrapper expone registros para configurar la operación del núcleo y leer su estado.
 * 
 * Mapa de memoria (direcciones de palabra):
 *    - 0x00: Registro OP_CODE    [RW] - Código de operación (ancho OP_CODE_WIDTH)
 *    - 0x04: Registro NUM_BANDS  [RW] - Número de bandas espectrales (ancho NUM_BANDS_WIDTH)
 *    - 0x08: Registro START      [WO] - Escribir 1 para iniciar procesamiento (auto-limpia)
 *    - 0x0C: Registro STATUS     [RO] - Bit 0: flag pixel_done, Bits [8:1]: error_code
 *
 * La interfaz OBI sigue el protocolo estándar con señales req_i, we_i, be_i, addr_i, wdata_i,
 * gnt_o, rvalid_o, rdata_o y err_o.
 *
 * @section signals Descripción de señales de entrada y salida
 * | Señal          | Dirección | Descripción                                                                |
 * |----------------|-----------|----------------------------------------------------------------------------|
 * | clk_i          | input     | Reloj principal del sistema.                                               |
 * | rst_ni         | input     | Reset asíncrono activo en bajo.                                            |
 * | req_i          | input     | Solicitud de transferencia del bus OBI.                                    |
 * | we_i           | input     | Habilitación de escritura (1=escritura, 0=lectura).                        |
 * | be_i           | input     | Habilitación de byte (no utilizado en esta implementación).                |
 * | addr_i         | input     | Dirección de acceso del bus.                                               |
 * | wdata_i        | input     | Datos de escritura del bus.                                                |
 * | gnt_o          | output    | Concesión de transferencia.                                                |
 * | rvalid_o       | output    | Indicador de respuesta válida.                                             |
 * | rdata_o        | output    | Datos de lectura del bus.                                                  |
 * | err_o          | output    | Indicador de error en la transacción.                                      |
 * | op_code_o      | output    | Código de operación hacia el núcleo (producto vectorial o escalar).        |
 * | num_bands_o    | output    | Número de bandas espectrales hacia el núcleo.                              |
 * | start_o        | output    | Pulso de inicio de operación hacia el núcleo.                              |
 * | pixel_done_i   | input     | Señal que indica que el núcleo completó un cálculo.                        |
 * | error_code_i   | input     | Código de error proveniente del núcleo.                                    |
 */
 
module hsi_vector_core_wrapper #(
    parameter int OP_CODE_WIDTH   = 8,   ///< Ancho del código de operación
    parameter int NUM_BANDS_WIDTH = 8,   ///< Ancho del número de bandas
    parameter int ERR_WIDTH       = 8    ///< Ancho del código de error
) (
    input  logic             clk_i,      ///< Reloj del sistema
    input  logic             rst_ni,     ///< Reset asíncrono (activo bajo)

    // Interfaz OBI (esclavo)
    input  logic             req_i,      ///< Solicitud de transferencia
    input  logic             we_i,       ///< Habilitación de escritura (1=escritura, 0=lectura)
    input  logic [3:0]       be_i,       ///< Habilitación de byte (no usado)
    input  logic [31:0]      addr_i,     ///< Dirección de acceso
    input  logic [31:0]      wdata_i,    ///< Datos de escritura
    output logic             gnt_o,      ///< Señal de concesión
    output logic             rvalid_o,   ///< Respuesta válida
    output logic [31:0]      rdata_o,    ///< Datos de lectura
    output logic             err_o,      ///< Indicador de error

    // Señales de control al núcleo
    output logic [OP_CODE_WIDTH-1:0]    op_code_o,    ///< Código de operación
    output logic [NUM_BANDS_WIDTH-1:0]  num_bands_o,  ///< Número de bandas
    output logic                       start_o,      ///< Pulso de inicio (1 ciclo)

    // Señales de estado del núcleo
    input  logic                       pixel_done_i,  ///< Indicador de procesamiento completado
    input  logic [ERR_WIDTH-1:0]       error_code_i   ///< Código de error
);

    // Registros internos
    logic [OP_CODE_WIDTH-1:0]    op_code_reg;        ///< Registro para código de operación
    logic [NUM_BANDS_WIDTH-1:0]  num_bands_reg;      ///< Registro para número de bandas
    logic                        start_pulse_reg;     ///< Registro para pulso de inicio
    
    // Registros de estado
    logic                       done_flag_reg;       ///< Flag de procesamiento completado
    logic [ERR_WIDTH-1:0]       error_code_reg;     ///< Registro de código de error

/**
 * @class wrapper_state_t
 * @brief Estados de la máquina de estados finita (FSM) del wrapper OBI
 * 
 * @details
 * Esta enumeración define los estados de la FSM que controla las transacciones OBI:
 * - IDLE: Estado inicial. Espera solicitudes del bus.
 * - RESP_WAIT: Estado de espera para generar respuesta a la transacción.
 * 
 * \dot
 * digraph FSM {
 *   rankdir=LR;
 *   node [shape=ellipse, style=filled, fillcolor=lightgray];
 * 
 *   IDLE -> RESP_WAIT [label="req_i"];
 *   RESP_WAIT -> IDLE [label="1 ciclo"];
 * 
 *   // Transiciones implícitas
 *   IDLE -> IDLE [label="!req_i"];
 *   RESP_WAIT -> RESP_WAIT [style=invis];
 * 
 *   // Comportamiento especial
 *   IDLE -> IDLE [label="req_i && we_i && addr_i==0x08 && wdata_i[0]", 
 *                style=dashed, color=blue];
 *   RESP_WAIT -> IDLE [label="start_pulse_reg", style=dashed, color=blue];
 * 
 *   // Leyenda
 *   subgraph cluster_legend {
 *     label = "Leyenda";
 *     node [shape=plaintext];
 *     a [label="Transición normal"];
 *     b [label="Pulso de start", color=blue, fontcolor=blue];
 *   }
 * }
 * \enddot
 */
    typedef enum logic [1:0] {IDLE, RESP_WAIT} wrapper_state_t;
    wrapper_state_t state_reg, state_next;                 ///< Registros de estado actual y siguiente
    logic [31:0] addr_lat;                         ///< Dirección latenciada
    logic        we_lat;                           ///< Tipo de transacción latenciada
    logic        bus_err_flag;                     ///< Flag de error de dirección

    // Asignación de salidas de control
    assign op_code_o   = op_code_reg;
    assign num_bands_o = num_bands_reg;
    assign start_o     = start_pulse_reg;

    /**
     * @brief Lógica secuencial principal
     *
     * @details
     * Implementa la máquina de estados que maneja las transacciones OBI y actualiza
     * los registros de control y estado. Maneja reset asíncrono y genera las señales
     * de respuesta del bus.
     */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            // Reset asíncrono
            state_reg       <= IDLE;
            op_code_reg     <= '0;
            num_bands_reg   <= '0;
            start_pulse_reg <= 1'b0;
            done_flag_reg   <= 1'b0;
            error_code_reg  <= '0;
            gnt_o           <= 1'b0;
            rvalid_o        <= 1'b0;
            rdata_o         <= 32'b0;
            err_o           <= 1'b0;
            addr_lat        <= 32'b0;
            we_lat          <= 1'b0;
            bus_err_flag    <= 1'b0;
        end else begin
            // Valores por defecto
            gnt_o    <= 1'b0;
            rvalid_o <= 1'b0;
            err_o    <= 1'b0;

            case (state_reg)
                IDLE: begin
                    if (req_i) begin
                        // Latch de información de la transacción
                        addr_lat   <= addr_i;
                        we_lat     <= we_i;
                        
                        // Decodificación de dirección
                        unique case (addr_i[5:0]) 
                            6'h00: bus_err_flag <= 1'b0;  // 0x00 (op_code)
                            6'h04: bus_err_flag <= 1'b0;  // 0x04 (num_bands)
                            6'h08: bus_err_flag <= 1'b0;  // 0x08 (start)
                            6'h0C: bus_err_flag <= 1'b0;  // 0x0C (status)
                            default: bus_err_flag <= 1'b1; // dirección inválida
                        endcase

                        // Escritura de registros
                        if (we_i && !bus_err_flag) begin
                            case (addr_i[5:0])
                                6'h00: op_code_reg <= wdata_i[OP_CODE_WIDTH-1:0]; 
                                6'h04: num_bands_reg <= wdata_i[NUM_BANDS_WIDTH-1:0]; 
                                6'h08: if (wdata_i[0] == 1'b1) begin
                                    start_pulse_reg <= 1'b1;
                                    done_flag_reg   <= 1'b0;
                                    error_code_reg  <= '0;
                                end
                                6'h0C: ; // Escritura ignorada
                                default: ;
                            endcase
                        end

                        gnt_o    <= 1'b1;
                        state_reg <= RESP_WAIT;
                    end
                end

                RESP_WAIT: begin
                    // Generación de respuesta
                    rvalid_o <= 1'b1;
                    err_o    <= bus_err_flag;
                    
                    if (!we_lat) begin
                        // Lectura de registros
                        unique case (addr_lat[5:0])
                            6'h00: rdata_o <= {{(32-OP_CODE_WIDTH){1'b0}}, op_code_reg};
                            6'h04: rdata_o <= {{(32-NUM_BANDS_WIDTH){1'b0}}, num_bands_reg};
                            6'h08: rdata_o <= 32'b0;
                            6'h0C: begin 
                                logic [31:0] status_data;
                                status_data            = 32'b0;
                                status_data[0]         = done_flag_reg;
                                status_data[8:1]       = error_code_reg; 
                                rdata_o <= status_data;
                            end
                            default: rdata_o <= 32'b0;
                        endcase
                    end else begin
                        rdata_o <= 32'b0;
                    end
                    
                    state_reg <= IDLE;
                    if (start_pulse_reg) begin
                        start_pulse_reg <= 1'b0;
                    end
                end
            endcase

            // Captura de señales de estado del núcleo
            if (pixel_done_i) begin
                done_flag_reg  <= 1'b1;
                error_code_reg <= error_code_i;
            end
        end
    end

endmodule
