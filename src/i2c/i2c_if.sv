interface i2c_if;
wand scl;
wand sda;

modport slave (
	input scl,
	inout sda
);

endinterface