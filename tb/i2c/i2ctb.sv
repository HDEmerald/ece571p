`timescale 1ns/1ns

module i2c_tb;

  logic clk, rst;
  logic sda_drive, sda_val;
  logic scl;
  logic fifo_valid, fifo_rd_en;
  logic [7:0] fifo_dout;
  bit ack;
  bit [7:0] rx;

  // Instantiate interface
  i2c_if i2c();

  // Open-drain SDA/SCL drive logic
  assign i2c.sda = sda_drive ? sda_val : 1'bz;
  assign i2c.scl = scl;

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // DUT instantiation
  i2c_slave #(.SLAVE_ADDR(7'h42)) dut (
    .clk(clk),
	.i2c(i2c),
	.rst(rst),
	.fifo_valid(fifo_valid),
	.fifo_dout(fifo_dout),
	.fifo_rd_en(fifo_rd_en)
  );

  // I2C Master tasks
  task send_start();
    @(negedge clk);
    sda_drive = 1; sda_val = 1; scl = 1;
    @(negedge clk);
    sda_val = 0;
    @(negedge clk); scl = 0;
  endtask

  task send_bit(input bit b);
    sda_val = b;
    @(negedge clk); scl = 1;
    @(negedge clk); scl = 0;
  endtask

  task send_byte(input byte data);
    for (int i = 7; i >= 0; i--) send_bit(data[i]);
  endtask

  task read_bit(output bit b);
    sda_drive = 0;
    @(negedge clk); scl = 1;
    @(negedge clk); b = i2c.sda;
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
    @(negedge clk); scl = 1;
    @(negedge clk); scl = 0;
    sda_drive = 0;
  endtask

  task send_nack();
    sda_drive = 1; sda_val = 1;
    @(negedge clk); scl = 1;
    @(negedge clk); scl = 0;
    sda_drive = 0;
  endtask

  task send_stop();
    sda_drive = 1; sda_val = 0; scl = 1;
    @(negedge clk);
    sda_val = 1;
    @(posedge clk);
  endtask

  // Test sequence
  initial begin
    $display("Begin I2C Slave Test");

    rst = 1;
    sda_drive = 1; sda_val = 1;
    scl = 1;
    fifo_dout = 8'hA5;
	fifo_valid = 1;
    #20 rst = 0;

    #100;
    send_start();
    send_byte(8'h85);       // 0x42 << 1 | 1 = 0x85 (read)
    read_bit(ack);          // ACK from slave
    $display("ACK from slave: %b", ack);

    read_byte(rx);          // Read 1 byte
    $display("Received byte from slave: %2h", rx);

    send_nack();            // Master done reading
    send_stop();

    #100 $finish;
  end

endmodule
