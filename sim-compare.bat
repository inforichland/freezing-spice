@echo off

del *.cf *.vcd
ghdl -a common.vhd decode_pkg.vhd compare_unit.vhd tests/compare_tb.vhd
ghdl -e compare_tb
ghdl -r compare_tb --vcd=compare_tb.vcd

REM gtkwave compare_tb.vcd
