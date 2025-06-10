module i2c_assertions(clk, i2c, start_cond, stop_cond);
input clk, start_cond, stop_cond;
i2c_if i2c;

sequence StartCond_s;
($fell(i2c.sda) && $stable(i2c.scl) && i2c.scl) ##0 ~i2c.sda throughout $fell(i2c.scl)[->1];
endsequence

sequence StopCond_s;
($rose(i2c.scl) && $stable(i2c.sda) && ~i2c.sda) ##0 i2c.scl throughout $rose(i2c.sda)[->1];
endsequence

property StartCond_p;
StartCond_s |=> start_cond;
endproperty
StartCond_a: assert property (@(posedge clk) StartCond_p)
else $error("Error: start_cond of bus monitor not asserted during start condition! t=%0t", $time);

property StopCond_p;
StopCond_s |=> stop_cond;
endproperty
StopCond_a: assert property (@(posedge clk) StopCond_p)
else $error("Error: stop_cond of bus monitor not asserted during stop condition! t=%0t", $time);

property StartToStop_p;
StartCond_s |=> ##[*] StopCond_s;
endproperty
StartToStop_a: assert property (@(posedge clk) StartToStop_p)
else $error("Error: Didn't see a stop condition after a start condition! t=%0t", $time);

endmodule