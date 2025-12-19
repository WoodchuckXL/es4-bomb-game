//Wire game top-level module
//The game works by sending a unique signal through each of the four wires. When a wire is connected
//on the right side, a module checks that wire's signal with the expected signal for that pin. 
//Indicator goes high when all four wire signals match expected (wires are connected correctly)
module wire_game (
//signal reciever inputs
//these inputs are checked against the expected signals to drive the "game complete" output
input logic i3,
input logic i2,
input logic i1,
input logic i0,
//outputs generating signals for each of the wires
output logic o3,
output logic o2,
output logic o1,
output logic o0,

input logic clk,
input logic enabled,
//correct/incorect sequence indicator (game controller)
output logic y
);

//Instantiate the chip clock
// logic clk;
// SB_HFOSC #(
//     .CLKHF_DIV("0b00")
// ) osc (
//     .CLKHFPU(1'b1), // Power up
//     .CLKHFEN(1'b1), // Enable
//     .CLKHF(clk) // Clock output
// );

//clk1 is a clock used for the checksig module. It's phase shifted so that checksig does not
//read the wire signals as they are changing
logic clk1;

//Drive every wire output (to be read) and create expected signals to compare

logic [25:0] counter = 26'd0;
//offset counter for checksig clock - starts counting a quarter of the way through the wire signals' period
logic [25:0] clkcounter = 26'b00000000100000000000000000;

//variables for expected wire signals
logic exp3;
logic exp2;
logic exp1;
logic exp0;

always_ff @(posedge clk) begin
    //update the counters
    counter <= counter + 1;
    clkcounter <= clkcounter + 1;
    //update checksig clock
    clk1 <= clkcounter[16];
    //drive wire signals (from top pin to bottom: on, blink1, blink2, off)
    o2 <= counter[17];
    o1 <= ~counter[17];
    exp3 <= ~counter[17];
    exp2 <= counter[17];
  end

assign o3 = 1'b1;
assign o0 = 1'b0;
assign exp1 = 1'b1;
assign exp0 = 1'b0;

//Check reciever inputs with expected signals
//expected signals (from top pin to bottom): blink2, blink1, on, off

logic check3;
logic check2;
logic check1;
logic check0;

checksig checksig3(
.data(i3),
.ex(exp3),
.clk(clk1),
.y(check3)
);

checksig checksig2(
.data(i2),
.ex(exp2),
.clk(clk1),
.y(check2)
);

checksig checksig1(
.data(i1),
.ex(exp1),
.clk(clk1),
.y(check1)
);

checksig checksig0(
.data(i0),
.ex(exp0),
.clk(clk1),
.y(check0)
);

//update output LED - on iff. all 4 signals recieved match expected
always_comb begin
    y = check1 & check2 & check3 & check0 & enabled;
end
endmodule

//checksig module checks to see if a reciever input signal matches the expected signal
module checksig (
//reciever input signal
input logic data,
//expected signal
input logic ex,
input logic clk,
output logic y
);

logic [3:0] datavec;
logic [3:0] exvec;

always_ff @(posedge clk) begin
    //read in expected and data values to shift registers
    datavec[0] <= data;
    datavec[1] <= datavec[0];
    datavec[2] <= datavec[1];
    datavec[3] <= datavec[2];
    exvec[0] <= ex;
    exvec[1] <= exvec[0];
    exvec[2] <= exvec[1];
    exvec[3] <= exvec[2];
end

//check if data and expected vectors match and update output accordingly
always_comb begin
if (exvec == datavec)
    y = 1'b1;
else
    y = 1'b0;
end

endmodule

