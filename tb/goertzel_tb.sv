/*
 * goertzel_tb.sv
 *
 * This testbench verifies the operation of the goertzel_filter module by
 * comparing the output powers of 2 instances given an input BFSK waveform.
 *
 */

module goertzel_filter_tb;
parameter int SAMPLE_WIDTH = 12;
parameter int ACC_WIDTH = 24;
parameter int SAMPLE_RATE = 48000;
parameter real BAUD = 45.45;
parameter real F0 = 2295.0;
parameter real F1 = 2125.0;
parameter real AMPLITUDE = 0.5;
parameter real NOISE = 0.0;
localparam int SYMBOL_COUNT = 8;

logic clk, rst_n, start, in_valid, ready, gen;
logic [ SAMPLE_WIDTH - 1 : 0 ] current_sample;
logic [ SYMBOL_COUNT - 1 : 0 ] input_pattern = 8'b11101001;

/* Clock setup */
initial clk = 0;
always #1 clk = ~clk;

/* Convert unsigned BFSK samples to signed, and centered around 0 */
logic signed [ SAMPLE_WIDTH - 1 : 0 ] centered_sample;
always_comb
begin
    centered_sample = $signed( current_sample ) - $signed( 1 << ( SAMPLE_WIDTH - 1 ) );
end

localparam int N_FREQS = 2;
localparam real TARGET_FREQS [ N_FREQS ] = '{ F0, F1 };
logic f_valid [ N_FREQS ];
logic signed [ 2 * ACC_WIDTH - 1 : 0 ] f_power [ N_FREQS ];

/* Generate a Goertzel filter for each frequency */
genvar i;
generate
    for (i = 0; i < N_FREQS; i++)
    begin
        goertzel_filter #(
            .SAMPLE_WIDTH( SAMPLE_WIDTH ),
            .ACC_WIDTH ( ACC_WIDTH ),
            .SAMPLE_RATE ( SAMPLE_RATE ),
            .TARGET_FREQ ( TARGET_FREQS[ i ] ),
            .BAUD ( BAUD )
        ) u_goer (
            .clk ( clk ),
            .rst_n ( rst_n ),
            .start ( start ),
            .in_valid ( in_valid ),
            .in_sample ( centered_sample[ SAMPLE_WIDTH - 1 : 0 ] ),
            .out_valid ( f_valid[ i ] ),
            .power ( f_power[ i ])
        );
    end
endgenerate

waveform_generator #(
    .SAMPLE_WIDTH ( SAMPLE_WIDTH ),
    .SAMPLE_RATE ( SAMPLE_RATE ),
    .BAUD ( BAUD ),
    .F0 ( F0 ),
    .F1 ( F1 ),
    .SYMBOL_COUNT ( SYMBOL_COUNT ),
    .AMPLITUDE ( AMPLITUDE ),
    .NOISE ( NOISE )
) waveform_fifo (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .out_ready ( ready ),
    .gen_samples( gen ),
    .pattern ( input_pattern ),
    .out_valid ( in_valid ),
    .out_data ( current_sample )
);

/* Reset and start sequence */
initial
begin
    rst_n = 0;
    start = 0;
    ready = 1; /* Always ready to consume a sample */
    #10;
    rst_n = 1;
    gen = 1;

    /* Start iterating over the first symbol */
    #1 @( negedge clk );
    start = 1;
    @( negedge clk );
    start = 0;
end

initial
begin
    automatic integer pass = 1;
    automatic int symbol_count = 0;

    forever
    begin
        /* Look for end-of-window from the first filter */
        @( posedge clk )
        if ( f_valid[ 0 ] )
        begin
            if ( $isunknown( f_power[ 0 ] ) || $isunknown( f_power[ 1 ] ) )
            begin
                $error( "Symbol %0d: bit=0, X detected, P0: %0d, P1: %0d",
                symbol_count, f_power[ 0 ], f_power[ 1 ] );
                pass = 0;
            end

            if ( input_pattern[ symbol_count ] == 1'b0 ) /* 0 symbol was sent, F0 should have greater power */
            begin
                if ( !( f_power[ 0 ] > f_power[ 1 ] ) )
                begin
                    $error( "Symbol %0d: bit=0, expected F0>F1 but got %0d <= %0d",
                    symbol_count, f_power[ 0 ], f_power[ 1 ] );
                    pass = 0;
                end
            end
            else  /* 1 symbol was sent, F1 should have greater power */
            begin
                if ( !( f_power[ 1 ] > f_power[ 0 ] ) )
                begin
                    $error( "Symbol %0d: bit=1, expected F1>F0 but got %0d <= %0d",
                    symbol_count, f_power[ 1 ], f_power[ 0 ] );
                    pass = 0;
                end
            end

            symbol_count++;
            if ( symbol_count == SYMBOL_COUNT )
            begin
                if ( pass )
                    $display( "Goertzel filter test passed: all %0d symbols correct", SYMBOL_COUNT );
                else
                    $display( "Goertzel filter test failed" );
                    $finish;
            end

            /* Start iterating over the next symbol */
            @( negedge clk );
            start = 1;
            @( negedge clk );
            start = 0;
        end
    end
end

endmodule
