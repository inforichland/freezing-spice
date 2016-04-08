GHDL=ghdl
GHDLFLAGS=
GHDLRUNFLAGS=

# Correct order is crucial to avoid ghdl error
SRC_PATH = src/
SRC = $(addprefix $(SRC_PATH), csr_pkg.vhd std_logic_textio.vhd common.vhd id_pkg.vhd encode_pkg.vhd alu.vhd compare_unit.vhd ex_pkg.vhd ex.vhd id.vhd if_pkg.vhd if.vhd regfile.vhd csr.vhd pipeline.vhd dpram.vhd)

# 
PIPELINE_TB=tests/pipeline_tb.vhd

#Name of each (non-pipeline) test
TESTS_PATH = tests
TESTS = decoder_tb compare_tb

# Pipeline testbench vectors
PIPELINE_TB_TEST_NUMBERS=1 2 3
TEST_VECTORS=$(addprefix $(TESTS_PATH)/test_config, $(PIPELINE_TB_TEST_NUMBERS))

SIM_PATH=sim/
SIM_OUTPUTS=$(addprefix $(SIM_PATH), memio.vec regout.vec)

# Default target
.PHONY: all
all: input_vectors $(TESTS) pipeline_tb

.PHONY: tests
tests: $(TESTS) pipeline_tb

# Analyse, Elaborate and Run
$(TESTS):
	$(GHDL) -a $(GHDLFLAGS) 	$(SRC) $(TESTS_PATH)/$@.vhd
	$(GHDL) -e $(GHDLFLAGS) 	$@
	$(GHDL) -r $(GHDLRUNFLAGS) 	$@ --vcd=$@.vcd  #--wave=$@.ghw
.PHONY: $(TESTS)

# pipeline_tb
pipeline_tb: input_vectors test1 test2 test3
.PHONY: pipeline_tb

# test case 1
test1: sim/test1.vec tests/test_config1.vhd input_vectors
	$(GHDL) -a $(GHDLFLAGS) 	$(SRC) $(TESTS_PATH)/test_config1.vhd $(PIPELINE_TB)
	$(GHDL) -e $(GHDLFLAGS) 	pipeline_tb
	$(GHDL) -r $(GHDLRUNFLAGS) 	pipeline_tb --vcd=pipeline_tb_test1.vcd
	./verify_test_vecs test1
.PHONY: test1

# test case 2
test2: sim/test2.vec tests/test_config2.vhd input_vectors
	$(GHDL) -a $(GHDLFLAGS) 	$(SRC) $(TESTS_PATH)/test_config2.vhd $(PIPELINE_TB)
	$(GHDL) -e $(GHDLFLAGS) 	pipeline_tb
	$(GHDL) -r $(GHDLRUNFLAGS) 	pipeline_tb --vcd=pipeline_tb_test2.vcd
	./verify_test_vecs test2
.PHONY: test2

# test case 3
test3: sim/test3.vec tests/test_config3.vhd input_vectors
	$(GHDL) -a $(GHDLFLAGS) 	$(SRC) $(TESTS_PATH)/test_config3.vhd $(PIPELINE_TB)
	$(GHDL) -e $(GHDLFLAGS) 	pipeline_tb
	$(GHDL) -r $(GHDLRUNFLAGS) 	pipeline_tb --vcd=pipeline_tb_test3.vcd
	./verify_test_vecs test3
.PHONY: test3

# generation of test vectors
.PHONY: $(TEST_VECTORS)
$(TEST_VECTORS):
	$(GHDL) -a $(GHDLFLAGS) 	src/csr_pkg.vhd src/common.vhd src/id_pkg.vhd src/encode_pkg.vhd $@.vhd tests/generate_ramfile.vhd
	$(GHDL) -e $(GHDLFLAGS) 	generate_ramfile
	$(GHDL) -r $(GHDLRUNFLAGS) 	generate_ramfile
.PHONY: input_vectors
input_vectors: $(TEST_VECTORS)

.PHONY: clean
clean:
	$(GHDL) --clean
	rm *.cf *.vcd
	rm $(SIM_OUTPUTS)
