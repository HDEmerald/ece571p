/*
 * bfsk_demod_tb.sv
 *
 * Drives a random bit pattern through the waveform_generator module and
 * checks that the demodulated output bytes match the input pattern.
 *
 */

module bfsk_demod_tb;
localparam int SAMPLE_WIDTH = 12;
localparam int ACC_WIDTH = 28;
localparam int DATA_WIDTH = 8;
localparam real SAMPLE_RATE = 48000.0;
localparam real BAUD = 45.0;
localparam real F0 = 2995.0;
localparam real F1 = 2125.0;
localparam real AMPLITUDE = 0.5;
localparam real NOISE = 0.0;

localparam int BYTE_COUNT = 16; 
localparam int SYMBOL_COUNT = BYTE_COUNT * DATA_WIDTH;

logic clk;
logic rst_n;

logic in_valid;
logic [ SAMPLE_WIDTH - 1 : 0 ] in_data;
logic in_ready;
logic out_valid;
logic [ DATA_WIDTH - 1 : 0 ] out_data;
logic out_ready = 1;

bfsk_demod #(
    .SAMPLE_WIDTH ( SAMPLE_WIDTH ),
    .ACC_WIDTH ( ACC_WIDTH ),
    .DATA_WIDTH ( DATA_WIDTH ),
    .SAMPLE_RATE ( SAMPLE_RATE ),
    .BAUD ( BAUD ),
    .F0 ( F0 ),
    .F1 ( F1 )
) dut (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .in_valid ( in_valid ),
    .in_data ( in_data ),
    .in_ready ( in_ready ),
    .out_valid ( out_valid ),
    .out_data ( out_data ),
    .out_ready ( out_ready )
);

logic gen;
logic symbol_value;
waveform_generator #(
    .SAMPLE_WIDTH ( SAMPLE_WIDTH ),
    .SAMPLE_RATE ( SAMPLE_RATE ),
    .BAUD ( BAUD ),
    .F0 ( F0 ),
    .F1 ( F1 ),
    .AMPLITUDE ( AMPLITUDE ),
    .NOISE ( NOISE )
) stim (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .out_ready ( in_ready ),
    .gen_samples ( gen ),
    .symbol_value ( symbol_value ),
    .out_valid ( in_valid ),
    .out_data ( in_data )
);

/* Clock setup */
initial clk = 0;
always #1 clk = ~clk;

/* Generate a random bit pattern */
bit [ SYMBOL_COUNT - 1 : 0 ] bit_pattern;
initial bit_pattern = $urandom;

/* Reset, then start generating symbols one by one */
int symbol_index = 0;
initial
begin
    rst_n = 0;
    gen = 0;
    symbol_value = 0;
    @( posedge clk );
    rst_n = 1;
    @( posedge clk );

    for ( symbol_index = 0; symbol_index < SYMBOL_COUNT; symbol_index++ )
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

/* Collect output bytes and check */
int index = 0;
reg [ DATA_WIDTH - 1 : 0 ] expected_byte;
bit pass = 1;
initial
begin
    @( posedge rst_n );

    for ( index = 0; index < BYTE_COUNT; index++ )
    begin
        expected_byte = '0;
        for ( int b = 0; b < DATA_WIDTH; b++ )
        expected_byte[ b ] = bit_pattern[ index * DATA_WIDTH + b ];

        @( posedge out_valid );

        if ( out_data !== expected_byte )
        begin
            $error( "Byte %0d mismatch: got %0h expected %0h",
                     index, out_data, expected_byte );
            pass = 0;
        end

        @( negedge out_valid );
    end

    if ( pass )
        $display( "BFSK demodulator test: all %0d bytes correct", BYTE_COUNT );
    else
        $display( "BFSK demodulator test: failed" );
    $finish;
end

endmodule




