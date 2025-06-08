fifo_deps := $(wildcard src/fifo/*.sv)
fifotb_deps := tb/fifo/fifotb.sv

bfsk_demod_deps := $(wildcard src/dsp/*.sv)
bfsk_demodtb_deps := tb/dsp/bfsk_demod_tb.sv tb/dsp/waveform_generator.sv

goertzel_deps := src/dsp/goertzel_filter.sv
goertzeltb_deps := tb/dsp/goertzel_filter_tb.sv tb/dsp/waveform_generator.sv

byte_packer_deps := src/dsp/byte_packer.sv
byte_packertb_deps := tb/dsp/byte_packer_tb.sv

i2c_deps := $(wildcard src/i2c/*.sv)
i2ctb_deps := tb/i2c/i2ctb.sv

top_deps := $(fifo_deps) $(bfsk_demod_deps) $(i2c_deps) $(wildcard src/top/*.sv)
toptb_deps := tb/top/toptb.sv tb/dsp/waveform_generator.sv

# Commands for FIFO compilation and simulation
fifo: $(fifo_deps) $(fifotb_deps)
	vlog -source -lint $(fifo_deps) $(fifotb_deps)
sim_fifo: fifo
	vsim -c fifo_tb $(ARGS)

# Commands for BFSK Demodulator compilation and simulation
bfsk_demod: $(bfsk_demod_deps) $(bfsk_demodtb_deps)
		vlog -source -lint $(bfsk_demod_deps) $(bfsk_demodtb_deps)
sim_bfsk_demod: bfsk_demod
		vsim -c bfsk_demod_tb $(ARGS)

# Commands for Geortzel Filter compilation and simulation
goer: $(goertzel_deps) $(goertzeltb_deps)
	vlog -source -lint $(goertzel_deps) $(goertzeltb_deps)
sim_goer: goer
	vsim -c goertzel_filter_tb $(ARGS)

# Commands for  Byte-packer compilation and simulation
byte_packer: $(byte_packer_deps) $(byte_packertb_deps)
	vlog -source -lint $(byte_packer_deps) $(byte_packertb_deps)
sim_byte_packer: byte_packer
	vsim -c byte_packer_tb $(ARGS)

# Commands for I2C module compilation and simulation
i2c: $(i2c_deps) $(i2ctb_deps)
	vlog -source -lint $(i2c_deps) $(i2ctb_deps)
sim_i2c: i2c
	vsim -c i2c_tb $(ARGS)

# Commands for compiling/simulating the whole module
top: $(top_deps) $(toptb_deps)
	vlog -source -lint $(top_deps) $(toptb_deps)
sim_top: top
	vsim -c top_tb $(ARGS)