/*
 * goertzel_filter_assertions.sv
 *
 */

module goertzel_filter_assertions #(
    parameter int SAMPLE_WIDTH = 12,
    parameter int ACC_WIDTH = 28,
    parameter real SAMPLE_RATE = 48000.0,
    parameter real BAUD = 45.0,
    parameter int WINDOW_SIZE = $rtoi( SAMPLE_RATE / BAUD + 0.5 )
)(
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic in_valid,
    input logic active,
    input logic signed [ SAMPLE_WIDTH - 1 : 0 ] in_sample,
    input logic signed [ ACC_WIDTH - 1 : 0 ] s_prev,
    input logic signed [ ACC_WIDTH - 1 : 0 ] s_prev2,
    input logic [ $clog2( WINDOW_SIZE ) - 1 : 0 ] sample_count,
    input logic out_valid,
    input logic signed [ 2 * ACC_WIDTH - 1 : 0 ] power
 );

/*
 * At the end of a window, out_valid should assert for 1 cycle.
 */
sequence low_high_low_s ( logic signal );
    !signal ##1 signal ##1 !signal;
endsequence

property out_valid_once_p;
    @( posedge clk ) disable iff ( !rst_n )
    ( ( sample_count === WINDOW_SIZE - 1 ) && in_valid && active ) |-> low_high_low_s( out_valid );
endproperty

out_valid_once_a: assert property ( out_valid_once_p )
    else $error( "out_valid was asserted for more than 1 cycle" );

/*
 * If the filter is active and a sample is available, the sample count should increase.
 */
property inc_sample_count_p;
    @( posedge clk ) disable iff ( !rst_n )
    ( in_valid && active ) |=> ( ( sample_count === ( $past( sample_count ) + 1 ) ) || out_valid );
endproperty

inc_sample_count_a: assert property ( inc_sample_count_p )
    else $error( "sample_count should increment if accumulating and a sample is available" );

/*
 * out_valid is only asserted at the end of a window.
 */
property no_spurious_out_valid_p;
    @( posedge clk ) disable iff ( !rst_n )
    out_valid |-> ( sample_count === WINDOW_SIZE - 1 )
endproperty

no_spurious_out_valid_a: assert property ( no_spurious_out_valid_p )
    else $error( "out_valid was asserted during accumulation" );

/*
 * The Goertzel module has a latency of WINDOW_SIZE.
 */
sequence accumulate_window_s;
    in_valid[ -> WINDOW_SIZE ] ##1 out_valid;
endsequence

property latency_check_p;
    @( posedge clk ) disable iff ( !rst_n )
    ( start ) |-> accumulate_window_s;
endproperty

latency_check_a: assert property ( latency_check_p )
    else $error( "Latency was not %0d cycles", WINDOW_SIZE );

endmodule
