library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;
use work.mem_pkg.all;

entity memory_stage is
    port (mem_d : in  mem_in;
          mem_q : out mem_out);
end entity memory_stage;

architecture Behavioral of memory_stage is
begin  -- architecture Behavioral

    mem_q.data_addr <= mem_d.alu_out;
    mem_q.we <= '1' when mem_d.insn_type = OP_STORE else '0';
    mem_q.re <= '1' when mem_d.insn_type = OP_LOAD else '0';
    mem_q.data_out <= (others => '0'); -- TODO!

end architecture Behavioral;
