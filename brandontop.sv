module weight_game(
    input logic enabled,
    input logic [8:0] timer,
    input logic [2:0] inA,
    input logic [2:0] inB,
    input logic [17:0] randomNums,
    input logic vga_clk,
    input logic frame_clk,

    output logic [8:0] vga,
    output logic out

    );

    logic rst;
    // places and outputs

    // assign desiredNum = 10'b1111100111;//randomNums[24:15]; 
    logic [3:0] hunsPlace;
    logic [9:0] hunsOutput;
    logic [3:0] tensPlace;
    logic [9:0] tensOutput;
    logic [3:0] onesPlace;
    logic [9:0] onesOutput;
    // outputs
    logic [25:0] counter;
    logic [5:0] output2;
    logic [5:0] output1;
    logic [5:0] output0;

    logic [9:0]number, an_x, an_y, lin_x, lin_y;

    logic clk;
    SB_HFOSC # (
                    .CLKHF_DIV("0b00")
        ) osc (
            .CLKHFPU(1'b1), // Power up
            .CLKHFEN(1'b1), // Enable
            .CLKHF(clk),   // Clock output
            .TRIM0(1'b0), .TRIM1(1'b0), .TRIM2(1'b0), .TRIM3(1'b0), .TRIM4(1'b0),
            .TRIM5(1'b0), .TRIM6(1'b0), .TRIM7(1'b0), .TRIM8(1'b0), .TRIM9(1'b0)
        );

    counter real_counter(
        .clk({clk}),
        .counter({counter})
    );

    // register rstRegister(
    //     .clk({clk}),
    //     .in({button}),
    //     .out({rst})
    // );

    encoder encoder0(
        .a({inA[0]}),
        .b({inB[0]}),
        .clk({clk}),
        .rst({rst}),
        .number({output0})
    );
    encoder encoder1(
        .a({inA[1]}),
        .b({inB[1]}),
        .clk({clk}),
        .rst({rst}),
        .number({output1})
    );
    encoder encoder2(
        .a({inA[2]}),
        .b({inB[2]}),
        .clk({clk}),
        .rst({rst}),
        .number({output2})
    );

    always_comb begin
        case (output2[3:0])
            4'b0000: hunsOutput = 10'b0000000000; //000
            4'b0001: hunsOutput = 10'b0001100100; //100
            4'b0010: hunsOutput = 10'b0011001000; //200
            4'b0011: hunsOutput = 10'b0100101100; //300
            4'b0100: hunsOutput = 10'b0110010000; //400
            4'b0101: hunsOutput = 10'b0111110100; //500
            4'b0110: hunsOutput = 10'b0000000000; //600
            4'b0111: hunsOutput = 10'b0000000000; //700
            4'b1001: hunsOutput = 10'b1100100000; //800
            4'b1010: hunsOutput = 10'b1110000100;//900
            default: hunsOutput = 10'b0000000000; // Handle unknown select values
        endcase

        case (output1[3:0])
            4'b0000: tensOutput = 10'b0000000000; //00
            4'b0001: tensOutput = 10'b0000001010; //10
            4'b0010: tensOutput = 10'b0000010100; //20
            4'b0011: tensOutput = 10'b0000011110; //30
            4'b0100: tensOutput = 10'b0000101000; //40
            4'b0101: tensOutput = 10'b0000110010; //50
            4'b0110: tensOutput = 10'b0000111100; // 60
            4'b0111: tensOutput = 10'b0001000110; //70
            4'b1000: tensOutput = 10'b0001010000; //80
            4'b1001: tensOutput = 10'b0001011010; //90
            default: tensOutput = 10'b0000000000;
        endcase

        case (output0[3:0])
            4'b0000: onesOutput = 10'b0000000000; //0
            4'b0001: onesOutput = 10'b0000000001; //1
            4'b0010: onesOutput = 10'b0000000010; //2
            4'b0011: onesOutput = 10'b0000000011; //3
            4'b0100: onesOutput = 10'b0000000100; //4
            4'b0101: onesOutput = 10'b0000000101; //5
            4'b0110: onesOutput = 10'b0000000110; // 6
            4'b0111: onesOutput = 10'b0000000111; //7
            4'b1000: onesOutput = 10'b0000001000; //8
            4'b1001: onesOutput = 10'b0000001001; //9
            default: onesOutput = 10'b0000000000;
        endcase
        out = (an_x == lin_x && an_y+10 == lin_y);
    end

    always_ff @(posedge frame_clk) begin
        if (enabled) begin
            an_x = output1*10;
            an_y = output0*10;
        end else begin
            an_x = 0;
            an_y = 0;
        end
        lin_x = (((output2*5457 % 64)*3793) % 64) * 10;
        lin_y = (((output2*37+24 % 64)*7571) % 42) * 10;
    end

    // ----- VGA OUTPUT ----- //
    logic [9:0]x;
    logic [9:0]y;
    logic valid;
    vga vga_0 (.clk(vga_clk), .x(x), .y(y), .valid(valid), .HSYNC(vga[2]), .VSYNC(vga[1]));

    weight_visuals vis(.timer(timer), .num_x(an_x), .num_y(an_y), .lin_x(lin_x), .lin_y(lin_y), .valid(valid), .col(x), .row(y), .rgb(vga[8:3]));
    assign vga[0] = 0;
endmodule

module weight_visuals (
    input logic [8:0] timer,
    input logic [9:0] num_x,
    input logic [9:0] num_y,
    input logic [9:0] lin_x,
    input logic [9:0] lin_y,
    input logic valid,
    input logic [9:0] col,
    input logic [9:0] row,
    output logic [5:0] rgb
);
    logic [95:0] sprite_data;
    logic [47:0] text_data;
    logic [5:0] sprite_color, text_color;
    logic [5:0] index;
    logic [3:0] sprite_x, sprite_y;
    sprite_weight weight (.addr(sprite_y[3:0]), .data(sprite_data));
    sprite_rom_8 text (.index(index), .addr(sprite_y[2:0]), .data(text_data));
    logic [9:0] weight_x = 320, weight_y = 240;
    logic [9:0] weight_x_min, weight_y_min;
    localparam int weight_scale = 5;
    localparam int weight_size = 16 * weight_scale;
    localparam int weight_halfsize = weight_size/2;

    always_comb begin
        weight_x = num_x;
        weight_y = num_y;
        weight_x_min = ((weight_x - weight_halfsize) < 0) ? 0 : weight_x - weight_halfsize;
        weight_y_min = ((weight_y - weight_halfsize) < 0) ? 0 : weight_y - weight_halfsize;

        sprite_color = sprite_data[sprite_x*6+5:sprite_x*6];
        text_color = text_data[sprite_x*6+5:sprite_x*6];

        index = 0;
        sprite_x = 0;
        sprite_y = 0;
        if (valid) begin
            if (col == lin_x || row == lin_y) rgb = 6'b111000;
            else rgb = 6'b111111;

            // Draw weight
            if (row >= weight_y_min && col >= weight_x_min
            && row < weight_y + weight_size - weight_halfsize && col < weight_x + weight_size - weight_halfsize) begin
                sprite_y = (row - weight_y + weight_halfsize)/weight_scale;
                sprite_x = 15 - (col - weight_x + weight_halfsize)/weight_scale;
                if (sprite_color != 6'b111111) rgb = sprite_color;
            end 


            // Timer
            if (col >= 640 - 32 && row < 32) begin
                index = 26 + (timer % 10);
                sprite_x = 15-(col - (640 - 32))/4;
                sprite_y = row/4;
                rgb = (text_color == 6'b111111) ? 6'b110000 : 6'b000000;
            end
            else if (col >= 640 - 64 && row < 32) begin
                index = 26 + ((timer/10) % 10);
                sprite_x = 15-(col - (640 - 32))/4;
                sprite_y = row/4;
                rgb = (text_color == 6'b111111) ? 6'b110000 : 6'b000000;
            end
            else if (col >= 640 - 98 && row < 32) begin
                index = 26 + ((timer/100) % 10);
                sprite_x = 15-(col - (640 - 32))/4;
                sprite_y = row/4;
                rgb = (text_color == 6'b111111) ? 6'b110000 : 6'b000000;
            end
        end else rgb = 6'b000000;
    end

endmodule