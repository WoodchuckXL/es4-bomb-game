module register(
    input logic clk,
    input logic in,
    output logic out
    );

    logic z;

    always_ff@(posedge clk) begin
        z <= in;
        out <= z;
    end
endmodule