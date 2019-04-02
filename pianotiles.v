module pianotiles(
		CLOCK_50,
		KEY,
		VGA_CLK,
		VGA_HS,
		VGA_VS,
		VGA_BLANK_N,
		VGA_SYNC_N,
		VGA_R,
		VGA_G,
		VGA_B, 
		HEX0, 
		HEX1,
		LEDR, 
		SW
		);

	input 			CLOCK_50;		// 50 MHz Clock
	input 	[3:0] KEY;				// Input Keys
	input 	[3:0] SW;
	
	output			VGA_CLK;   		//	VGA Clock
	output			VGA_HS;			//	VGA H_SYNC
	output			VGA_VS;			//	VGA V_SYNC
	output			VGA_BLANK_N;	//	VGA BLANK
	output			VGA_SYNC_N;		//	VGA SYNC
	output	[9:0]	VGA_R;   		//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 		//	VGA Green[9:0]
	output	[9:0]	VGA_B;   		//	VGA Blue[9:0]
	
	output [6:0] HEX0;
	output [6:0] HEX1;
	output [17:0] LEDR;
	
	/* The state of the game.
		0 - Landing Page
		1 - In-game
		2 - End Credits
	*/
	
	reg [1:0] game_state;
	initial game_state <= 2'd0;
	
	assign LEDR[1:0] = game_state[1:0];
	assign LEDR[17:14] = KEY[3:0];
	
	assign LEDR[5:4] = game_state[1:0];
	
	// This generates a random number between 0-3 to select which column to play on.
	
	wire [1:0] random_column;
	random rng(CLOCK_50, negative, random_column[1:0]);
	
	// We never want to reset the screen. Thus, this will always be posedge.
	
	wire reset_screen = 1'b1;
	
	// We only want to draw on the screen when the game state is not at the landing page.
	
	wire draw_screen;
	assign draw_screen = game_state == 2'd1;
		
	// The current x and y being written to.
	
	wire [31:0] draw_x;
	wire [31:0] draw_y;
	
	// The maximum x and y of the panel (320 x 240).
	
	localparam [31:0] max_x = 32'd320;
	localparam [31:0] max_y = 32'd240;

	// Wires that specify the condition of any of the 4 columns.
	reg [255:0] col_a; // We only use bits 239 -> 0, but we must declare 255 to use a while loop below.
	reg [255:0] col_b;
	reg [255:0] col_c;
	reg [255:0] col_d;

	// Specify the color of the pixel that should be drawn at (x, y).
	
	wire [2:0] color;
	
   vga_player VGA_PLAYER(
		.clock(CLOCK_50),
		.reg_x(draw_x),
		.reg_y(draw_y),
		.max_x(max_x),
		.max_y(max_y),
		.color(color),
		.col_a(col_a),
		.col_b(col_b),
		.col_c(col_c),
		.col_d(col_d));
	
	// This handles the rate divided clock.
	
	wire rate_clock;
	localparam MAX_RATE = 32'd250000;
	
	rate_divider rd(
		.clock(CLOCK_50),
		.max_rate(MAX_RATE),
		.rate_switch(rate_clock));
	
	// Parameter that specifies the size of a tile (in pixels).
	
	localparam [31:0] tile_size = 32'd50;
	
	// This the current column we are drawing to.
	
	reg [1:0] current_col;
	initial current_col = random_column;
	
	// This is the amount of pixels that we've left to draw.
	
	reg [31:0] current_count;
	initial current_count = tile_size;
	
	// When a tile touches the ground, this is the amount of time the user has left.
	
	reg [1:0] alert_col;
	reg [31:0] alert_time_left;
	
	initial begin
		alert_time_left = 32'd1024;
		alert_col = 1'd0;
	end
	
	// Scores
	
	reg [7:0] game_score;
	initial game_score = 0;
	
	hex_decoder hd1(game_score[7:4], HEX1[6:0]);
	hex_decoder hd0(game_score[3:0], HEX0[6:0]);
	
	// Used in for loops.
	
	reg [31:0] i_sub;
	reg [7:0] i_start;
	reg [31:0] i;
	
	// Handles the rate clock / game logic.
	
	always @(posedge rate_clock)
	begin		
		if (game_state == 2'd0 || game_state == 2'd2) begin // At Landing Page or End Credits
			if(~KEY[0] || ~KEY[1] || ~KEY[2] || ~KEY[3]) begin // If any key is being pressed.
				col_a = 0;
				col_b = 0;
				col_c = 0;
				col_d = 0;
				current_count = tile_size;
				current_col = random_column;
				game_score = 8'd0;
				alert_time_left = 1024;
				alert_col = 2'd0;
				game_state <= 2'd1;
			end
		end else if (game_state == 2'd1) begin // Inside an active game.
			if(current_count <= 0) begin // this will happen every time a new tile starts
				current_count = tile_size; // If current count reaches 0 reset the counter back to tiles height
				current_col[1:0] = random_column[1:0]; // store a new random column from 0 to 3, next tile will be on this new column
			end else begin
				current_count = current_count - 1; // decrease counter
			end
			
			// for each column reg, shift down 1 bit
			case(current_col[1:0]) // the last bit of the corresponding column reg will be set to one
				2'd0: begin
					col_a[0] = 1;
					col_a = col_a << 1;
					col_b = col_b << 1;
					col_c = col_c << 1;
					col_d = col_d << 1;
				end
				
				2'd1: begin
					col_b[0] = 1;
					col_a = col_a << 1;
					col_b = col_b << 1;
					col_c = col_c << 1;
					col_d = col_d << 1;
				end
				
				2'd2: begin
					col_c[0] = 1;
					col_a = col_a << 1;
					col_b = col_b << 1;
					col_c = col_c << 1;
					col_d = col_d << 1;
				end
				
				default: begin
					col_d[0] = 1;
					col_a = col_a << 1;
					col_b = col_b << 1;
					col_c = col_c << 1;
					col_d = col_d << 1;
				end
			endcase
			
			// alert_time_left counts the remaining time before the lowest tile exits the screen
			// if alert_time_left is default, start counting when the first tile reaches the ground
			if(alert_time_left == 31'd1024) begin // sets the corresponding alert_col to 1
				if(col_a[239] == 1) begin
					alert_time_left = tile_size;
					alert_col = 1'd0;
				end else if(col_b[239] == 1) begin
					alert_time_left = tile_size;
					alert_col = 2'd1;
				end else if(col_c[239] == 1) begin
					alert_time_left = tile_size;
					alert_col = 2'd2;
				end else if(col_d[239] == 1) begin
					alert_time_left = tile_size;
					alert_col = 2'd3;
				end
			end else if (alert_time_left > 0) begin // if alertime_already started and is not 0 yet
				alert_time_left = alert_time_left - 1;
				/*
				if what the user pressed matches the current lowest tile
				remove the current lowest tile(setting the remaining 1s to 0s) from the corresponding col reg
				the remaining height of the lowest tile is determined by alert_time_left
				at last add score and rest slaert_time _left back to default to wait for the next tile.
				*/
				if(alert_col[1:0] == 2'd0 && ~KEY[3] && KEY[2] && KEY[1] && KEY[0]) begin
					alert_time_left = alert_time_left + 1;
					
					for(i = 0; i < tile_size; i = i + 1) begin
						if (alert_time_left > 0) begin
							i_sub = 239 - i;
							i_start[7:0] = i_sub[7:0];
							col_a[i_start] = 0;
							alert_time_left = alert_time_left - 1;
						end
					end
							
					game_score = game_score + 1;
					alert_time_left = 1024;
					
					if(col_b[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd1;
					end else if(col_c[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd2;
					end else if(col_d[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd3;
					end
				end else if(alert_col[1:0] == 2'd1 && KEY[3] && ~KEY[2] && KEY[1] && KEY[0]) begin
					alert_time_left = alert_time_left + 1;
					
					for(i = 0; i < tile_size; i = i + 1) begin
						if (alert_time_left > 0) begin
							i_sub = 239 - i;
							i_start[7:0] = i_sub[7:0];
							col_b[i_start] = 0;
							alert_time_left = alert_time_left - 1;
						end
					end
							
					game_score = game_score + 1;
					alert_time_left = 1024;
					
					if(col_a[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 1'd0;
					end else if(col_c[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd2;
					end else if(col_d[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd3;
					end
				end else if(alert_col[1:0] == 2'd2 && KEY[3] && KEY[2] && ~KEY[1] && KEY[0]) begin
					alert_time_left = alert_time_left + 1;
					
					for(i = 0; i < tile_size; i = i + 1) begin
						if (alert_time_left > 0) begin
							i_sub = 239 - i;
							i_start[7:0] = i_sub[7:0];
							col_c[i_start] = 0;
							alert_time_left = alert_time_left - 1;
						end
					end
							
					game_score = game_score + 1;
					alert_time_left = 1024;
					
					if(col_a[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 1'd0;
					end else if(col_b[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd1;
					end else if(col_d[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd3;
					end
				end else if(alert_col[1:0] == 2'd3 && KEY[3] && KEY[2] && KEY[1] && ~KEY[0]) begin
					alert_time_left = alert_time_left + 1;
					
					for(i = 0; i < tile_size; i = i + 1) begin
						if (alert_time_left > 0) begin
							i_sub = 239 - i;
							i_start[7:0] = i_sub[7:0];
							col_d[i_start] = 0;
							alert_time_left = alert_time_left - 1;
						end
					end
							
					game_score = game_score + 1;
					alert_time_left = 1024;
					
					if(col_a[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 1'd0;
					end else if(col_b[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd1;
					end else if(col_c[239] == 1) begin
						alert_time_left = tile_size;
						alert_col = 2'd2;
					end
				end
			end else begin // if the user did not press the correct key, go to end credit
				game_state <= 2'd2;
			end
		end
	end
		
	vga_adapter VGA(
		.resetn(reset_screen),
		.clock(CLOCK_50),
		.colour(color),
		.x(draw_x),
		.y(draw_y),
		.plot(draw_screen),
		.VGA_R(VGA_R),
		.VGA_G(VGA_G),
		.VGA_B(VGA_B),
		.VGA_HS(VGA_HS),
		.VGA_VS(VGA_VS),
		.VGA_BLANK(VGA_BLANK_N),
		.VGA_SYNC(VGA_SYNC_N),
		.VGA_CLK(VGA_CLK));
			
		defparam VGA.RESOLUTION = "320x240"; // 320x240=76800px, 160x120=19200px
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "piano.mif";
	
endmodule

module vga_player(clock, reg_x, reg_y, max_x, max_y, color, col_a, col_b, col_c, col_d);
	input clock;
	
	input [31:0] max_x;
	input [31:0] max_y;
	
	output reg [2:0] color;
	
	output reg [31:0] reg_x;
	output reg [31:0] reg_y;
	
	input [255:0] col_a;	
	input [255:0] col_b;
	input [255:0] col_c;
	input [255:0] col_d;
	
	reg [255:0] draw_col;
	reg [2:0] draw_color;
	
	always @(posedge clock) begin	
		// go back to the first coordinate when the end of the screen is reached	
		if(reg_x >= max_x) begin
			reg_x = 0;
			
			if(reg_y >= max_y)
				reg_y = 0;
			else
				reg_y = reg_y + 1;
		end else	begin
			reg_x = reg_x + 1;
		end
		// switch to the next column reg for each 80 pixels on the x axis		
		if(reg_x < 80) begin
			draw_color = 3'b001;
			draw_col = col_a;
		end else if(reg_x < 160) begin
			draw_color = 3'b010;
			draw_col = col_b;
		end else if(reg_x < 240) begin
			draw_color = 3'b011;
			draw_col = col_c;
		end else if(reg_x < 320) begin
			draw_color = 3'b100;
			draw_col = col_d;
		end else begin
			draw_color = 3'b001;
			draw_col = col_a;
		end
			
		// if the value in the col reg is 1 set the colour to the tile's colour
		if (draw_col[reg_y] == 1)
			color = draw_color;
		else // else it will be white
			color = 3'b111;
	end
endmodule

/*
	random(clk, reset, num)
	
	clk / 1 bit - The clock to trigger generating a new cycle upon every posedge.
	reset / 1 bit - Ensures that the next generate number is ground.
	num / 2 bit - Generates a number to this registry.
*/
module random(clk, reset, num);
	input clk;
	input reset;
	
	output reg [1:0] num;
	// a pseudo random number generator using two Linear Feedback Shift Register
	reg [8:0] n0, n1; // the shift register
   wire f0, f1; // the feedback that is the xor between 2 bits in the shift register
	
	assign f0 = n0[3] ^ n0[8];
	assign f1 = n1[5] ^ n1[0];
	
   always @(posedge clk or posedge reset)
   begin
		if (reset == 1'd1) begin // result will always be 0 when reset is set to high
			n0[8:0] = 9'd0;
			n1[8:0] = 9'd0;
		end else if (reset == 1'd0 && n0 == 9'd0 && n1 == 9'd0) begin // add 1 into the shift register when rng is starting
			n0[8:0] = 9'd1;
			n1[8:0] = 9'd1;
		end else begin // shift the register and attach the feedback to the end
			n0[8:0] = {n0[7:0],f0};
			n1[8:0] = {n1[7:0],f1};
		end
		
		num[1:0] = {n0[0], n1[0]}; // combine first bit of both shift register to get the random number
   end
endmodule

/*
	rate_divider(clock, max_rate, rate_switch)
	
	clock / 1 bit - The main clock to track on every posedge cycle
	max_rate / 32 bit - A variable tracking the maximum cycle of this divider
	rate_switch / 1 bit - The output to cycle {0, 1} after every 'max_rate' 'clock' cycles have elapsed.
*/
module rate_divider(clock, max_rate, rate_switch);
	input clock;
	input [31:0] max_rate;
	
	output reg rate_switch;
	
	reg [31:0] current_rate;
	initial current_rate = 0;
	
	always @(posedge clock)
	begin
		current_rate = current_rate + 1;
		if(current_rate >= max_rate)// if the max rate is reached reset the rate counter and toggle the rate_switch
		begin
			current_rate = 0;
			if(rate_switch == 1'b1)
				rate_switch = 1'b0;
			else
				rate_switch = 1'b1;
		end
	end
endmodule

/*	
	hex_decoder(hex_digit, segments)

	hex_digit / 4 bit - 0 to 15 value to read hexidecimal from
	segments / 7 bit - 0 to E to output selection value to
*/
module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule
