module encoder(
    input logic a, 
    input logic b,
    input logic clk, 
    input logic rst,
    output logic [5:0] number
    );
    
    // logic variabes for a slower clock signal
    logic sim_clk;
    logic [25:0] counter;
    // logic for syncing data to clock
    logic [1:0] syncA;
    logic [1:0] syncB;
    // logic for detecting negedge on encoder
    logic fallEdge;
    logic [5:0] leftTurn;
    logic [5:0] rightTurn;

    //clock functionality
    

    counter real_counter(
        .clk({clk}),
        .counter({counter})
    );
    always_comb begin 
        sim_clk = counter[15];
    end

    // two bit shift register for the two inputs of the encoder
    register registerA(
        .clk({sim_clk}),
        .in({a}),
        .out({syncA[0]})
    );
    register registerA1(
        .clk({sim_clk}),
        .in({syncA[0]}),
        .out({syncA[1]})
    );
    register registerB(
        .clk({sim_clk}),
        .in({b}),
        .out({syncB[0]})
    );
    register registerB1(
        .clk({sim_clk}),
        .in({syncB[0]}),
        .out({syncB[1]})
    );

    always_comb begin
        fallEdge = ~syncA[0] && syncA[1];
    end

    rotCheck real_rotCheck(
        .clk({clk}),
        .fallEdge({fallEdge}),
        .a({syncA}),
        .b({syncB}),
        .rst({rst}),
        .posTurn({rightTurn}),
        .negTurn({leftTurn})
    ); 

    assign number = (rightTurn - leftTurn);

endmodule
