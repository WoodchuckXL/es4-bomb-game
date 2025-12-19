//finite state logic
//represented here as a module but this will function in our program's top-level module
//k is a status input - when games finish, k goes high for a brief time
//win output goes high in the last state (WIN state)
//fail output goes high if timer runs out
//fail output goes high if timer runs out, - TIMER STARTS WHEN THE FPGA IS POWERED
module finitestate (
input logic k,
output logic win,
output logic fail
);
//TO DO: INSTANTIATE CHIP CLOCK
logic clk;
SB_HFOSC #(
    .CLKHF_DIV("0b00")
) osc (
    .CLKHFPU(1'b1), // Power up
    .CLKHFEN(1'b1), // Enable
    .CLKHF(clk) // Clock output
);

//state update clock
logic stateclk;

//counter for fail condition
logic [25:0] counter = 34'd0;

//state logic signals, nextstate logic signals
logic [2:0] state;
logic [2:0] nextstate;

//generate next state with comb. logic
always_comb begin
 nextstate[2] = state[2] + (state[0] & k & state[1]);
 nextstate[1] = (state[0] & k) + (~state[2] & state[1] & ~state[0]);
 nextstate[0] = (state[0] & ~k) + (~state[0] & k & ~state[2]);
end

//pass state values through registers
always_ff @(posedge clk) begin
    state <= nextstate;
    //increment counter
    counter <= counter + 1;
    //create state clock
    stateclk <= counter[25];
end

//win and fail conditions
always_comb begin
win = state[2];
fail = counter[33];
end

//game selector - drive the value of win based on what game we are on
//case statements

endmodule
