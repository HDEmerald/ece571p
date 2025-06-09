`timescale 1ns/1ns

module i2c_tb;
  parameter TESTS = 100;
  parameter CLOCK_RATIO = 64;
  parameter I2C_ADDR = 7'h42;
  localparam CLOCK_PULSE = CLOCK_RATIO / 2;
  
  logic clk, rst_n;
  logic sda_drive, sda_val;
  logic scl;
  logic fifo_valid, fifo_rd_en;
  logic [7:0] fifo_dout;
  bit ack;
  bit [7:0] rx;
  bit error;

  // Instantiate interface
  i2c_if i2c();

  // Open-drain SDA/SCL drive logic
  assign i2c.sda = sda_drive ? sda_val : 1'b1;
  assign i2c.scl = scl;

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // DUT instantiation
  i2c_slave #(.SLAVE_ADDR(I2C_ADDR)) dut (
    .clk(clk),
	.i2c(i2c),
	.rst_n(rst_n),
	.fifo_valid(fifo_valid),
	.fifo_dout(fifo_dout),
	.fifo_rd_en(fifo_rd_en)
  );

  // I2C Master tasks
  task send_start();
    repeat (CLOCK_PULSE) @(negedge clk);
    sda_drive = 1; sda_val = 1; scl = 1;
    repeat (CLOCK_PULSE) @(negedge clk);
    sda_val = 0;
    repeat (CLOCK_PULSE) @(negedge clk); scl = 0;
  endtask

  task send_bit(input bit b);
    repeat (CLOCK_PULSE) @(negedge clk); scl = 1; sda_val = b;
    repeat (CLOCK_PULSE) @(negedge clk); scl = 0;
  endtask

  task send_byte(input byte data);
    for (int i = 7; i >= 0; i--) send_bit(data[i]);
  endtask

  task read_bit(output bit b);
    sda_drive = 0;
    repeat (CLOCK_PULSE) @(negedge clk); scl = 1;
    repeat (CLOCK_PULSE) @(negedge clk); b = i2c.sda;
    scl = 0;
  endtask

  task read_byte(output byte data);
    for (int i = 7; i >= 0; i--) begin
      logic b;
      read_bit(b);
      data[i] = b;
    end
  endtask

  task send_ack();
    sda_drive = 1; sda_val = 0;
    repeat (CLOCK_PULSE) @(negedge clk);
    scl = 1;
    repeat (CLOCK_PULSE) @(negedge clk);
    scl = 0;
    repeat (CLOCK_PULSE) @(negedge clk);
  endtask

  task send_nack();
    sda_drive = 1; sda_val = 1;
    repeat (CLOCK_PULSE) @(negedge clk);
    scl = 1;
    repeat (CLOCK_PULSE) @(negedge clk);
    scl = 0;
    repeat (CLOCK_PULSE) @(negedge clk);
  endtask

  task send_stop();
    sda_drive = 1; sda_val = 0; scl = 1;
    repeat (CLOCK_PULSE) @(negedge clk);
    sda_val = 1;
    repeat (CLOCK_PULSE) @(posedge clk);
    sda_drive = 0;
  endtask

  // Test sequence
  initial begin
    $display("Begin I2C Slave Test");
    
    error = 0;
    rst_n = 0;
    sda_drive = 1; sda_val = 1;
    scl = 1;
    #20 rst_n = 1;
    fifo_valid = 1;

    repeat (TESTS) begin
    
    // random value to transmit
    fifo_dout = $urandom();
    
    // wait a random amount of time between transactions
    repeat ($urandom_range(0.5*CLOCK_PULSE,2*CLOCK_PULSE)) @(negedge clk);

    // start transaction
    send_start();
    send_byte((I2C_ADDR << 1) | 1);      // ((0x42 << 1) | 1) = 0x85 (read)

    read_bit(ack);          		// ACK from slave

    read_byte(rx);          		// Read 1 byte

    send_ack();            			// Master done reading
    send_stop();
	
    if ((ack !== 0) || (rx !== fifo_dout)) begin
      $display("Error @ %0t: ack,rx = 0b%1b,0x%2h (Expctd 0b0,0x%2h)", $time, ack, rx, fifo_dout);
      error = 1;
    end

    end

    if (error)
      $display("@@@ FAILED @@@");
    else
      $display("@@@ PASSED @@@");

    #100 $finish;
  end

  initial
  begin
  `ifdef DEBUG
  $dumpfile("dump.vcd"); $dumpvars;
  `endif
  end

endmodule
