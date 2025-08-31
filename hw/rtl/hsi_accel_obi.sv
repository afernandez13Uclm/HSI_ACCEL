/**
 * @file hsi_accel_obi.sv
 * @brief Módulo top para la integración del wrapper OBI y el núcleo HSI Vector Core.
 *
 * @details
 * Este archivo top conecta el wrapper `hsi_vector_core_wrapper` con el núcleo `hsi_vector_core`.
 * Expone una interfaz OBI para facilitar su integración dentro de plataformas como X-HEEP.
 * 
 * El wrapper maneja la configuración del núcleo (op_code, num_bands, start) y proporciona acceso
 * al estado del procesamiento. Los vectores de entrada/salida deben conectarse externamente.
 *
 * @author
 * Alejandro Fernández Rodríguez, UCLM
 * @version 1.0
 * @date 2025
 */
module hsi_accel_obi #(
    parameter int COMPONENT_WIDTH = 16,
    parameter int FIFO_DEPTH      = 16,
    parameter int COMPONENTS_MAX  = 3,
    localparam int DATA_WIDTH     = COMPONENT_WIDTH * COMPONENTS_MAX,
    localparam int CNT_WIDTH      = $clog2(COMPONENTS_MAX)
)(
    input  logic                           clk_i,
    input  logic                           rst_ni,

    //==================== OBI slave ====================
    input  logic                           req_i,
    input  logic                           we_i,
    input  logic  [3:0]                    be_i,
    input  logic  [31:0]                   addr_i,
    input  logic  [31:0]                   wdata_i,

    output logic                           gnt_o,
    output logic                           rvalid_o,
    output logic  [31:0]                   rdata_o,
    output logic                           err_o,

    //==================== FIFO hacia core ==============
    output logic                           in1_wr_en_o,
    output logic                           in2_wr_en_o,
    output logic  [DATA_WIDTH-1:0]         in1_data_o,
    output logic  [DATA_WIDTH-1:0]         in2_data_o,

    //  Señal opcional de lectura externa; se OR‑ea con la generada por el bus
    input  logic                           out_rd_en_i,

    output logic                           out_empty_o,
    output logic  [DATA_WIDTH-1:0]         out_data_o
);

    // ------------------------------------------------------------------------
    // Señales de control procedentes del wrapper de registros
    // ------------------------------------------------------------------------
    logic [3:0]  op_code;
    logic [31:0] num_bands;
    logic        start;
    logic        pixel_done;
    logic [3:0]  error_code;
    logic        in1_full, in2_full, out_full;
    /* verilator lint_off UNDRIVEN */
    logic        in1_empty, in2_empty;
    /* verilator lint_on UNDRIVEN */

    // Direcciones para los registros de datos FIFO
    localparam logic [31:0] ADDR_FIFO_IN1 = 32'h20;
    localparam logic [31:0] ADDR_FIFO_IN2 = 32'h24;
    localparam logic [31:0] ADDR_FIFO_OUT = 32'h28;

    // ------------------------------------------------------------------------
    // Registro CSR + wrapper
    // ------------------------------------------------------------------------
    logic        csr_gnt,  csr_rvalid, csr_err;
    logic [31:0] csr_rdata;

    hsi_vector_core_wrapper #(
        .OP_CODE_WIDTH(4),
        .NUM_BANDS_WIDTH(32),
        .ERR_WIDTH(4),
        .READ_CLEAR_DONE(0),
        .EXPOSE_FIFO_STATUS(1)
    ) i_wrapper (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        // Señales OBI
        .req_i(req_i),
        .we_i(we_i),
        .be_i(be_i),
        .addr_i(addr_i),
        .wdata_i(wdata_i),
        .gnt_o(csr_gnt),
        .rvalid_o(csr_rvalid),
        .rdata_o(csr_rdata),
        .err_o(csr_err),
        // Salida de control
        .op_code_o(op_code),
        .num_bands_o(num_bands),
        .start_o(start),
        .pixel_done_i(pixel_done),
        .error_code_i(error_code),
        .in1_full_i(in1_full),
        .in2_full_i(in2_full),
        .out_full_i(out_full),
        .out_empty_i(out_empty_o),
        .in1_empty_i(in1_empty),
        .in2_empty_i(in2_empty)
    );

    // ------------------------------------------------------------------------
    // Decodificación de acceso
    // ------------------------------------------------------------------------
    logic trans_wr_in1   = req_i & we_i  & (addr_i == ADDR_FIFO_IN1);
    logic trans_wr_in2   = req_i & we_i  & (addr_i == ADDR_FIFO_IN2);
    logic trans_rd_out   = req_i & ~we_i & (addr_i == ADDR_FIFO_OUT);

    logic fifo_wr_in1_ok = trans_wr_in1 & ~in1_full;
    logic fifo_wr_in2_ok = trans_wr_in2 & ~in2_full;
    logic fifo_rd_out_ok = trans_rd_out & ~out_empty_o;

    // Acceso FIFO?  -> Necesitamos tratar handshake manualmente
    logic trans_fifo = trans_wr_in1 | trans_wr_in2 | trans_rd_out;

    // ------------------------------------------------------------------------
    // Generación de gnt_o
    // Para accesos a los FIFO se concede solo cuando hay espacio/datos
    // Para el resto de direcciones delegamos en el wrapper CSR
    // ------------------------------------------------------------------------
    assign gnt_o = (trans_fifo) ? (fifo_wr_in1_ok | fifo_wr_in2_ok | fifo_rd_out_ok) : csr_gnt;

    // ------------------------------------------------------------------------
    // Rutas de escritura a FIFO IN1 / IN2 (empaquetado de 16‑bit)
    // ------------------------------------------------------------------------
    /* verilator lint_off UNUSED */
    logic [DATA_WIDTH-1:0] acc_in1, acc_in2;
    logic [CNT_WIDTH-1:0]  cnt_in1, cnt_in2;
    /* verilator lint_on UNUSED */

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            in1_wr_en_o <= 1'b0;
            in2_wr_en_o <= 1'b0;
            in1_data_o  <= '0;
            in2_data_o  <= '0;
            acc_in1     <= '0;
            acc_in2     <= '0;
            cnt_in1     <= '0;
            cnt_in2     <= '0;
        end else begin
            // Pulsos mono‑ciclo por defecto
            in1_wr_en_o <= 1'b0;
            in2_wr_en_o <= 1'b0;

            // ================= FIFO IN1 =================
            if (fifo_wr_in1_ok & gnt_o) begin
                acc_in1 <= {acc_in1[DATA_WIDTH-COMPONENT_WIDTH-1:0], wdata_i[COMPONENT_WIDTH-1:0]};
                if (cnt_in1 == CNT_WIDTH'(COMPONENTS_MAX-1)) begin
                    in1_data_o  <= {acc_in1[DATA_WIDTH-COMPONENT_WIDTH-1:0], wdata_i[COMPONENT_WIDTH-1:0]};
                    in1_wr_en_o <= 1'b1;
                    cnt_in1    <= '0;
                end else begin
                    cnt_in1 <= cnt_in1 + 1'b1;
                end
            end

            // ================= FIFO IN2 =================
            if (fifo_wr_in2_ok & gnt_o) begin
                acc_in2 <= {acc_in2[DATA_WIDTH-COMPONENT_WIDTH-1:0], wdata_i[COMPONENT_WIDTH-1:0]};
                if (cnt_in2 == CNT_WIDTH'(COMPONENTS_MAX-1)) begin
                    in2_data_o  <= {acc_in2[DATA_WIDTH-COMPONENT_WIDTH-1:0], wdata_i[COMPONENT_WIDTH-1:0]};
                    in2_wr_en_o <= 1'b1;
                    cnt_in2    <= '0;
                end else begin
                    cnt_in2 <= cnt_in2 + 1'b1;
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Lectura desde FIFO OUT  (desempaquetado a 16‑bit)
    // ------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] shift_out;
    logic [CNT_WIDTH-1:0]  cnt_out;
    logic                  fifo_pop_bus;
    logic                  rvalid_fifo_reg;
    logic [31:0]           rdata_fifo_reg;

    // Pop desde el bus cuando se solicita una nueva palabra completa
    assign fifo_pop_bus = fifo_rd_out_ok & gnt_o & (cnt_out == '0);

    // Señal que efectivamente leerá el core
    logic core_out_rd_en;
    assign core_out_rd_en = out_rd_en_i | fifo_pop_bus;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cnt_out         <= '0;
            shift_out       <= '0;
            rvalid_fifo_reg <= 1'b0;
            rdata_fifo_reg  <= 32'b0;
        end else begin
            // Cuando toca coger nueva palabra
            if (fifo_pop_bus) begin
                shift_out <= out_data_o;          // Cargamos la palabra de DATA_WIDTH
            end

            // Si estamos en un ciclo de lectura
            if (fifo_rd_out_ok & gnt_o) begin
                // Sacamos el componente alto de shift_out
                rdata_fifo_reg  <= {16'b0, shift_out[DATA_WIDTH-1 -: COMPONENT_WIDTH]};
                rvalid_fifo_reg <= 1'b1;

                // Preparamos siguiente componente
                shift_out <= shift_out << COMPONENT_WIDTH;
                if (cnt_out == CNT_WIDTH'(COMPONENTS_MAX-1)) begin
                    cnt_out <= '0;
                end else begin
                    cnt_out <= cnt_out + 1'b1;
                end
            end else begin
                rvalid_fifo_reg <= 1'b0; // De‑asertamos cuando no hay acceso
            end
        end
    end

    // ------------------------------------------------------------------------
    // Núcleo vectorial
    // ------------------------------------------------------------------------
    hsi_vector_core #(
        .COMPONENT_WIDTH(COMPONENT_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .COMPONENTS_MAX(COMPONENTS_MAX)
    ) i_hsi_core (
        .clk(clk_i),
        .rst_n(rst_ni),
        .in1_wr_en(in1_wr_en_o),
        .in1_data_in(in1_data_o),
        .in1_full(in1_full),
        .in2_wr_en(in2_wr_en_o),
        .in2_data_in(in2_data_o),
        .in2_full(in2_full),
        .out_rd_en(core_out_rd_en),
        .out_data_out(out_data_o),
        .out_empty(out_empty_o),
        .out_full(out_full),
        .op_code(op_code),
        .num_bands(num_bands),
        .start(start),
        .pixel_done(pixel_done),
        .error_code(error_code)
    );

    // ------------------------------------------------------------------------
    // Multiplexor final hacia bus OBI
    // ------------------------------------------------------------------------
    assign rvalid_o = trans_rd_out ? rvalid_fifo_reg : csr_rvalid;
    assign rdata_o  = trans_rd_out ? rdata_fifo_reg  : csr_rdata;
    assign err_o    = trans_rd_out ? (~fifo_rd_out_ok) : csr_err;

endmodule
