/*
 * byte_packer_tb.sv
 *
 * Exhaustive testbench for the byte_packer shift register.
 *
 */

module byte_packer_tb;
parameter int DATA_WIDTH = 8;
localparam int MAX = 2 ** DATA_WIDTH;

logic clk;
logic rst_n;
logic bit_in;
logic bit_in_valid;
logic out_valid;
logic [ DATA_WIDTH - 1 : 0] out_data;

byte_packer #(
    .DATA_WIDTH( DATA_WIDTH )
) dut (
    .clk ( clk),
    .rst_n ( rst_n ),
    .bit_in ( bit_in ),
    .bit_in_valid ( bit_in_valid ),
    .out_valid ( out_valid ),
    .out_data ( out_data )
);

/* Clock setup */
initial clk = 0;
always #1 clk = ~clk;

integer i;
reg [ DATA_WIDTH - 1 :0 ] expected_byte;
integer bit_index;
integer errors;

/* Apply stimulus and check */
initial
begin
    rst_n = 0;
    bit_in = 0;
    bit_in_valid = 0;
    errors = 0;
    @( posedge clk );
    rst_n = 1;
    @( posedge clk );

    /* Loop over all possible patterns */
    for ( i = 0; i < MAX; i = i + 1 )
    begin
        expected_byte = i[ DATA_WIDTH - 1 : 0 ];

        /* Drive bits LSB-first */
        for ( bit_index = 0; bit_index < DATA_WIDTH; bit_index = bit_index + 1 )
        begin
            bit_in_valid = 1'b1;
            bit_in = expected_byte[ bit_index ];
            @( posedge clk );
        end

        bit_in_valid = 1'b0;
        bit_in = 1'b0;

        @( posedge clk );
        if ( !out_valid )
        begin
            $display( "out_valid did not assert for byte %0x0h", i );
            errors = errors + 1;
        end
        else if ( out_data !== expected_byte )
        begin
            $display( "out_data mismatch. Expected 0x%0h, got 0x%0h", expected_byte, out_data );
            errors = errors + 1;
        end

        @(posedge clk);
    end

    if (errors == 0)
    begin
        $display( "Byte packer test passed: all %0d patterns correct", MAX );
    end
    else
    begin
        $display( "Byte packer test failed: %0d errors detected.", errors );
    end
    $finish;
end

endmodule
