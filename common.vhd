library ieee;
use ieee.std_logic_1164.all;

package common is
    -- definition for a machine word
    subtype word is std_logic_vector(31 downto 0);

    -- pipeline registers between IF and ID stages
    type if_id_regs_t is record
        ir  : word;                     -- instruction register
        npc : word;                     -- PC pipeline register
    end record if_id_regs_t;

    -- pipeline registers between ID and EX stages
    type id_ex_regs_t is record
        a   : word;
        b   : word;
        npc : word;
        ir  : word;
        imm : word;
    end record id_ex_regs_t;

    -- pipeline registers between EX and MEM stages
    type ex_mem_regs_t is record
        lmd          : word;
        branch_taken : std_logic;
        npc          : word;
        ir           : word;
        b            : word;
    end record ex_mem_regs_t;

    -- constants
    constant c_if_id_regs_reset : if_id_regs_t := (ir  => (others => '0'),
                                                   npc => (others => '0'));

    constant c_id_ex_regs_reset : id_ex_regs_t := (a   => (others => '0'),
                                                   b   => (others => '0'),
                                                   npc => (others => '0'),
                                                   ir  => (others => '0'),
                                                   imm => (others => '0'));


    -- sign-extend a 16-bit vector to 32 bits
    function sign_extend (value : std_logic_vector(15 downto 0)) return word;
    
end package common;

package body common is

    -- purpose: sign-extend a vector from 16 to 32 bits
    function sign_extend (value : std_logic_vector(15 downto 0)) return word is
        variable result : word := (others => '0');
    begin  -- function sign_extend
        for i in 31 downto 16 loop
            result(i) := value(15);
        end loop;  -- i
        result(15 downto 0) := value;

        return result;
    end function sign_extend;
    
end package body common;
