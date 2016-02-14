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
+ 2-cycle branch penalty for correctly predicted branches, 3 otherwise (hoping to improve these soon)
+ Most structural hazards that could be overcome w/ muxing are implemented as such ("bypassing" or "forwarding")

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
+ Interrupts / Exceptions
+ More sophisticated Branch prediction
+ Caches
+ Out-of-order (maybe?)
+ Multiple-issue (maybe?)
+ Probably more...
