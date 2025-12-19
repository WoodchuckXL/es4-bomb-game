module top (
  input logic [4:0] mg_in,

  input logic [2:0] wg_inA,
  input logic [2:0] wg_inB,

  input logic [3:0] wr_i,
  output logic [3:0] wr_o,

  input logic clk_12m,

  output logic [8:0] vga,
  output logic light,
  output wire speaker
);
  // Clocks and counters
  logic vga_clk;
  logic frame_clk;
  logic [17:0] rng_counter;
  vga_clk_gen clkgen (.clk_12m(clk_12m), .vga_clk(vga_clk), .vga_frame_clk(frame_clk), .clk_counter(rng_counter));

  `define TIME 300
  logic [8:0] death_counter = 0, death_timer;
  assign death_timer = `TIME - death_counter;

  `define IDLE 3'b000
  `define WEIGHT 3'b001
  `define MEM 3'b010
  `define WIRE 3'b011
  `define DONE 3'b100
  `define FAIL 3'b101
  logic [2:0] state = `IDLE, next_state = `IDLE;
  logic mg_enabled, wg_enabled, wr_enabled;
  logic mg_done, wg_done, wr_done;
  logic [8:0] st_vga, mg_vga, wg_vga, wr_vga, dn_vga, no_vga;

  assign no_vga = 9'b000000000;

  vga_driver_idle idle (.vga_clk(vga_clk), .timer(death_timer), .vga(st_vga));

  vga_driver_done done (.vga_clk(vga_clk), .timer(death_timer), .vga(dn_vga));

  vga_driver_wire wire_vis (.vga_clk(vga_clk), .timer(death_timer), .vga(wr_vga));

  vga_driver_mg mem_game (.enabled(mg_enabled), .input_data(~mg_in), 
  .vga_clk(vga_clk), .frame_clk(frame_clk), .rng_counter(rng_counter), 
  .timer(death_timer),
  .vga(mg_vga), .out(mg_done));

  weight_game weight_game (.enabled(wg_enabled), .timer(death_timer), .inA(wg_inA), .inB(wg_inB), 
  .randomNums(rng_counter), .vga_clk(vga_clk), .frame_clk(frame_clk), 
  .vga(wg_vga), .out(wg_done));

  wire_game wire_i (.enabled(wr_enabled), .i3(wr_i[3]), .i2(wr_i[2]), .i1(wr_i[1]), .i0(wr_i[0]), 
  .o3(wr_o[3]), .o2(wr_o[2]), .o1(wr_o[1]), .o0(wr_o[0]), .clk(clk_12m), .y(wr_done));

  always_ff @(posedge frame_clk) begin
    state <= next_state;
    mg_enabled <= 0;  
    wg_enabled <= 0;
    wr_enabled <= 0;
    light <= 0;
    case (state)
      `IDLE: begin
        light <= 1;
        if (mg_in[4] == 0) next_state <= `WEIGHT;
        else if (death_counter == `TIME) next_state <= `FAIL;
        else next_state <= `IDLE;
      end
      `WEIGHT: begin
        wg_enabled <= 1;
        light <= wg_done;
        if (wg_done == 1 && mg_in[4] == 0) next_state <= `MEM;
        else if (death_counter == `TIME) next_state <= `FAIL;
        else next_state <= `WEIGHT;
      end
      `MEM: begin
        mg_enabled <= 1;
        light <= mg_done;
        if (mg_done == 1 && mg_in[4] == 0) next_state <= `WIRE;
        else if (death_counter == `TIME) next_state <= `FAIL;
        else next_state <= `MEM;
      end
      `WIRE: begin
        wr_enabled <= 1;
        light <= wr_done;
        if (wr_done == 1 && mg_in[4] == 0) next_state <= `DONE;
        else if (death_counter == `TIME) next_state <= `FAIL;
        else next_state <= `WIRE;
      end
      `DONE: begin
        light <= 1;
        next_state <= `DONE;
      end
      `FAIL: begin
        light <= 0;
        next_state <= `FAIL;
      end
    endcase
  end

  assign vga = (state == `IDLE) ? st_vga : (
    (state == `WEIGHT) ? wg_vga : (
    (state == `MEM) ? mg_vga : (
    (state == `WIRE) ? wr_vga : (
    (state == `DONE) ? dn_vga : no_vga))));

always_ff @(posedge beep) begin
  if (state != `DONE) death_counter = death_counter + 1;
end

// SPEAKER stuff //
    logic [23:0] counter = 0;
    logic [20:0] beepCounter = 0;
    logic beep = 0;

    always @(posedge clk_12m) begin
        if(beep) begin
            beepCounter <= beepCounter + 1;
        end
        else begin
            beepCounter <= 0;
        end
    end
    always @(posedge clk_12m) begin
        if (counter >= 12_000_000 - 1) begin
            counter <= 0;
            beep <= 1;
        end else begin
            counter <= counter + 1;
            if (beep && beepCounter[20])
                beep <= 0;  
        end
        if (state == `FAIL) beep <= 1;
    end

    reg [14:0] tickCounter = 0;
    wire tick = tickCounter[14];

    always @(posedge clk_12m) begin
        if (beep)
            tickCounter <= tickCounter + 1;
        else
            tickCounter <= 0;
    end

    assign speaker = (state == `DONE) ? 0 : tick;
endmodule


// ------------------------------- ********* ------------------------------- //
// ------------------------------- ********* ------------------------------- //
// ------------------------------- VGA STUFF ------------------------------- //
// ------------------------------- ********* ------------------------------- //
// ------------------------------- ********* ------------------------------- //



module vga_driver_idle (
  input logic vga_clk,
  input logic [8:0] timer,
  output logic [8:0] vga
);
  logic [9:0]x;
  logic [9:0]y;
  logic valid;
  vga vga_idle (.clk(vga_clk), .x(x), .y(y), .valid(valid), .HSYNC(vga[2]), .VSYNC(vga[1]));

  idle_visuals vis (.valid(valid), .timer(timer), .col(x), .row(y), .rgb(vga[8:3]));
  assign vga[0] = 0;
endmodule

module idle_visuals (
    input logic [8:0] timer,
    input logic valid,
    input logic [9:0] col,
    input logic [9:0] row,
    output logic [5:0] rgb
);
  logic [5:0] index;
  logic [2:0] sprite_y, sprite_x;
  logic [47:0] sprite_data;
  logic [5:0] sprite_color;
  sprite_rom_8 sprites (.index(index), .addr(sprite_y), .data(sprite_data));

  always_comb begin
    index = 0;
    sprite_color = sprite_data[sprite_x*6+5:sprite_x*6];
    sprite_x = 0;
    sprite_y = 0;
    if (valid) begin
      rgb = 6'b111111;
      if (col < 8 && row < 8) begin
        index = 3;
        sprite_x = 15-col;
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 16 && row < 8) begin
        index = 4;
        sprite_x = 15-(col - 8);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 24 && row < 8) begin
        index = 5;
        sprite_x = 15-(col - 16);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 32 && row < 8) begin
        index = 20;
        sprite_x = 15-(col - 24);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 40 && row < 8) begin
        index = 18;
        sprite_x = 15-(col - 32);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 48 && row < 8) begin
        index = 4;
        sprite_x = 15-(col - 40);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 56 && row < 8) begin
        rgb = 6'b000000;
      end
      else if (col < 64 && row < 8) begin
        index = 19;
        sprite_x = 15-(col - 56);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 72 && row < 8) begin
        index = 7;
        sprite_x = 15-(col - 64);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 80 && row < 8) begin
        index = 4;
        sprite_x = 15-(col - 72);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 88 && row < 8) begin
        rgb = 6'b000000;
      end
      else if (col < 96 && row < 8) begin
        index = 1;
        sprite_x = 15-(col - 88);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 104 && row < 8) begin
        index = 14;
        sprite_x = 15-(col - 96);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 112 && row < 8) begin
        index = 12;
        sprite_x = 15-(col - 104);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 120 && row < 8) begin
        index = 1;
        sprite_x = 15-(col - 112);
        sprite_y = row;
        rgb = sprite_color;
      end

      // Timer
      if (col >= 640 - 32 && row < 32) begin
        index = 26 + (timer % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end
      else if (col >= 640 - 64 && row < 32) begin
        index = 26 + ((timer/10) % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end
      else if (col >= 640 - 98 && row < 32) begin
        index = 26 + ((timer/100) % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end

    end 
    else rgb = 6'b0;
  end

endmodule


module vga_driver_done (
  input logic vga_clk,
  input logic [8:0] timer,
  output logic [8:0] vga
);
  logic [9:0]x;
  logic [9:0]y;
  logic valid;
  vga vga_idle (.clk(vga_clk), .x(x), .y(y), .valid(valid), .HSYNC(vga[2]), .VSYNC(vga[1]));

  done_visuals vis (.valid(valid), .timer(timer), .col(x), .row(y), .rgb(vga[8:3]));
  assign vga[0] = 0;
endmodule

module done_visuals (
    input logic valid,
    input logic [8:0] timer,
    input logic [9:0] col,
    input logic [9:0] row,
    output logic [5:0] rgb
);
  logic [5:0] index;
  logic [2:0] sprite_y, sprite_x;
  logic [47:0] sprite_data;
  logic [5:0] sprite_color;
  sprite_rom_8 sprites (.index(index), .addr(sprite_y), .data(sprite_data));

  always_comb begin
    index = 0;
    sprite_color = sprite_data[sprite_x*6+5:sprite_x*6];
    sprite_x = 0;
    sprite_y = 0;
    if (valid) begin
      rgb = 6'b111111;
      if (col < 8 && row < 8) begin
        index = 6;
        sprite_x = 15-col;
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 16 && row < 8) begin
        index = 14;
        sprite_x = 15-(col - 8);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 24 && row < 8) begin
        index = 14;
        sprite_x = 15-(col - 16);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 32 && row < 8) begin
        index = 3;
        sprite_x = 15-(col - 24);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 40 && row < 8) begin
        index = 0;
        sprite_x = 15-(col - 32);
        sprite_y = row;
        rgb = 6'b000000;
      end
      else if (col < 48 && row < 8) begin
        index = 9;
        sprite_x = 15-(col - 40);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 56 && row < 8) begin
        index = 14;
        sprite_x = 15-(col - 48);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 64 && row < 8) begin
        index = 1;
        sprite_x = 15-(col - 56);
        sprite_y = row;
        rgb = sprite_color;
      end


      // Timer
      if (col >= 640 - 32 && row < 32) begin
        index = 26 + (timer % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end
      else if (col >= 640 - 64 && row < 32) begin
        index = 26 + ((timer/10) % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end
      else if (col >= 640 - 98 && row < 32) begin
        index = 26 + ((timer/100) % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end
    end 
    else rgb = 6'b0;
  end

endmodule


module vga_driver_wire (
  input logic vga_clk,
  input logic [8:0] timer,
  output logic [8:0] vga
);
  logic [9:0]x;
  logic [9:0]y;
  logic valid;
  vga vga_idle (.clk(vga_clk), .x(x), .y(y), .valid(valid), .HSYNC(vga[2]), .VSYNC(vga[1]));

  wire_visuals vis (.valid(valid), .timer(timer), .col(x), .row(y), .rgb(vga[8:3]));
  assign vga[0] = 0;
endmodule

module wire_visuals (
    input logic valid,
    input logic [8:0] timer,
    input logic [9:0] col,
    input logic [9:0] row,
    output logic [5:0] rgb
);
  logic [5:0] index;
  logic [2:0] sprite_y, sprite_x;
  logic [47:0] sprite_data;
  logic [5:0] sprite_color;
  sprite_rom_8 sprites (.index(index), .addr(sprite_y), .data(sprite_data));

  always_comb begin
    index = 0;
    sprite_color = sprite_data[sprite_x*6+5:sprite_x*6];
    sprite_x = 0;
    sprite_y = 0;
    if (valid) begin
      rgb = 6'b110011;
      if (col < 8 && row < 8) begin
        index = 1;
        sprite_x = 15-col;
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 16 && row < 8) begin
        index = 17;
        sprite_x = 15-(col - 8);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 24 && row < 8) begin
        index = 8;
        sprite_x = 15-(col - 16);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 32 && row < 8) begin
        index = 13;
        sprite_x = 15-(col - 24);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 40 && row < 8) begin
        index = 6;
        sprite_x = 15-(col - 32);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 48 && row < 8) begin
        index = 0;
        sprite_x = 15-(col - 40);
        sprite_y = row;
        rgb = 6'b000000;
      end
      else if (col < 56 && row < 8) begin
        index = 24;
        sprite_x = 15-(col - 48);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 64 && row < 8) begin
        index = 14;
        sprite_x = 15-(col - 56);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 72 && row < 8) begin
        index = 20;
        sprite_x = 15-(col - 64);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 80 && row < 8) begin
        index = 17;
        sprite_x = 15-(col - 72);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 88 && row < 8) begin
        index = 0;
        sprite_x = 15-(col - 80);
        sprite_y = row;
        rgb = 6'b000000;
      end
      else if (col < 96 && row < 8) begin
        index = 14;
        sprite_x = 15-(col - 88);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 104 && row < 8) begin
        index = 22;
        sprite_x = 15-(col - 96);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 112 && row < 8) begin
        index = 13;
        sprite_x = 15-(col - 104);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 120 && row < 8) begin
        index = 0;
        sprite_x = 15-(col - 112);
        sprite_y = row;
        rgb = 6'b000000;
      end
      else if (col < 128 && row < 8) begin
        index = 1;
        sprite_x = 15-(col - 120);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 136 && row < 8) begin
        index = 17;
        sprite_x = 15-(col - 128);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 144 && row < 8) begin
        index = 4;
        sprite_x = 15-(col - 136);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 152 && row < 8) begin
        index = 0;
        sprite_x = 15-(col - 144);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 160 && row < 8) begin
        index = 10;
        sprite_x = 15-(col - 152);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 168 && row < 8) begin
        index = 5;
        sprite_x = 15-(col - 160);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 176 && row < 8) begin
        index = 0;
        sprite_x = 15-(col - 168);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 184 && row < 8) begin
        index = 18;
        sprite_x = 15-(col - 176);
        sprite_y = row;
        rgb = sprite_color;
      end
      else if (col < 192 && row < 8) begin
        index = 19;
        sprite_x = 15-(col - 184);
        sprite_y = row;
        rgb = sprite_color;
      end

      // Timer
      if (col >= 640 - 32 && row < 32) begin
        index = 26 + (timer % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end
      else if (col >= 640 - 64 && row < 32) begin
        index = 26 + ((timer/10) % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end
      else if (col >= 640 - 98 && row < 32) begin
        index = 26 + ((timer/100) % 10);
        sprite_x = 15-(col - (640 - 32))/4;
        sprite_y = row/4;
        rgb = (sprite_color == 6'b111111) ? 6'b110000 : 6'b000000;
      end
    end 
    else rgb = 6'b0;
  end

endmodule