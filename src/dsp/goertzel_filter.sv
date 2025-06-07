/*
 * goertzel_filter.sv
 *
 * This Goertzel filter module processes input samples over a symbol-length
 * rectangular window. It then outputs the power of the target frequency over that window.
 *
 */

module goertzel_filter #(
    parameter int SAMPLE_WIDTH = 12,
    parameter int ACC_WIDTH = 28,
    parameter real SAMPLE_RATE = 48000.0,
    parameter real TARGET_FREQ = 2995.0,
    parameter real BAUD = 45.0
)(
    input logic clk,
    input logic rst_n,
    input logic start, /* Trigger to start an accumulation window */

    input logic in_valid,
    input logic signed [ SAMPLE_WIDTH - 1 : 0 ] in_sample,

    output logic out_valid,
    output logic signed [ 2 * ACC_WIDTH - 1 : 0 ] power /* Raw energy in the DFT bin */
);

localparam int COEFF_WIDTH = 24; /* Q2.22 fixed point */
localparam int COEFF_FRAC = COEFF_WIDTH - 2;
localparam int POWER_WIDTH = 2 * ACC_WIDTH;
localparam int WINDOW_SIZE = $rtoi( SAMPLE_RATE / BAUD + 0.5 );

localparam real OMEGA = 2.0 * 3.141592653589793 * TARGET_FREQ / SAMPLE_RATE;
localparam real RCR = 2.0 * $cos( OMEGA );
localparam logic signed [ COEFF_WIDTH - 1 : 0 ] COEFF = $rtoi( RCR * ( 1 << COEFF_FRAC ) );

logic signed [ ACC_WIDTH - 1 : 0 ] s_prev, s_prev2; /* State memory */
logic [ $clog2( WINDOW_SIZE ) - 1 : 0 ] sample_count;
logic active; /* Are we currently accumulating? */

logic signed [ ACC_WIDTH - 1 : 0 ] s_next;
logic signed [ 2 * ACC_WIDTH - 1 : 0 ] sqN, sqNm1;
logic signed [ 2 * ACC_WIDTH + COEFF_WIDTH - 1 : 0 ] cross_term;

always_comb
begin
    s_next = in_sample + $signed( ( COEFF * s_prev ) >>> COEFF_FRAC ) - s_prev2;
    sqN = s_next * s_next;
    sqNm1 = s_prev * s_prev;
    cross_term = COEFF * ( s_next * s_prev );
end

always_ff @( posedge clk or negedge rst_n )
begin
    if ( !rst_n )
    begin
        active <= 1'b0;
        sample_count <= '0;
        s_prev <= '0;
        s_prev2 <= '0;
        out_valid <= 1'b0;
        power <= '0;
    end 
    else
    begin
        out_valid <= 1'b0;

        if ( start && in_valid ) /* If a sample is available immediately */
        begin
            active <= 1'b1;
            sample_count <= 1;
            s_prev2 <= '0;
            s_prev <= in_sample;
        end
        else if ( start )
        begin
            active <= 1'b1;
            sample_count <= '0;
            s_prev <= '0;
            s_prev2 <= '0;
        end
        else if ( active && in_valid ) /* Accumulate when a sample is available */
        begin
            if ( sample_count == WINDOW_SIZE - 1 )
            begin
                /* Computer the power of the window */
                power <= sqN + sqNm1 - ( cross_term >>> COEFF_FRAC );
                out_valid <= 1'b1;
                active <= 1'b0;
            end
            else
            begin
                /* Advance state and accumulate */
                sample_count <= sample_count + 1;
                s_prev2 <= s_prev;
                s_prev <= s_next;
            end
        end
    end
end

endmodule
