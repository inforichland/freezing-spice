library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;

package mem_pkg is

    type mem_in is record
        alu_out   : word;
        rf_we     : std_logic;
        insn_type : insn_type_t;
        rd_addr   : std_logic_vector(4 downto 0);
    end record mem_in;

    type mem_out is record
        data_addr : word;
        we : std_logic;
        re : std_logic;
        data_out : word;
    end record mem_out;

end package mem_pkg;
