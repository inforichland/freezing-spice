GHDL=ghdl
GHDLFLAGS=
GHDLRUNFLAGS=

# Correct order is crucial to avoid ghdl error
SRC_PATH = src/
SRC = $(addprefix $(SRC_PATH), std_logic_textio.vhd common.vhd id_pkg.vhd decode.vhd encode_pkg.vhd alu.vhd compare_unit.vhd ex_pkg.vhd ex.vhd id.vhd if_pkg.vhd if.vhd regfile.vhd pipeline.vhd dpram.vhd)

#Name of each test
TESTS_PATH = tests/
TESTS = pipeline_tb decoder_tb compare_tb

TEST_VECTORS=tests/test_config

SIM_PATH=sim/
SIM_OUTPUTS=$(addprefix $(SIM_PATH), memio.vec regout.vec)

# Default target
.PHONY: all
all: input_vectors $(TESTS)

.PHONY: tests
tests: input_vectors $(TESTS)

# Analyse, Elaborate and Run
$(TESTS): input_vectors
	$(GHDL) -a $(GHDLFLAGS) 	$(SRC) $(TESTS_PATH)/$@.vhd
	$(GHDL) -e $(GHDLFLAGS) 	$@
	$(GHDL) -r $(GHDLRUNFLAGS) 	$@ --vcd=$@.vcd  #--wave=$@.ghw
.PHONY: $(TESTS)

.PHONY: $(TEST_VECTORS)
$(TEST_VECTORS):
	$(GHDL) -a $(GHDLFLAGS) 	src/common.vhd src/id_pkg.vhd src/encode_pkg.vhd $@.vhd tests/generate_ramfile.vhd
	$(GHDL) -e $(GHDLFLAGS) 	generate_ramfile
	$(GHDL) -r $(GHDLRUNFLAGS) 	generate_ramfile

.PHONY: input_vectors
input_vectors: $(TEST_VECTORS)

.PHONY: clean
clean:
	$(GHDL) --clean
	rm *.cf *.vcd
	rm $(SIM_OUTPUTS)
