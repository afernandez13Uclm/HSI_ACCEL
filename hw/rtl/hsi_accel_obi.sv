module hsi_accel_obi #(
  parameter int unsigned AW = 32,
  parameter int unsigned DW = 32
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  // OBI slave interface
  input  logic             req_i,
  input  logic [AW-1:0]    addr_i,
  input  logic             we_i,
  input  logic [DW-1:0]    wdata_i,
  output logic [DW-1:0]    rdata_o,
  output logic             rvalid_o
);

  // Señales internas entre wrapper y core
  logic        start;
  logic [1:0]  op_code;
  logic [15:0] pixel_size;
  logic [15:0] result;
  logic        valid_result;
  logic        pixel_done;
  logic        busy;

  // Instancia del wrapper OBI
  hsi_vector_core_wrapper u_wrapper (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .req_i(req_i),
    .addr_i(addr_i[7:0]), // usamos parte baja como dirección local
    .we_i(we_i),
    .wdata_i(wdata_i),
    .rdata_o(rdata_o),
    .rvalid_o(rvalid_o),
    .start_o(start),
    .op_code_o(op_code),
    .pixel_size_o(pixel_size),
    .result_i(result),
    .valid_result_i(valid_result),
    .pixel_done_i(pixel_done),
    .busy_i(busy)
  );

  // Instancia del core de procesamiento HSI
    hsi_vector_core u_core (
    .clk(clk_i),
    .rst_n(rst_ni),
    .start(start),
    .op_code(op_code),
    .num_bands(pixel_size),

    // Entradas de datos dummy
    .in1_wr_en(1'b0),
    .in1_data_in(16'b0),
    .in1_full(),

    .in2_wr_en(1'b0),
    .in2_data_in(16'b0),
    .in2_full(),

    .out_rd_en(1'b0),
    .out_empty(),
    .out_data_out(),
    .out_full(),

    .pixel_done(pixel_done),
    .valid(valid_result),
    .result(result),
    .error_code()
  );

endmodule
