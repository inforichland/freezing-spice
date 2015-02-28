@echo off

del *.cf *.vcd
ghdl -a ../src/common.vhd ../src/decode_pkg.vhd ../src/compare_unit.vhd compare_tb.vhd
ghdl -e compare_tb
ghdl -r compare_tb --vcd=compare_tb.vcd

REM gtkwave compare_tb.vcd
