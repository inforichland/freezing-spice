@echo off

del *.cf *.vcd
ghdl -a common.vhd decode_pkg.vhd decode.vhd encode_pkg.vhd alu.vhd compare_unit.vhd ex_pkg.vhd ex.vhd id_pkg.vhd id.vhd if_pkg.vhd if.vhd regfile.vhd pipeline.vhd ../tests/pipeline_tb.vhd
ghdl -e pipeline_tb
REM ghdl -r pipeline_tb --stack-size=500000000 --vcd=pipeline_tb.vcd
ghdl -r pipeline_tb --vcd=pipeline_tb.vcd

REM gtkwave decoder_tb.vcd
