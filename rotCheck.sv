module rotCheck(
    input logic clk,
    input logic fallEdge,
    input logic [1:0] a, 
    input logic [1:0] b, 
    input logic rst,
    output logic [5:0] posTurn,
    output logic [5:0] negTurn
    );

    always_ff @(posedge fallEdge) begin
        if(a[0] == 1'b0 && b[1] == 1'b1) begin
            posTurn <= posTurn + 1;
            negTurn <= negTurn;
        end
        else if(b[0] == 1'b0 && a[1] == 1'b1) begin
            negTurn <= negTurn + 1;
            posTurn <= posTurn;
        end
        else begin
            posTurn <= posTurn;
            negTurn <= negTurn;
        end
    end

endmodule