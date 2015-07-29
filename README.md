README
======

Freezing Spice
--------------
A pipelined 32-bit RISC-V implementation, written in VHDL.  It is targeted for FPGA synthesis.

Microarchitecture
-----------------
+ 5-stage pipeline ("classic MIPS")
  + Fetch
  + Decode
  + Execute
  + Memory access
  + Register file writeback
+ In-order, single-issue (see TODOs)
+ 3-cycle branch penalty (see TODOs)
+ All hazard stalls are resolved via interlocking (see TODOs)

Status
------
While not yet finished, a large part of the RV32-I instruction set is implemented.  Note that I am not a professional CPU architect :)

Implementation
--------------
+ VHDL - RTL
+ Simulation - GHDL / GtkWave
+ Synthesis - Xilinx ISE 14.7 - Spartan 6 (*TODO*)

TODO
----
+ Better tests!
+ CSRs (Core Specific Registers)
+ Forwarding between pipeline stages to reduce structural hazards
+ Interrupts / Exceptions
+ Branch prediction
+ Caches
+ Out-of-order (maybe?)
+ Multiple-issue (maybe?)
+ Probably more...
