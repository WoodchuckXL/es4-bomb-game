module vga_driver_mg (
  input logic enabled,
  input logic [4:0] input_data,
  input logic vga_clk,
  input logic frame_clk,
  input logic [17:0] rng_counter,
  input logic [8:0] timer,

  output logic [8:0] vga,
  output logic out
  );
  logic [5:0] frameCounter; 

  // Game state variables
  `define IDLE 2'b00
  `define SEQD 2'b01
  `define USEI 2'b10
  `define DONE 2'b11
  logic [1:0] mg_state = `IDLE, mg_state_next;
  logic [3:0] color, p_color, p_color_prev, s_color; // Color screen output

  // Current sequence variables
  `define SEQ_LEN 12
  `define SEQ_ADD 2
  logic [3:0] cur_seq_len = `SEQ_ADD;
  logic [3:0] seq_i = 0, seq_i_s, seq_i_p;
  logic seq_i_rst;
  logic seq_over_s=0, seq_over_p=0;
  logic [`SEQ_LEN*2-1:0] seq_data;

  // Update frame logic
  always_ff @(posedge frame_clk) begin
    // Variable defaults
    seq_i_rst <= 1;

    // ---------- STATE MACHINE ---------- //
    // State switching logic
    if (mg_state_next != mg_state) begin
      case (mg_state_next)
        `IDLE: ;
        `SEQD: begin 
          seq_i_rst <= 0;
        end
        `USEI: begin 
          seq_i_p = 0;
          seq_over_p = 0;
        end
        `DONE: ;
      endcase
      frameCounter = 0; // Reset the second clock
    end
    // Update state
    mg_state = mg_state_next;
    // State logic for each frame
    case (mg_state)
      `IDLE: begin 
        color = 4'b0000;
        if (input_data[4] && enabled) begin 
          mg_state_next <= `SEQD;
          seq_data = rng_counter;
          seq_data *= 4759;
        end
        else mg_state_next <= `IDLE;
        out <= 0;
      end
      `SEQD: begin 
        color = (frameCounter > 4) ? s_color : 4'b0000;
        if (seq_over_s == 1) mg_state_next <= `USEI;
        else mg_state_next <= `SEQD;
        out <= 0;
      end
      `USEI: begin 
        p_color_prev = color;
        color = p_color;
        if (seq_over_p == 1) begin // Change state, player completed sequence
          mg_state_next <= (cur_seq_len == `SEQ_LEN) ? `DONE : `SEQD;
          cur_seq_len <= cur_seq_len + `SEQ_ADD;
        end else if (input_data[4]) mg_state_next <= `SEQD; //Let the player ask for the sequence again
        else mg_state_next <= `USEI;

        out <= 0;
        // Check for user input / color change
        if (p_color_prev != p_color && p_color != 4'b0000) begin 
          if (p_color == s_color) begin 
            out <= 1;
            seq_i_p = seq_i_p + 1;
          end
          else seq_i_p = 0;
          if (seq_i_p == cur_seq_len) seq_over_p <= 1;
        end
      end
      `DONE: begin
        color <= 4'b1111;
        mg_state_next <= `DONE;
        out <= 1;
      end
    endcase

    // ---------- FRAME GAME LOGIC ---------- //
    p_color <= input_data[3:0]; // Get User input

    // Second clock generator
    if (frameCounter == 59) frameCounter = 0;
    else frameCounter <= frameCounter + 1;
    second_clk <= (frameCounter < 30);
  end

  always_comb begin 
    // Sequence index MUX
    seq_i = (mg_state == `SEQD) ? seq_i_s : seq_i_p;
  end
  // mem_game_sequence mem_rom (.index(seq_i), .color(s_color));
  mem_sequence_gen mem_gen (.seq(seq_data), .index(seq_i), .color(s_color));
  always_ff @(posedge second_clk or negedge seq_i_rst) begin
    seq_over_s <= 1'b0;
    if (!seq_i_rst) seq_i_s <= 0;
    else if (mg_state != `SEQD);
    else if (seq_i == cur_seq_len-1) seq_over_s <= 1'b1;
    else seq_i_s <= seq_i_s+1; // Increment sequence index when in DISPLAY state
  end

  // ---------- VGA DISPLAY CONTROL ---------- //
  logic [9:0]x;
  logic [9:0]y;
  logic valid;
  vga vga_0 (.clk(vga_clk), .x(x), .y(y), .valid(valid), .HSYNC(vga[2]), .VSYNC(vga[1]));

  mem_visuals vis(.mem_game_state(color), .timer(timer), .valid(valid), .col(x), .row(y), .rgb(vga[8:3]));
  assign vga[0] = 0;
endmodule

module mem_visuals (
  input logic [3:0] mem_game_state,
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
      if (col < 319 && row < 239) begin
        rgb = (mem_game_state[3] == 1'b1) ? 6'b110000 : 6'b010000;
      end
      else if (col > 320 && row < 239) begin
        rgb = (mem_game_state[2] == 1'b1) ? 6'b111100 : 6'b010100;
      end
      else if (col < 319 && row > 240) begin
        rgb = (mem_game_state[1] == 1'b1) ? 6'b001100 : 6'b000100;
      end
      else if (col > 320 && row > 240) begin 
        rgb = (mem_game_state[0] == 1'b1) ? 6'b000011 : 6'b000001;
      end
      else rgb = 6'b0;

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



// ROM
module mem_game_sequence (
  input logic [3:0] index,
  output logic [3:0] color
);
  always_comb begin
    case (index)
      4'd0: color = 4'b1000;
      4'd1: color = 4'b0100;
      4'd2: color = 4'b0010;
      4'd3: color = 4'b0001;
      4'd4: color = 4'b0100;
      4'd5: color = 4'b0010;
      4'd6: color = 4'b1000;
      4'd7: color = 4'b0100;
      4'd8: color = 4'b0010;
      4'd9: color = 4'b0001;
      4'd10: color= 4'b1000;
      4'd11: color= 4'b0010;
      4'd12: color= 4'b1000;
      4'd13: color= 4'b0100;
      4'd14: color= 4'b0010;
      4'd15: color= 4'b0001;
    endcase
  end
endmodule

// Sequence from data string
module mem_sequence_gen (
  input logic [`SEQ_LEN*2-1:0] seq,
  input logic [3:0] index,
  output logic [3:0] color
);
  logic [1:0] step;
  always_comb begin
    step = seq[index*2+1:index*2];
    case (step)
      2'd0: color = 4'b1000;
      2'd1: color = 4'b0100;
      2'd2: color = 4'b0010;
      2'd3: color = 4'b0001;
    endcase
  end
endmodule