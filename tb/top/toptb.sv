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

/* @@@ Testbench signals for DUT @@@ */
logic clk;
logic rst_n;
logic in_valid;
logic [ ADC_DATA_WIDTH - 1 : 0 ] in_data;
logic in_ready;
i2c_if i2c();

/* @@@ Instantiate DUT and waveform generator @@@ */
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

endmodule