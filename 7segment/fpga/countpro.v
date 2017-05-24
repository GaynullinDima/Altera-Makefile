`timescale 1ns / 1ps

module countpro(
    output VGA_RED,
    output VGA_GREEN,
    output VGA_BLUE,
    output VGA_HSYNC,
    output VGA_VSYNC,
	 output [3:0] leds,
	 input  [3:0] btns,
	 input  CLK_50MHZ
    );

// My development board had a 50MHz clock.
// The original code was for a board with a 25MHz clock.
// This section divides CLK_50MHZ by 2 and outputs clk.
reg clk;
always @(posedge CLK_50MHZ)
clk <= ~clk;

wire inDisplayArea;
wire [9:0] CounterX;
wire [8:0] CounterY;

VidSync_Gen syncgen(.clk(clk), .VGA_HSYNC(VGA_HSYNC), .VGA_VSYNC(VGA_VSYNC), 
  .inDisplayArea(inDisplayArea), .CounterX(CounterX), .CounterY(CounterY));

/////////////////////////////////////////////////////////////////
reg [9:0] PaddlePosition, AutoPaddlePosition;

always @(posedge clk)
if(btns[0] ^ btns[1])
begin
	if(btns[0])
	begin
		if(~&PaddlePosition)        // make sure the value doesn't overflow
			PaddlePosition <= PaddlePosition + 1;
	end
	else
	begin
		if(|PaddlePosition)        // make sure the value doesn't underflow
			PaddlePosition <= PaddlePosition - 1;
	end
end

/////////////////////////////////////////////////////////////////
reg [9:0] ballX;
reg [8:0] ballY;
reg ball_inX, ball_inY;

always @(posedge clk)
if(ball_inX==0) ball_inX <= (CounterX==ballX) & ball_inY; else ball_inX <= !(CounterX==ballX+16);

always @(posedge clk)
if(ball_inY==0) ball_inY <= (CounterY==ballY); else ball_inY <= !(CounterY==ballY+16);

wire ball = ball_inX & ball_inY;

/////////////////////////////////////////////////////////////////
// These sections were modified by GS to A) better fit my screen and B) provide automatic paddle control.
// Draw a border around the screen                //79
wire border = (CounterX[9:3]==0) || (CounterX[9:3]==72) || (CounterY[8:3]==0) || (CounterY[8:3]==59);
wire manualpaddle = (CounterX>=PaddlePosition+8) && (CounterX<=PaddlePosition+120) && (CounterY[8:4]==27);
wire autopaddle = (CounterX>=(AutoPaddlePosition-60)+8) && (CounterX<=(AutoPaddlePosition-60)+120) && (CounterY[8:4]==27);
wire paddle = (0 ? (autopaddle) : manualpaddle); // select based on SW_0
wire BouncingObject = border | paddle; // active if the border or paddle is redrawing itself

reg ball_dirX, ball_dirY;
reg ResetCollision;
always @(posedge clk) ResetCollision <= (CounterY==500) & (CounterX==0);  // active only once for every video frame

reg CollisionX1, CollisionX2, CollisionY1, CollisionY2;
always @(posedge clk) if(ResetCollision) CollisionX1<=0; else if(BouncingObject & (CounterX==ballX   ) & (CounterY==ballY+ 8)) CollisionX1<=1;
always @(posedge clk) if(ResetCollision) CollisionX2<=0; else if(BouncingObject & (CounterX==ballX+16) & (CounterY==ballY+ 8)) CollisionX2<=1;
always @(posedge clk) if(ResetCollision) CollisionY1<=0; else if(BouncingObject & (CounterX==ballX+ 8) & (CounterY==ballY   )) CollisionY1<=1;
always @(posedge clk) if(ResetCollision) CollisionY2<=0; else if(BouncingObject & (CounterX==ballX+ 8) & (CounterY==ballY+16)) CollisionY2<=1;

// Output assigns for LEDs
assign leds[0] = CollisionX1;
assign leds[1] = CollisionX2;
assign leds[2] = btns[0];
assign leds[3] = btns[1];


/////////////////////////////////////////////////////////////////
wire UpdateBallPosition = ResetCollision;  // update the ball position at the same time that we reset the collision detectors

always @(posedge clk)
if(UpdateBallPosition) // only update ball if SW_3 allows.
begin
	if(~(CollisionX1 & CollisionX2))        // if collision on both X-sides, don't move in the X direction
	begin
		ballX <= ballX + (ball_dirX ? (-3 ) : (3));  // Speed set by SW_1
		if(CollisionX2) ball_dirX <= 1; else if(CollisionX1) ball_dirX <= 0;
	end

	if(~(CollisionY1 & CollisionY2))        // if collision on both Y-sides, don't move in the Y direction
	begin
		ballY <= ballY + (ball_dirY ? (-3 ) : (3)); // Speed set by SW_1
		if(CollisionY2) ball_dirY <= 1; else if(CollisionY1) ball_dirY <= 0;
	end
	
	AutoPaddlePosition <= ((ballX<=60) ? 60 : (ballX>=520) ? 520 : ballX);  // Don't let autopaddle drive off screen edge!
end 

/////////////////////////////////////////////////////////////////

// Set colour scheme based on SW_2
wire R = ((~btns[3] & (border | paddle | ball)) | (btns[3] & (border | paddle)));
wire G = ((~btns[3] & (border | paddle | ball)) | (btns[3] & (border)));
wire B = ((~btns[3] & (border | paddle | ball)) | (btns[3] & (ball)));

reg VGA_R, VGA_G, VGA_B;

assign VGA_RED   = VGA_R;
assign VGA_GREEN = VGA_G;
assign VGA_BLUE  = VGA_B;

always @(posedge clk)
begin
  VGA_R <= R & inDisplayArea;
  VGA_G <= G & inDisplayArea;
  VGA_B <= B & inDisplayArea;
end

endmodule

module VidSync_Gen(clk, VGA_HSYNC, VGA_VSYNC, inDisplayArea, CounterX, CounterY);
input clk;
output VGA_HSYNC, VGA_VSYNC;
output inDisplayArea;
output [9:0] CounterX;
output [8:0] CounterY;

//////////////////////////////////////////////////
reg [9:0] CounterX;
reg [8:0] CounterY;
wire CounterXmaxed = (CounterX==10'h2FF);

always @(posedge clk)
if(CounterXmaxed)
	CounterX <= 0;
else
	CounterX <= CounterX + 1;

always @(posedge clk)
if(CounterXmaxed) CounterY <= CounterY + 1;

reg	vga_HS, vga_VS;
always @(posedge clk)
begin
	vga_HS <= (CounterX[9:4]==6'h28); // change this value to move the display horizontally (WAS 2D)
	vga_VS <= (CounterY==479); // change this value to move the display vertically (WAS 500)
end

reg inDisplayArea;
always @(posedge clk)
if(inDisplayArea==0)
	inDisplayArea <= (CounterXmaxed) && (CounterY<480);
else
	inDisplayArea <= !(CounterX==639);
	
assign VGA_HSYNC = ~vga_HS;
assign VGA_VSYNC = ~vga_VS;

endmodule
