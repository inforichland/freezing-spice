@echo off

del *.cf *.vcd
ghdl -a ../src/common.vhd ../src/decode_pkg.vhd ../src/decode.vhd decoder_tb.vhd
ghdl -e decoder_tb
ghdl -r decoder_tb --vcd=decoder_tb.vcd

REM gtkwave decoder_tb.vcd
