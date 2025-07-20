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
 * @class hsi_vector_core_wrapper
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
    parameter int OP_CODE_WIDTH       = 4,
    parameter int NUM_BANDS_WIDTH     = 32,
    parameter int ERR_WIDTH           = 4,
    parameter bit READ_CLEAR_DONE     = 0,
    parameter bit EXPOSE_FIFO_STATUS  = 0
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,

    // Interfaz OBI
    input  logic                     req_i,
    input  logic                     we_i,
    input  logic [3:0]               be_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0]              addr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [31:0]              wdata_i,
    output logic                     gnt_o,
    output logic                     rvalid_o,
    output logic [31:0]              rdata_o,
    output logic                     err_o,

    // Señales hacia el núcleo
    output logic [OP_CODE_WIDTH-1:0] op_code_o,
    output logic [NUM_BANDS_WIDTH-1:0] num_bands_o,
    output logic                     start_o,

    // Señales desde el núcleo
    input  logic                     pixel_done_i,
    input  logic [ERR_WIDTH-1:0]     error_code_i,

    // FIFO status
    input  logic                     in1_full_i,
    input  logic                     in2_full_i,
    input  logic                     out_full_i,
    input  logic                     out_empty_i,
    input  logic                     in1_empty_i,
    input  logic                     in2_empty_i
);

        // ============================================================================
    /** @name Mapa de direcciones del wrapper
     *  @brief Direcciones en bytes alineadas a palabra de 32 bits.
     *  @{
     */
    localparam logic [5:0] ADDR_OPCODE      = 6'h00;  /**< Dirección del registro OP_CODE (RW). */
    localparam logic [5:0] ADDR_NUM_BANDS   = 6'h04;  /**< Dirección del registro NUM_BANDS (RW). */
    localparam logic [5:0] ADDR_COMMAND     = 6'h08;  /**< Dirección del registro COMMAND (WO): start, clear_done, clear_error. */
    localparam logic [5:0] ADDR_STATUS      = 6'h0C;  /**< Dirección del registro STATUS (RO): done, error, busy. */
    localparam logic [5:0] ADDR_FIFO_STATUS = 6'h10;  /**< Dirección del registro FIFO_STATUS (RO, si EXPOSE_FIFO_STATUS=1). */
    /** @} */

    // ============================================================================
    /** @name Registros internos del wrapper
     *  @brief Almacenan configuración, estado y control hacia el núcleo vectorial.
     *  @{
     */
    logic [OP_CODE_WIDTH-1:0]     op_code_reg;      /**< Registro de código de operación configurado. */
    logic [NUM_BANDS_WIDTH-1:0]   num_bands_reg;    /**< Registro del número de bandas configurado. */
    logic                         start_pulse_reg;  /**< Pulso de inicio de operación hacia el núcleo. */
    logic                         done_flag_reg;    /**< Bandera que indica operación finalizada. */
    logic [ERR_WIDTH-1:0]         error_code_reg;   /**< Último código de error recibido del núcleo. */
    logic                         busy_reg;         /**< Bandera que indica núcleo ocupado. */
    /** @} */

    // ============================================================================
    /** @name Latch de señales de transacción OBI
     *  @brief Retienen información relevante de la transacción durante una respuesta.
     *  @{
     */
    logic [5:0] addr_lat;      /**< Dirección latched de la transacción (6 bits significativos). */
    logic       we_lat;        /**< Bandera latched de escritura (1: write, 0: read). */
    logic       bus_err_lat;   /**< Bandera latched de error detectado durante la transacción. */
    /** @} */

    // ============================================================================
    /**
     * @class state_wrapper_t
     * @brief Máquina de estados finita (FSM) para protocolo de respuesta OBI.
     *
     * @details
     * La FSM controla el protocolo de respuesta del wrapper `hsi_vector_core_wrapper` frente a accesos
     * del maestro OBI. La FSM tiene dos estados y gestiona las señales `gnt_o`, `rvalid_o`, `err_o` y `rdata_o`
     * según la fase de la transacción.
     *
     * @dot
     * digraph FSM {
     *   rankdir=LR;
     *   node [shape=ellipse, style=filled, fillcolor=lightgray];

     *   S_IDLE -> S_RESP [ label="req_i" ];
     *   S_RESP -> S_IDLE [ label="always (respuesta enviada)" ];
     * }
     * @enddot
     *
     * - `S_IDLE`: Estado de espera. Otorga `gnt_o` cuando `req_i` está activo.
     * - `S_RESP`: Estado de respuesta. Produce `rvalid_o`, `err_o`, y `rdata_o` según la dirección latched.
     *
     * La respuesta puede incluir:
     * - Código de operación (`ADDR_OPCODE`)
     * - Número de bandas (`ADDR_NUM_BANDS`)
     * - Estado (`ADDR_STATUS`) con `DONE`, `ERROR_CODE` y `BUSY`
     * - Estado de las FIFOs (`ADDR_FIFO_STATUS`) si está habilitado
     */

    typedef enum logic [0:0] {
        S_IDLE,   /**< Estado inactivo, espera nueva transacción OBI. */
        S_RESP    /**< Estado de respuesta: genera señales rvalid_o / err_o. */
    } state_wrapper_t;

    state_wrapper_t state_q;  /**< Estado actual de la FSM. */
    state_wrapper_t state_d;  /**< Próximo estado de la FSM. */


        /**
     * @brief Aplica el byte enable a una escritura de 32 bits.
     *
     * @details
     * Esta función auxiliar permite actualizar de forma selectiva los bytes individuales de una palabra de 32 bits
     * utilizando una máscara de byte enable (`be`). Si un bit de `be[i]` está activo, el byte correspondiente
     * de `newdata` sobrescribe el de `orig`. Si no está activo, el byte original se conserva.
     *
     * @param orig     Palabra original de 32 bits.
     * @param newdata  Nueva palabra con los datos a escribir.
     * @param be       Byte enable (4 bits): cada bit habilita escritura de un byte (LSB -> MSB).
     * @return Palabra resultante tras aplicar el byte enable.
     */
    function automatic [31:0] apply_be (
        input [31:0] orig,      ///< Palabra original (antes de la escritura).
        input [31:0] newdata,   ///< Datos nuevos a escribir.
        input [3:0]  be         ///< Máscara de byte enable: be[0] aplica a bits [7:0], etc.
    );
        apply_be = orig;
        if (be[0]) apply_be[7:0]    = newdata[7:0];
        if (be[1]) apply_be[15:8]   = newdata[15:8];
        if (be[2]) apply_be[23:16]  = newdata[23:16];
        if (be[3]) apply_be[31:24]  = newdata[31:24];
    endfunction


        /**
     * @brief Decodificación de dirección válida para el wrapper.
     *
     * @details
     * Esta lógica combinacional detecta si la dirección recibida en `addr_i` se corresponde con un
     * registro implementado dentro del wrapper. Si la dirección es válida, `addr_valid_comb` se activa.
     * La dirección ADDR_FIFO_STATUS solo es válida si el parámetro `EXPOSE_FIFO_STATUS` está activado.
     *
     * | Dirección         | Registro        | Condición                   |
     * |-------------------|------------------|------------------------------|
     * | 0x00              | OP_CODE         | Siempre válida               |
     * | 0x04              | NUM_BANDS       | Siempre válida               |
     * | 0x08              | COMMAND         | Siempre válida               |
     * | 0x0C              | STATUS          | Siempre válida               |
     * | 0x10              | FIFO_STATUS     | Válida solo si expuesta      |
     */
    logic addr_valid_comb;

    always_comb begin
        unique case (addr_i[5:0])
            ADDR_OPCODE,
            ADDR_NUM_BANDS,
            ADDR_COMMAND,
            ADDR_STATUS:      addr_valid_comb = 1'b1;
            ADDR_FIFO_STATUS: addr_valid_comb = (EXPOSE_FIFO_STATUS) ? 1'b1 : 1'b0;
            default:          addr_valid_comb = 1'b0;
        endcase
    end


    // Asignaciones a core
    assign op_code_o   = op_code_reg;
    assign num_bands_o = num_bands_reg;
    assign start_o     = start_pulse_reg;

    // FSM combinacional
    always_comb begin
        state_d  = state_q;
        gnt_o    = 1'b0;
        rvalid_o = 1'b0;
        err_o    = 1'b0;
        rdata_o  = 32'h0;
        case (state_q)
            S_IDLE: begin
                if (req_i) begin
                    gnt_o   = 1'b1;
                    state_d = S_RESP;
                end
            end
            S_RESP: begin
                rvalid_o = 1'b1;
                err_o    = bus_err_lat;
                if (!we_lat) begin
                    unique case (addr_lat)
                        ADDR_OPCODE:    rdata_o = {{(32-OP_CODE_WIDTH){1'b0}}, op_code_reg};
                        ADDR_NUM_BANDS: rdata_o = num_bands_reg;
                        ADDR_COMMAND:   rdata_o = 32'h0;
                        ADDR_STATUS: begin
                            logic [31:0] s; s = '0;
                            s[0]   = done_flag_reg;
                            s[4:1] = error_code_reg;
                            s[8]   = busy_reg;
                            rdata_o = s;
                        end
                        ADDR_FIFO_STATUS: if (EXPOSE_FIFO_STATUS) begin
                            logic [31:0] f; f = '0;
                            f[0] = in1_full_i;
                            f[1] = in2_full_i;
                            f[2] = out_full_i;
                            f[3] = out_empty_i;
                            f[4] = in1_empty_i;
                            f[5] = in2_empty_i;
                            rdata_o = f;
                        end
                        default: rdata_o = 32'h0;
                    endcase
                end
                state_d = S_IDLE;
            end
        endcase
    end

    // Secuencial
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q         <= S_IDLE;
            op_code_reg     <= '0;
            num_bands_reg   <= '0;
            start_pulse_reg <= 1'b0;
            done_flag_reg   <= 1'b0;
            error_code_reg  <= '0;
            busy_reg        <= 1'b0;
            addr_lat        <= '0;
            we_lat          <= 1'b0;
            bus_err_lat     <= 1'b0;
        end else begin
            state_q <= state_d;
            if (start_pulse_reg) start_pulse_reg <= 1'b0; // pulso 1 ciclo

            if (state_q == S_IDLE && req_i) begin
                addr_lat    <= addr_i[5:0];
                we_lat      <= we_i;
                bus_err_lat <= ~addr_valid_comb;
                if (we_i && addr_valid_comb) begin
                    unique case (addr_i[5:0])
                        ADDR_OPCODE: begin
                            if (be_i[0]) op_code_reg <= wdata_i[OP_CODE_WIDTH-1:0];
                        end

                        ADDR_NUM_BANDS: begin
                            logic [31:0] new_nb = apply_be(num_bands_reg, wdata_i, be_i);
                            num_bands_reg <= new_nb[NUM_BANDS_WIDTH-1:0];
                        end
                        ADDR_COMMAND: begin
                            logic [2:0] cmd;
                            cmd = apply_be(32'h0, wdata_i, be_i)[2:0];
                            if (cmd[1]) done_flag_reg  <= 1'b0;          // CLEAR_DONE
                            if (cmd[2]) error_code_reg <= '0;            // CLEAR_ERROR
                            if (cmd[0] && !busy_reg) begin               // START
                                start_pulse_reg <= 1'b1;
                                done_flag_reg   <= 1'b0;
                                busy_reg        <= 1'b1;
                            end
                        end
                        default: ; // RO
                    endcase
                end
            end

            // Estado del núcleo
            if (error_code_i != 0) begin
                error_code_reg <= error_code_i;
                busy_reg       <= 1'b0;
            end
            if (pixel_done_i) begin
                done_flag_reg <= 1'b1;
                busy_reg      <= 1'b0;
            end

            if (READ_CLEAR_DONE && state_q == S_RESP && !we_lat && addr_lat==ADDR_STATUS && rvalid_o)
                done_flag_reg <= 1'b0;
        end
    end

endmodule
