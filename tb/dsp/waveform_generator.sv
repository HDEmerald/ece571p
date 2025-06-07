/*
 * waveform_generator.sv
 *
 * This module acts as a FIFO and outputs an unsigned sine waveform
 * for the chosen frequency.
 *
 */

module waveform_generator #(
    parameter int SAMPLE_WIDTH = 12,
    parameter int SAMPLE_RATE = 48000,
    parameter real BAUD = 45.0,
    parameter real F0 = 2995.0,
    parameter real F1 = 2125.0,
    parameter real AMPLITUDE = 0.5,
    parameter real NOISE = 0.0
)(
    input logic clk,
    input logic rst_n,
    input logic out_ready,
    input logic gen_samples,
    input logic symbol_value,
    output logic out_valid,
    output logic [ SAMPLE_WIDTH - 1 : 0 ] out_data
);

localparam int SAMPLES_PER_SYMBOL = $rtoi( SAMPLE_RATE / BAUD + 0.5 );

localparam real TWO_PI = 6.283185307179586;
localparam real LEVELS = ( 2.0 ** SAMPLE_WIDTH ) - 1.0;

logic [ SAMPLE_WIDTH - 1 : 0 ] samples [ 0 : SAMPLES_PER_SYMBOL - 1 ];

/* Fill the FIFO with samples when gen_samples rises */
always_ff @( posedge gen_samples )
begin
    automatic real time_in_symbol, sample_in_symbol, inst_sine, scaled_sample, freq;
    automatic int sample_uint;

    for ( int i = 0; i < SAMPLES_PER_SYMBOL; i++ )
    begin
        freq = symbol_value ? F1 : F0;
        sample_in_symbol = i % SAMPLES_PER_SYMBOL;
        time_in_symbol = sample_in_symbol / real'( SAMPLE_RATE );

        /* Calculate instantaneous value */
        inst_sine = AMPLITUDE * $sin( TWO_PI * freq * time_in_symbol ) + ( 2.0 * ( $urandom( ) / 4294967295.0 ) - 1.0 ) * NOISE;
        inst_sine = ( inst_sine > 1.0 ) ? 1.0 : ( inst_sine < -1.0 ) ? -1.0 : inst_sine;

        /* Map to unsigned range 0..LEVELS */
        scaled_sample = ( inst_sine + 1.0 ) * ( LEVELS / 2.0 );
        sample_uint = $rtoi( scaled_sample + 0.5 );
        samples[ i ] = sample_uint[ SAMPLE_WIDTH - 1 : 0 ];
    end
end

logic [ $clog2( SAMPLES_PER_SYMBOL ) - 1 : 0 ] read_ptr;

always_ff @( posedge clk or negedge rst_n )
begin
    if ( !rst_n )
    begin
        read_ptr <= '0;
        out_valid <= 1'b0;
        out_data  <= 0;
    end
    else
    begin
        if ( gen_samples )
        begin
            read_ptr <= '0;
            out_data  <= samples[ 0 ];
            out_valid <= 1'b1; /* Samples are generated in 1 cycle */
        end
        if ( out_valid && out_ready )
        begin
            out_data <= samples[ read_ptr ];
            read_ptr <= read_ptr + 1;
            if ( read_ptr == SAMPLES_PER_SYMBOL - 1 )
            begin
                out_valid <= 1'b0;
            end
        end
    end
end

endmodule
