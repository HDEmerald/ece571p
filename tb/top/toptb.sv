interface i2c_if;
  wand scl;
  wand sda;

  modport slave (
    input scl,
    inout sda
  );
endinterface

module top_tb;
/* @@@ Parameters @@@ */
/* ADC FIFO Parameters */
parameter int		ADC_DATA_WIDTH = 12;
parameter int		ADC_FIFO_DEPTH = 512;
/* BFSK Demod. Parameters */
parameter int		ACC_WIDTH = 28;
parameter real		SAMPLE_RATE = 48000.0;
parameter real		BAUD = 45.0;
parameter real		F0 = 2995.0;
parameter real		F1 = 2125.0;
/* I2C FIFO Parameters */
// none
/* I2C Interface Module Parameters */
parameter bit [6:0]	I2C_ADDR = 'h42;
/* Waveform Generator Parameters */
localparam real AMPLITUDE = 0.5;
localparam real NOISE = 0.0;
localparam int DATA_WIDTH = 8;
localparam int BYTE_COUNT = 16; 
localparam int SYMBOL_COUNT = BYTE_COUNT * DATA_WIDTH;
/* Testbench Parameters */
parameter MONITOR = 0;
parameter CLOCK_RATIO = 64;
localparam CLOCK_PULSE = CLOCK_RATIO / 2;
localparam DISP_CNT = SYMBOL_COUNT / 4;

/* @@@ Testbench signals for DUT @@@ */
/* DUT Connections */
logic clk;
logic rst_n;
logic in_valid;
logic [ ADC_DATA_WIDTH - 1 : 0 ] in_data;
logic in_ready;
i2c_if i2c();
/* Waveform Generator Connections */
bit [ SYMBOL_COUNT - 1 : 0 ] bit_pattern;
logic gen;
logic symbol_value;
/* I2C Master Connections */
logic sda_drive, sda_val;
logic scl;
/* Output Capturing Variables */
logic ack;
logic [7:0] rx;

/* @@@ Instantiate DUT, waveform generator, and I2C master @@@ */
top #(
	.ADC_DATA_WIDTH(ADC_DATA_WIDTH),
	.ADC_FIFO_DEPTH(ADC_FIFO_DEPTH),
	.ACC_WIDTH(ACC_WIDTH),
	.SAMPLE_RATE(SAMPLE_RATE),
	.BAUD(BAUD),
	.F0(F0),
	.F1(F1),
	.I2C_ADDR(I2C_ADDR)
) DUT (
	.clk(clk),
	.rst_n(rst_n),
	.adc_q_in(in_data),
	.adc_q_valid_in(in_valid),
	.adc_q_ready_in(in_ready),
	.i2c(i2c)
);

waveform_generator #(
    .SAMPLE_WIDTH(ADC_DATA_WIDTH),
    .SAMPLE_RATE(SAMPLE_RATE),
    .BAUD(BAUD),
    .F0(F0),
    .F1(F1),
    .AMPLITUDE(AMPLITUDE),
    .NOISE(NOISE)
) wave_gen (
    .clk(clk),
    .rst_n(rst_n),
    .out_ready(in_ready),
    .gen_samples(gen),
    .symbol_value(symbol_value),
    .out_valid(in_valid),
    .out_data(in_data)
);

// Open-drain SDA/SCL drive logic
assign i2c.sda = sda_drive ? sda_val : 1'b1;
assign i2c.scl = scl;

/* @@@ I2C Master Tasks @@@ */
task send_start();
	repeat (CLOCK_PULSE) @(negedge clk);
	sda_drive = 1; sda_val = 1; scl = 1;
	repeat (CLOCK_PULSE) @(negedge clk);
	sda_val = 0;
	repeat (CLOCK_PULSE) @(negedge clk); scl = 0;
endtask

task send_bit(input bit b);
	repeat (CLOCK_PULSE) @(negedge clk); scl = 1; sda_val = b;
	repeat (CLOCK_PULSE) @(negedge clk); scl = 0;
endtask

task send_byte(input byte data);
	for (int i = 7; i >= 0; i--) send_bit(data[i]);
endtask

task read_bit(output bit b);
	sda_drive = 0;
	repeat (CLOCK_PULSE) @(negedge clk); scl = 1;
	repeat (CLOCK_PULSE) @(negedge clk); b = i2c.sda;
	scl = 0;
endtask

task read_byte(output byte data);
	for (int i = 7; i >= 0; i--) begin
		logic b;
		read_bit(b);
		data[i] = b;
	end
endtask

task send_ack();
	sda_drive = 1; sda_val = 0;
	repeat (CLOCK_PULSE) @(negedge clk); scl = 1;
	repeat (CLOCK_PULSE) @(negedge clk); scl = 0;
	repeat (CLOCK_PULSE) @(negedge clk);
endtask

task send_nack();
	sda_drive = 1; sda_val = 1;
	repeat (CLOCK_PULSE) @(negedge clk); scl = 1;
	repeat (CLOCK_PULSE) @(negedge clk); scl = 0;
	repeat (CLOCK_PULSE) @(negedge clk);
endtask

task send_stop();
	sda_drive = 1; sda_val = 0; scl = 1;
	repeat (CLOCK_PULSE) @(negedge clk);
	sda_val = 1;
	repeat (CLOCK_PULSE) @(posedge clk);
	sda_drive = 0;
endtask

/* @@@ Testbench Procedural Blocks @@@ */
/* Clock setup */
initial clk = 0;
always #1 clk = ~clk;

/* EDAPlayground waveform viewer */
initial
begin
`ifdef DEBUG
$dumpfile("dump.vcd"); $dumpvars;
`endif
end

/* Monitoring */
initial
begin
if (MONITOR != 0)
	begin
	$display("Time\t\t\tSDA\tSCL");
	$monitor("%t\t%1b\t%1b", $time, i2c.sda, i2c.scl);
	end
end

/* Reset, then start generating symbols one by one */
initial
begin
    rst_n = 0;
    gen = 0;
    symbol_value = 0;
    @( posedge clk );
    rst_n = 1;
    @( posedge clk );

    for (int symbol_index = 0; symbol_index < SYMBOL_COUNT; symbol_index++ )
    begin
        symbol_value = bit_pattern[ symbol_index ];

        /* Generate the next symbol's samples */
        @(negedge clk);
        gen = 1;
        @(negedge clk);
        gen = 0;
        wait ( !in_valid );
    end
end

initial
begin
sda_drive = 0; sda_val = 1;
scl = 1;

bit_pattern = $urandom;

repeat (BYTE_COUNT + 5) begin
	repeat (13000) @(posedge clk);

	send_start();
	send_byte((I2C_ADDR << 1) | 1);       // ((0x42 << 1) | 1) = 0x85 (read)
	read_bit(ack);          // ACK from slave

	read_byte(rx);          // Read 1 byte

	send_ack();            // Master done reading
	send_stop();
	$display("ACK from slave: %b", ack);
	$display("Received byte from slave: %2h", rx);
end

$display("Random bits to be received: 0x%32h", bit_pattern);		// 32 = SYMBOL_COUNT / 4

$finish;
end

endmodule