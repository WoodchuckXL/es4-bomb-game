module counter(
    input logic clk,
    output logic [25:0] counter
    );

    // Counter logic
    always_ff @(posedge clk) begin
        counter <= counter + 1;
    end

endmodule


