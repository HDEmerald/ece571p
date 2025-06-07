module top(clk, rst_n, adc_in, adc_valid, fifo_ready, i2c);
/* ADC FIFO parameters */
parameter int		ADC_DATA_WIDTH = 12;
parameter int		ADC_FIFO_DEPTH = 512;
/* BFSK Demod. parameters */
localparam int 		SAMPLE_WIDTH = ADC_DATA_WIDTH;
parameter int		ACC_WIDTH = 28;
localparam int		DATA_WIDTH = 8;
parameter real		SAMPLE_RATE = 48000.0;
parameter real		BAUD = 45.0;
parameter real		F0 = 2995.0;
parameter real		F1 = 2125.0;
/* I2C FIFO parameters */
localparam int		I2C_DATA_WIDTH = DATA_WIDTH;
localparam int		I2C_FIFO_DEPTH = 128;
/* I2C Interface Module parameters */
parameter bit [6:0]	I2C_ADDR = 'h42;

input logic clk, rst_n;
input logic adc_valid;
input logic [ADC_DATA_WIDTH-1:0] adc_in;
output logic fifo_ready;
i2c_if i2c;
endmodule