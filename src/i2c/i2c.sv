interface i2c_if;
  wand scl;
  wand sda;

  modport slave (
    input scl,
    inout sda
  );

endinterface

module i2c_slave #(
  parameter SLAVE_ADDR = 7'h42
)(
  input logic         clk,          // Module clock
  i2c_if.slave        i2c,          // I2C bus
  input logic         rst_n,        // Reset signal

  input logic         fifo_valid,   // Valid FIFO data out signal
  input logic [7:0]   fifo_dout,    // Data from FIFO to transmit
  output logic        fifo_rd_en   	// Read enable for FIFO
);

  // SDA handling (open-drain)
  logic sda_out_en;
  logic sda_out_val;
  assign i2c.sda = sda_out_en ? sda_out_val : 1'bz;

  // Synchronize and detect edges
  logic [1:0] sda_sync, scl_sync;
  always_ff @(posedge clk) begin
    sda_sync <= {sda_sync[0], i2c.sda};
    scl_sync <= {scl_sync[0], i2c.scl};
  end

  wire scl_rising  = (scl_sync == 2'b01);
  wire scl_falling = (scl_sync == 2'b10);
  wire sda_falling = (sda_sync == 2'b10);
  wire sda_rising  = (sda_sync == 2'b01);

  wire start_cond;
  wire stop_cond;
  wire busy;
  i2c_bus_monitor i2c_bm(
    .clk(clk),
	.i2c(i2c),
    .busy(busy),
    .start(start_cond),
    .stop(stop_cond)
  );

  typedef enum logic [2:0] {
    IDLE, ADDRESS, ACK_ADDR, SEND_BYTE, WAIT_ACK, STOP
  } state_t;

  state_t state;
  logic [7:0] shift_reg;
  logic [3:0] bit_cnt;
  logic data_cycle;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state              <= IDLE;
      bit_cnt            <= 0;
      sda_out_en         <= 0;
      sda_out_val        <= 0;
      fifo_rd_en <= 0;
      data_cycle <= 0;
    end else begin
      fifo_rd_en <= 0;
      sda_out_en         <= 0;

      case (state)
        IDLE: begin
          if (start_cond) begin
            state    <= ADDRESS;
            bit_cnt  <= 0;
          end
        end

        ADDRESS: begin
          if (scl_rising) begin
            shift_reg <= {shift_reg[6:0], i2c.sda};
            if (bit_cnt == 7) begin
              state <= ACK_ADDR;
              sda_out_en <= 1;
            end
            bit_cnt <= bit_cnt + 1;
          end
        end

        ACK_ADDR: begin
          sda_out_en <= 1;
          sda_out_val <= 0;
          if (scl_falling) begin
            if (shift_reg[7:1] == SLAVE_ADDR && shift_reg[0] == 1 && fifo_valid == 1) begin
              fifo_rd_en <= 1;
              bit_cnt <= 0;
              state <= SEND_BYTE;
            end else begin
              sda_out_val <= 1;  // NACK
              state <= STOP;
            end
          end
        end

        SEND_BYTE: begin
          sda_out_en <= 1;
          if ((i2c.scl == 0) && (data_cycle == 0)) begin
            sda_out_val <= fifo_dout[7 - bit_cnt];
            bit_cnt <= bit_cnt + 1;
            data_cycle <= 1;
            if (bit_cnt == 7) begin
              state <= WAIT_ACK;
              data_cycle <= 0;
            end
          end
          else if (i2c.scl == 1)
            data_cycle <= 0;
        end

        WAIT_ACK: begin
          if (scl_rising) begin
            sda_out_en <= 0;
            if (sda_sync[1] == 1) begin
              state <= STOP;
            end else begin
              state <= STOP;
            end
          end
        end

        STOP: begin
          if (stop_cond)
            state <= IDLE;
        end
      endcase
    end
  end

endmodule

module i2c_bus_monitor(
	input logic 	clk,
	i2c_if.slave 	i2c,
	output logic	busy,
	output logic	start,
	output logic	stop
);

enum {IDLE, READY, START, BUSY, HOLD, STOP} State, NextState;

// Update state on every posedge
always_ff @(posedge clk)
begin
	State <= NextState;
end

// Next state generation logic
always_comb
begin
case (State)
	IDLE:	NextState = ((i2c.sda == 0) && (i2c.scl == 1)) ? READY : IDLE;
	READY:	NextState = ((i2c.sda == 0) && (i2c.scl == 0)) ? START : ((i2c.sda == 1) && (i2c.scl == 1)) ? IDLE : READY;
	START:	NextState = ((i2c.sda == 0) && (i2c.scl == 1)) ? HOLD : BUSY;
	BUSY:	NextState = ((i2c.sda == 0) && (i2c.scl == 1)) ? HOLD : BUSY;
	HOLD:	NextState = ((i2c.sda == 1) && (i2c.scl == 1)) ? STOP : ((i2c.sda == 0) && (i2c.scl == 1)) ? HOLD : BUSY;
	STOP:	NextState = ((i2c.sda == 0) && (i2c.scl == 1)) ? READY : IDLE;
endcase
end

// Output generation
always_comb
begin
busy = (State == START) || (State == BUSY) || (State == HOLD);
start = (State == START);
stop = (State == STOP);
end

endmodule