library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;

package if_pkg is

    -- inputs to Instruction Fetch stage
    type if_in is record
        insn    : word;
        load_pc : std_logic;
        next_pc : word;
        stall   : std_logic;
    end record if_in;

    -- outputs from Instruction Fetch stage
    type if_out is record
        fetch_addr : word;
        pc : word;
    end record if_out;
    
end package if_pkg;
