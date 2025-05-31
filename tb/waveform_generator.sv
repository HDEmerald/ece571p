/*
 * waveform_generator.sv
 *
 * This module acts as a FIFO and outputs an unsigned BFSK waveform
 * for the provided bit pattern.
 *
 */

module waveform_generator #(
    parameter int SAMPLE_WIDTH = 12,
    parameter int SAMPLE_RATE = 48000,
    parameter real BAUD = 45.45,
    parameter real F0 = 2295.0,
    parameter real F1 = 2125.0,
    parameter int SYMBOL_COUNT = 8,
    parameter real AMPLITUDE = 0.5,
    parameter real NOISE = 0.0
)(
    input logic clk,
    input logic rst_n,
    input logic out_ready,
    input logic gen_samples,
    input logic [ SYMBOL_COUNT - 1 : 0 ] pattern,
    output logic out_valid,
    output logic [ SAMPLE_WIDTH - 1 : 0 ] out_data
);

localparam int SAMPLES_PER_SYMBOL = $rtoi( SAMPLE_RATE / BAUD + 0.5 );
localparam int DEPTH = SYMBOL_COUNT * SAMPLES_PER_SYMBOL;

localparam real TWO_PI = 6.283185307179586;
localparam real LEVELS = ( 2.0 ** SAMPLE_WIDTH ) - 1.0;

logic [ SAMPLE_WIDTH - 1 : 0 ] samples [ 0 : DEPTH - 1 ];

/* Fill the FIFO with samples when gen_samples is asserted */
always_ff @( posedge clk )
begin
    if ( rst_n && gen_samples )
    begin
        automatic real time_sec, inst_sine, scaled_sample, freq;
        automatic int symbol_index, sample_uint;
        automatic bit current_symbol;

        for ( int i = 0; i < DEPTH; i++ )
        begin
            /* Determine symbol bit */
            symbol_index = i / SAMPLES_PER_SYMBOL;
            current_symbol = ( symbol_index < SYMBOL_COUNT ) ? pattern[ symbol_index ] : 1'b0;
            freq = current_symbol ? F1 : F0;
            time_sec = i / real'( SAMPLE_RATE );

            /* Calculate instantaneous value */
            inst_sine = AMPLITUDE * $sin( TWO_PI * freq * time_sec ) + ( 2.0 * ( $urandom( ) / 4294967295.0 ) - 1.0 ) * NOISE;
            inst_sine = ( inst_sine > 1.0 ) ? 1.0 : ( inst_sine < -1.0 ) ? -1.0 : inst_sine;

            /* Map to unsigned range 0..LEVELS */
            scaled_sample = ( inst_sine + 1.0 ) * ( LEVELS / 2.0 );
            sample_uint = $rtoi( scaled_sample + 0.5 );
            samples[ i ] = sample_uint[ SAMPLE_WIDTH - 1 : 0 ];
        end
    end
end

logic [ $clog2( DEPTH ) - 1 : 0 ] read_ptr;

always_ff @( posedge clk or negedge rst_n )
begin
    if ( !rst_n )
    begin
        read_ptr <= '0;
        out_valid <= 1'b0;
    end
    else
    begin
        if ( gen_samples )
        begin
            read_ptr <= '0;
            out_valid <= 1'b1; /* Samples are generated in 1 cycle */
        end
        if ( out_valid && out_ready )
        begin
            out_data <= samples[ read_ptr ];
            read_ptr <= read_ptr + 1;
            if ( read_ptr == DEPTH - 1 )
            begin
                out_valid <= 1'b0;
            end
        end
    end
end

endmodule
