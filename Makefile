GHDL=ghdl
GHDLFLAGS=
GHDLRUNFLAGS=

# Correct order is crucial to avoid ghdl error
SRC_PATH = src/
SRC = $(addprefix $(SRC_PATH), common.vhd id_pkg.vhd decode.vhd encode_pkg.vhd alu.vhd compare_unit.vhd ex_pkg.vhd ex.vhd id.vhd if_pkg.vhd if.vhd regfile.vhd pipeline.vhd dpram.vhd)

#Name of each test
TESTS_PATH = tests/
TESTS = pipeline_tb decoder_tb compare_tb

# Default target
all: $(TESTS)

# Analyse, Elaborate and Run
$(TESTS):
	$(GHDL) -a $(GHDLFLAGS) 	$(SRC) $(TESTS_PATH)/$@.vhd
	$(GHDL) -e $(GHDLFLAGS) 	$@
	$(GHDL) -r $(GHDLRUNFLAGS) 	$@ --vcd=$@.vcd

.PHONY: clean
clean:
	$(GHDL) --clean
	rm *.cf *.vcd
