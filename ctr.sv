// Helper module

module ctr #(parameter BITS=2) (
  input logic clk,
  output logic [BITS-1:0] y
);
  logic [BITS-1:0] count_num = 0;

  assign y = count_num;

  always_ff @(posedge clk) begin
    count_num <= count_num + 1;
  end
endmodule

module ctr_reset #(
    parameter BITS=2) (
  input logic clk,
  input logic reset,
  output logic [BITS-1:0] y
);
  logic [BITS-1:0] count_num = 0;

  assign y = count_num;

  always_ff @(posedge clk) begin
    if (reset) count_num <= 0;
    else count_num <= count_num + 1;
  end
endmodule