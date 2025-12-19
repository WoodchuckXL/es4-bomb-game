module vga_clk_gen (
    input logic clk_12m,
    output logic vga_clk,
    output logic vga_frame_clk,
    output logic [17:0] clk_counter
);
    logic locked;
    logic clk;
    mypll pll(
        .clock_in(clk_12m), 
        .clock_out(clk), 
        .locked(locked)
    );
    assign vga_clk = clk;

    localparam int DIV = 420000;
    localparam int DIV_2 = 210000;
    logic [17:0] frame_internal = 0;
    always_ff @(posedge clk) begin
        if (frame_internal == DIV_2 - 1) begin
            frame_internal <= 0;
            vga_frame_clk <= ~vga_frame_clk;
        end else begin
            frame_internal <= frame_internal + 1;
            clk_counter <= clk_counter + 1;
        end
    end

endmodule

module vga (
  input logic clk,
  output logic [9:0]x,
  output logic [9:0]y,
  output logic valid,
  output logic HSYNC,
  output logic VSYNC
);
  always_ff @(posedge clk)begin

    if (x == 10'd800 - 1) begin
      x = 0;
      if (y == 10'd525 - 1) y = 0;
      else y = y + 1;
    end else x = x + 1;
    
    
  end

  always_comb begin
    // start of HSYNC 640 + 16 -> 640 + 16 + 96
    HSYNC = !(x >= 656 && x < 752);

    // start of VSYNC 480 + 10 -> 480 + 10 + 2
    VSYNC = !(y >= 490 && y < 492);

    // return valid visible area
    valid = (x < 640 && y < 480);
  end

endmodule

module pattern_gen (
  input logic valid,
  input logic [9:0] col,
  input logic [9:0] row,
  output logic [5:0] rgb
);

  always_comb begin
    if (valid) begin
      if (col < 160) rgb = 6'b001100;
      else if (col < 320) rgb = 6'b001000;
      else if (col < 480) rgb = 6'b000100;
      else rgb = 6'b0;
    end 
    else rgb = 6'b0;
  end

endmodule