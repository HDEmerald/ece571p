module fifo_tb;
parameter DEBUG = 0;
parameter TESTS = 100;
parameter MAXERR = 10;

parameter int DATASIZE = 8;
parameter int FIFOSIZE = 128;
localparam PTRSIZE = $clog2(FIFOSIZE);
localparam CNTSIZE = PTRSIZE+1;

reg clk, rst_n, dinV, doutR;
reg [DATASIZE-1:0] din;
wire dinR, doutV;
wire [CNTSIZE-1:0] cnt;
wire [DATASIZE-1:0] dout;

/*
NOTE: For FIFO between DSP and I2C Interface module, DATASIZE
	 must be 8 and FIFOSIZE must not exceed 128 since we don't
	 want cnt to be wider than 8 bits wide for smooth I2C
	 compatibility.
*/

// DUT
FIFO #(DATASIZE,FIFOSIZE) fifo(clk, rst_n, din, dinV, dinR, doutV, doutR, dout, cnt);

// Golden Device
logic [DATASIZE-1:0] q [$:FIFOSIZE-1];

task WriteFifo(input [DATASIZE-1:0] data);
	din = data;
	dinV = 1;
	repeat (1) @(negedge clk);
	din = 'x;
	dinV = 0;
endtask

task ReadFifo(output [DATASIZE-1:0] data);
	data = dout;
	doutR = 1;
	repeat (1) @(negedge clk);
	doutR = 0;
endtask

task ReadWriteFifo(inout [DATASIZE-1:0] data);
	din = data;
	dinV = 1;
	doutR = 1;
	data = (doutV) ? dout : 'x;
	repeat (1) @(negedge clk);
	din = 'x;
	dinV = 0;
	doutR = 0;
endtask

// Set up monitor
initial
begin
if (DEBUG != 0)
	begin
	$display("Time\t\t\tdin\t{dinV/R}\t{doutV/R}\tdout\tcnt\n");
	$monitor($time, "\t%h\t%2b\t\t%2b\t\t%h\t%0d",
			 din, {dinV,dinR}, {doutV,doutR}, dout, cnt);
	end
end

// Free running clock
initial
begin
clk = 0;
forever #10 clk = ~clk;
end

// Assert rst_n signal for a few clks
initial
begin
rst_n = 0;
repeat (3) @(negedge clk);
rst_n = 1;
end

logic [DATASIZE-1:0] tempFData;
logic [DATASIZE-1:0] tempQData;
int numerr = 0;

// Generate stimulus
initial
begin
din = '0;
dinV = 0;
doutR = 0;
repeat (5) @(negedge clk);

// Targeted Tests
q = {};

if (q.size() !== cnt)
	begin
	$display("*** ERROR: FIFO.cnt = %0d (Expctd %0d) t=%t", 
			 cnt, q.size(), $time);
	numerr += 1;
	end

ReadFifo(tempFData);
tempQData = q.pop_front();
if (q.size() !== cnt)
	begin
	$display("*** ERROR: FIFO.cnt = %0d (Expctd %0d) t=%t", 
			 cnt, q.size(), $time);
	numerr += 1;
	end

tempFData = $urandom();
tempQData = tempFData;
WriteFifo(tempFData);
q.push_back(tempQData);
if (q.size() !== cnt)
	begin
	$display("*** ERROR: FIFO.cnt = %0d (Expctd %0d) t=%t", 
			 cnt, q.size(), $time);
	numerr += 1;
	end
tempFData = $urandom();
tempQData = tempFData;
ReadWriteFifo(tempFData);
q.push_back(tempQData);
tempQData = q.pop_front();
if (q.size() !== cnt)
	begin
	$display("*** ERROR: FIFO.cnt = %0d (Expctd %0d) t=%t", 
			 cnt, q.size(), $time);
	numerr += 1;
	end
else if (tempFData !== tempQData)
	begin
	$display("*** ERROR: FIFO.read = %h, Queue.read = %h t=%t", 
			 tempFData, tempQData, $time);
	numerr += 1;
	end
ReadFifo(tempFData);
tempQData = q.pop_front();
if (q.size() !== cnt)
	begin
	$display("*** ERROR: FIFO.cnt = %0d (Expctd %0d) t=%t", 
			 cnt, q.size(), $time);
	numerr += 1;
	end
else if (tempFData !== tempQData)
	begin
	$display("*** ERROR: FIFO.read = %h, Queue.read = %h t=%t", 
			 tempFData, tempQData, $time);
	numerr += 1;
	end

for (int i = 0; i < FIFOSIZE+1; i++)
	begin
	tempFData = $urandom();
	tempQData = tempFData;
	WriteFifo(tempFData);
	q.push_back(tempQData);
	if (q.size() !== cnt)
		begin
		$display("*** ERROR: FIFO.cnt = %0d (Expctd %0d) t=%t", 
			 	 cnt, q.size(), $time);
		numerr += 1;
		end
	end

for (int i = 0; i < FIFOSIZE; i++)
	begin
	ReadFifo(tempFData);
	tempQData = q.pop_front();
	if (q.size() !== cnt)
		begin
		$display("*** ERROR: FIFO.cnt = %0d (Expctd %0d) t=%t", 
			 	 cnt, q.size(), $time);
		numerr += 1;
		end
	else if (tempFData !== tempQData)
		begin
		$display("*** ERROR: FIFO.read = %h, Queue.read = %h t=%t", 
				 tempFData, tempQData, $time);
		numerr += 1;
		end
	end

repeat (2) @(negedge clk);
$finish;

end

endmodule