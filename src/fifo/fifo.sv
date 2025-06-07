module FIFO (clk, rst_n, din, dinV, dinR, doutV, doutR, dout, cnt);
parameter int DATASIZE = 8;						// # of bits per FIFO entry
parameter int FIFOSIZE = 128;					// # of FIFO entries
localparam PTRSIZE = $clog2(FIFOSIZE); 			// # of bits for each pointer head (write and read)
localparam CNTSIZE = PTRSIZE+1;					// # of bits for FIFO entry count

/*
NOTE: For FIFO between DSP and I2C Interface module, DATASIZE
	 must be 8 and FIFOSIZE must not exceed 128 since we don't
	 want cnt to be wider than 8 bits wide for smooth I2C
	 compatibility.
*/

if ((DATASIZE < 1) || (type(DATASIZE) != type(int)))
	$fatal("DATASIZE of module FIFO must be an integer greater than 0!");
if ((FIFOSIZE < 2) || (type(FIFOSIZE) != type(int)))
	$fatal("FIFOSIZE of module FIFO must be an integer greater than 1!");

/*
*** PIN DESCRIPTIONS ***
clk: 	External driving clock
rst_n:	Reset signal
din:	Data from DSP unit
dinV:	din is valid
dinR:	FIFO ready to receive din on clk
doutV:	dout is valid
doutR:	I2C ready to receive dout on clk
dout:	Data going to I2C module
cnt:	# of FIFO entries ready to be read by I2C
*/

input clk, rst_n, dinV, doutR;
input [DATASIZE-1:0] din;
output dinR, doutV;
output reg [CNTSIZE-1:0] cnt;
output [DATASIZE-1:0] dout;

logic [DATASIZE-1:0] FIFO [FIFOSIZE-1:0];
logic [PTRSIZE-1:0] ReadPtr;
logic [PTRSIZE-1:0] WritePtr;

assign dinR = (cnt != FIFOSIZE);
assign doutV = (cnt != 0);
assign dout = FIFO[ReadPtr];

always_ff @(posedge clk or negedge rst_n)
begin
if (!rst_n)
	begin
	cnt <= '0;
	ReadPtr <= '0;
	WritePtr <= '0;
	end
else
	begin
	cnt <= cnt;
	FIFO[WritePtr] <= FIFO[WritePtr];
	ReadPtr <= ReadPtr;
	WritePtr <= WritePtr;
	if ((dinR && dinV) && (doutR && doutV))						// Read and Write FIFO
		begin
		cnt <= cnt;
		FIFO[WritePtr] <= din;
		ReadPtr <= (ReadPtr == FIFOSIZE-1) ? '0 : ReadPtr + 1;
		WritePtr <= (WritePtr == FIFOSIZE-1) ? '0 : WritePtr + 1;
		end
	else if (dinR && dinV)										// Write to FIFO
		begin
		cnt <= cnt + 1;
		FIFO[WritePtr] <= din;
		WritePtr <= (WritePtr == FIFOSIZE-1) ? '0 : WritePtr + 1;
		end
	else if (doutR && doutV)									// Read from FIFO
		begin
		cnt <= cnt - 1;
		ReadPtr <= (ReadPtr == FIFOSIZE-1) ? '0 : ReadPtr + 1;
		end
	end
end

endmodule