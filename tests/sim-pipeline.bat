@echo off

del *.cf *.vcd
ghdl -a ../src/common.vhd ../src/decode_pkg.vhd ../src/decode.vhd ../src/encode_pkg.vhd ../src/regfile.vhd ../src/alu.vhd ../src/compare_unit.vhd ../src/pipeline.vhd pipeline_tb.vhd
ghdl -e pipeline_tb
ghdl -r pipeline_tb --stack-size=500000000 --vcd=pipeline_tb.vcd

gtkwave decoder_tb.vcd
