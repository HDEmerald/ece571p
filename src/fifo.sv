module FIFO (clk, reset, din, dinV, dinR, doutV, doutR, dout, cnt);
parameter DATASIZE = 8;						// # of bits per FIFO entry
parameter FIFOSIZE = 128;					// # of FIFO entries
localparam HEADSIZE = $clog2(FIFOSIZE); 	// # of bits for each pointer head (write and read)
localparam CNTSIZE = HEADSIZE+1;			// # of bits for FIFO entry count

/*
NOTE: For FIFO between DSP and I2C Interface module, DATASIZE
	 must be 8 and FIFOSIZE must not exceed 128 since we don't
	 want cnt to be wider than 8 bits wide for smooth I2C
	 compatibility.
*/

if ((DATASIZE < 1) || (type(DATASIZE) != type(int)))
	$fatal("DATASIZE must be an integer greater than 0!");
if ((FIFOSIZE < 2) || (type(FIFOSIZE) != type(int)))
	$fatal("FIFOSIZE must be an integer greater than 1!");

/*
*** PIN DESCRIPTIONS ***
clk: 	External driving clock
reset:	Reset signal
din:	Data from DSP unit
dinV:	din is valid
dinR:	FIFO ready to receive din on clk
doutV:	dout is valid
doutR:	I2C ready to receive dout on clk
dout:	Data going to I2C module
cnt:	# of FIFO entries ready to be read by I2C
*/

input clk, reset, dinV, dinR, doutV, doutR;
input [DATASIZE-1:0] din;
output [CNTSIZE-1:0] cnt;
output [DATASIZE-1:0] dout;

logic [DATASIZE-1:0][FIFOSIZE-1:0] FIFO;
logic [HEADSIZE-1:0] ReadHead;
logic [HEADSIZE-1:0] WriteHead;

endmodule