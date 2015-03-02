library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

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
        rs1 : word;
        rs2 : word;
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

    constant c_id_ex_regs_reset : id_ex_regs_t := (rs1 => (others => '0'),
                                                   rs2 => (others => '0'),
                                                   npc => (others => '0'),
                                                   ir  => (others => '0'),
                                                   imm => (others => '0'));

    -- sign-extend a 16-bit vector to 32 bits
    function sign_extend (value : in std_logic_vector(15 downto 0)) return word;
    procedure println (str      : in string);

    -- instruction formats
    type r_insn_t is (R_ADD, R_SLT, R_SLTU, R_AND, R_OR, R_XOR, R_SLL, R_SRL, R_SUB, R_SRA);
    type i_insn_t is (I_JALR, I_LB, I_LH, I_LW, I_LBU, I_LHU, I_ADDI, I_SLTI, I_SLTIU, I_XORI, I_ORI, I_ANDI, I_SLLI, I_SRLI, I_SRAI);
    type s_insn_t is (S_SB, S_SH, S_SW);
    type sb_insn_t is (SB_BEQ, SB_BNE, SB_BLT, SB_BGE, SB_BLTU, SB_BGEU);
    type u_insn_t is (U_LUI, U_AUIPC);
    type uj_insn_t is (UJ_JAL);
    
end package common;

package body common is

    -- purpose: sign-extend a vector from 16 to 32 bits
    function sign_extend (value : in std_logic_vector(15 downto 0)) return word is
        variable result : word := (others => '0');
    begin  -- function sign_extend
        for i in 31 downto 16 loop
            result(i) := value(15);
        end loop;  -- i
        result(15 downto 0) := value;

        return result;
    end function sign_extend;

    -- print a string with a newline
    procedure println (str : in string) is
        variable l : line;
    begin  -- procedure println
        write(l, str);
        writeline(output, l);
    end procedure println;
    
end package body common;
