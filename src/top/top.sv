module top(clk, rst_n, adc_q_in, adc_q_valid_in, adc_q_ready_in, i2c);
/* @@@ Parameters @@@ */
/* ADC FIFO Parameters */
parameter int		ADC_DATA_WIDTH = 12;
parameter int		ADC_FIFO_DEPTH = 512;
localparam int		ADC_CNT_SIZE = $clog2(ADC_FIFO_DEPTH)+1;
/* BFSK Demod. Parameters */
localparam int 		SAMPLE_WIDTH = ADC_DATA_WIDTH;
parameter int		ACC_WIDTH = 28;
localparam int		DATA_WIDTH = 8;
parameter real		SAMPLE_RATE = 48000.0;
parameter real		BAUD = 45.0;
parameter real		F0 = 2995.0;
parameter real		F1 = 2125.0;
/* I2C FIFO Parameters */
localparam int		I2C_DATA_WIDTH = DATA_WIDTH;
localparam int		I2C_FIFO_DEPTH = 128;
localparam int		I2C_CNT_SIZE = $clog2(I2C_FIFO_DEPTH)+1;
/* I2C Interface Module Parameters */
parameter bit [6:0]	I2C_ADDR = 'h42;

/* @@@ Inputs and Outputs @@@ */
input logic clk, rst_n;
input logic adc_q_valid_in;
input logic [ADC_DATA_WIDTH-1:0] adc_q_in;
output logic adc_q_ready_in;
i2c_if.slave i2c;

/* @@@ Inter-module Wires @@@ */
/* ADC FIFO Wires */
wire [ADC_DATA_WIDTH-1:0] adc_q_out;
wire adc_q_valid_out, adc_q_ready_out;
wire [ADC_CNT_SIZE-1:0] adc_q_cnt; 		// unused
/* BFSK Demod. Wires */
wire [DATA_WIDTH-1:0] bfsk_out;
wire bfsk_valid_out, bfsk_ready_out;
/* I2C FIFO Wires */
wire [I2C_DATA_WIDTH-1:0] i2c_q_out;
wire i2c_q_valid_out, i2c_q_ready_out;
wire [I2C_CNT_SIZE-1:0] i2c_q_cnt; 		// unused
/* I2C Interface Module Wires */
// none

/* @@@ Instantiate Sub-modules @@@ */
/* Instantiate ADC FIFO */
FIFO #(
	.DATASIZE(ADC_DATA_WIDTH),
	.FIFOSIZE(ADC_FIFO_DEPTH)	
) adc_fifo (
	.clk(clk),
	.rst_n(rst_n),
	.din(adc_q_in),
	.dinV(adc_q_valid_in),
	.dinR(adc_q_ready_in),
	.dout(adc_q_out),
	.doutV(adc_q_valid_out),
	.doutR(adc_q_ready_out),
	.cnt(adc_q_cnt)
);
/* Instantiate BFSK Demod. */
bfsk_demod #(
	.SAMPLE_WIDTH(SAMPLE_WIDTH),
	.ACC_WIDTH(ACC_WIDTH),
	.DATA_WIDTH(DATA_WIDTH),
	.SAMPLE_RATE(SAMPLE_RATE),
	.BAUD(BAUD),
	.F0(F0),
	.F1(F1)
) bfsk_dmd (
	.clk(clk),
	.rst_n(rst_n),
	.in_valid(adc_q_valid_out),
	.in_data(adc_q_out),
	.in_ready(adc_q_ready_out),
	.out_valid(bfsk_valid_out),
	.out_data(bfsk_out),
	.out_ready(bfsk_ready_out)
);
/* Instantiate I2C FIFO */
FIFO #(
	.DATASIZE(I2C_DATA_WIDTH),
	.FIFOSIZE(I2C_FIFO_DEPTH)
) i2c_fifo (
	.clk(clk),
	.rst_n(rst_n),
	.din(bfsk_out),
	.dinV(bfsk_valid_out),
	.dinR(bfsk_ready_out),
	.dout(i2c_q_out),
	.doutV(i2c_q_valid_out),
	.doutR(i2c_q_ready_out),
	.cnt(i2c_q_cnt)
);
/* Instantiate I2C Interface Module */
i2c_slave #(
	.SLAVE_ADDR(I2C_ADDR)
) i2c_mod (
	.clk(clk),
	.i2c(i2c),
	.rst_n(rst_n),
	.fifo_valid(i2c_q_valid_out),
	.fifo_dout(i2c_q_out),
	.fifo_rd_en(i2c_q_ready_out)
);

endmodule