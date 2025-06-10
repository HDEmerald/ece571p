/*
 * bfsk_demod.sv
 *
 * This module takes an input BFSK waveform with 2 tones. Using a pair of
 * Goertzel filters, it identifies the bit value for each symbol and outputs
 * a completed byte.
 *
 */

module bfsk_demod #(
    parameter int SAMPLE_WIDTH = 12,
    parameter int ACC_WIDTH = 28,
    parameter int DATA_WIDTH = 8,
    parameter real SAMPLE_RATE = 48000.0, 
    parameter real BAUD = 45.0,
    parameter real F0 = 2995.0,
    parameter real F1 = 2125.0
)(
    input logic clk,
    input logic rst_n,
    input logic in_valid,
    input logic [ SAMPLE_WIDTH - 1 : 0 ] in_data,
    output logic in_ready,
    output logic out_valid,
    output logic [ DATA_WIDTH - 1 : 0 ] out_data,
    input logic out_ready
);

localparam int N_TONES = 2;
localparam int WINDOW_SIZE = $rtoi( SAMPLE_RATE / BAUD + 0.5 );

/* Convert unsigned sample to signed centered around zero */
logic signed [ SAMPLE_WIDTH - 1 : 0 ] centered_sample;
always_comb
begin
    centered_sample = $signed( {1'b0, in_data} ) - ( 1 << ( SAMPLE_WIDTH - 1 ) );
end

/* Symbol window counter to determine start pulse */
logic [ $clog2( WINDOW_SIZE ) - 1 : 0 ] sample_count;
logic start_window;
assign start_window = in_valid && ( sample_count == 0 );

always_ff @( posedge clk or negedge rst_n )
begin
    if ( !rst_n )
    begin
        sample_count <= '0;
    end
    else if ( in_valid )
    begin
        if ( sample_count == WINDOW_SIZE - 1 )
            sample_count <= '0;
        else
            sample_count <= sample_count + 1;
    end
end

/* Always ready to accept samples */
assign in_ready = 1'b1;

/* Goertzel filter outputs */
logic f_valid [ 0 : N_TONES - 1 ];
logic signed [ 2 * ACC_WIDTH - 1 : 0 ] f_power [ 0 : N_TONES - 1 ];

/* Instance for frequency F0 */
goertzel_filter #(
    .SAMPLE_WIDTH ( SAMPLE_WIDTH ),
    .ACC_WIDTH ( ACC_WIDTH ),
    .SAMPLE_RATE ( SAMPLE_RATE ),
    .TARGET_FREQ ( F0 ),
    .BAUD ( BAUD )
) gf0 (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .start ( start_window ),
    .in_valid ( in_valid ),
    .in_sample ( centered_sample ),
    .out_valid ( f_valid[ 0 ] ),
    .power ( f_power[ 0 ] )
);

/* Instance for frequency F1 */
goertzel_filter #(
    .SAMPLE_WIDTH ( SAMPLE_WIDTH ),
    .ACC_WIDTH ( ACC_WIDTH ),
    .SAMPLE_RATE ( SAMPLE_RATE ),
    .TARGET_FREQ ( F1 ),
    .BAUD ( BAUD )
) gf1 (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .start ( start_window ),
    .in_valid ( in_valid ),
    .in_sample ( centered_sample ),
    .out_valid ( f_valid[ 1 ] ),
    .power ( f_power[ 1 ] )
);

/* Bit decision: valid when both filters complete */
logic bit_valid;
logic bit_data;
assign bit_valid = f_valid[ 0 ] & f_valid[ 1 ];
assign bit_data = ( f_power[ 1 ] > f_power[ 0 ] ) ? 1'b1 : 1'b0;

/* Pack bits into bytes and output when filled */
byte_packer #(
    .DATA_WIDTH ( DATA_WIDTH )
) packer (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .bit_in ( bit_data ),
    .bit_in_valid ( bit_valid ),
    .out_valid ( out_valid ),
    .out_data ( out_data )
);

endmodule
