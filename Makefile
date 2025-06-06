fifo_deps := $(wildcard src/fifo/*.sv)
fifotb_deps := tb/fifo/fifotb.sv

goertzel_deps := src/dsp/goertzel_filter.sv
goertzeltb_deps := tb/dsp/goertzel_tb.sv tb/dsp/waveform_generator.sv

# dsp_deps := $(wildcard src/dsp/*.sv)
# dsptb_deps := tb/dsp/???.sv

i2c_deps := $(wildcard src/i2c/*.sv)
i2ctb_deps := tb/i2c/i2ctb.sv

# top_deps := fifo_deps dsp_deps i2c_deps

# Commands for FIFO compilation and simulation
fifo: $(fifo_deps) $(fifotb_deps)
	vlog -source -lint $(fifo_deps) $(fifotb_deps)
sim_fifo: fifo
	vsim -c top $(ARGS)

# Commands for Geortzel Filter compilation and simulation
goer: $(goertzel_deps) $(goertzeltb_deps)
	vlog -source -lint $(goertzel_deps) $(goertzeltb_deps)
sim_goer: goer
	vsim -c goertzel_filter_tb $(ARGS)

# Commands for I2C module compilation and simulation
i2c: $(i2c_deps) $(i2ctb_deps)
	vlog -source -lint $(i2c_deps) $(i2ctb_deps)
sim_i2c: i2c
	vsim -c i2c_tb $(ARGS)