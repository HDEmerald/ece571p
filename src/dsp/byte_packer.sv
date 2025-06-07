/*
 * byte_packer.sv
 *
 * An 8-bit shift register.
 *
 */

module byte_packer #(
    parameter int DATA_WIDTH = 8
)(
    input logic clk,
    input logic rst_n,

    input logic bit_in,
    input logic bit_in_valid,

    output logic out_valid,
    output logic [ DATA_WIDTH - 1 : 0 ] out_data
);

logic [ DATA_WIDTH - 1 : 0 ] shift_reg;
logic [ $clog2( DATA_WIDTH ) : 0 ] bit_count;

always_ff @( posedge clk or negedge rst_n )
begin
    if ( !rst_n )
    begin
        shift_reg <= '0;
        bit_count <= '0;
        out_valid <= 1'b0;
        out_data <= '0;
    end
    else
    begin
        out_valid <= 1'b0;
        out_data <= '0;

        if ( bit_in_valid )
        begin
            /* Form the new shift-register value */
            logic [ DATA_WIDTH - 1 : 0] shifted;
            shifted = { bit_in, shift_reg[ DATA_WIDTH - 1 : 1 ] };
            
            shift_reg <= shifted;

            /* Output the byte when full */
            if (bit_count == DATA_WIDTH - 1)
            begin
                out_valid <= 1'b1;
                out_data <= shifted;
                bit_count <= '0;
            end
            else
            begin
                bit_count <= bit_count + 1;
            end
        end
    end
end

endmodule
