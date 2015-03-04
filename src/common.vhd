library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

package common is
    -- definition for a machine word
    subtype word is std_logic_vector(31 downto 0);

    -- Enumerated types
    type alu_func_t is (ALU_NONE, ALU_ADD, ALU_ADDU, ALU_SUB, ALU_SUBU, ALU_SLT, ALU_SLTU, ALU_AND, ALU_OR, ALU_XOR, ALU_SLL, ALU_SRA, ALU_SRL);
    type op1_src_t is (OP1_REG, OP1_NPC);
    type op2_src_t is (OP2_REG, OP2_IMM);
    type insn_type_t is (OP_ILLEGAL, OP_LUI, OP_AUIPC, OP_JAL, OP_JALR, OP_BRANCH, OP_LOAD, OP_STORE, OP_ALU);
    type imm_type_t is (IMM_NONE, IMM_I, IMM_S, IMM_B, IMM_U, IMM_J);
    type branch_type_t is (BRANCH_NONE, BEQ, BNE, BLT, BGE, BLTU, BGEU);
    type load_type_t is (LOAD_NONE, LB, LH, LW, LBU, LHU);
    type store_type_t is (STORE_NONE, SB, SH, SW);

    -- pipeline registers between IF and ID stages
    type if_id_regs_t is record
        ir  : word;                     -- instruction register
        npc : word;                     -- PC pipeline register
    end record if_id_regs_t;

    -- pipeline registers between ID and EX stages
    type id_ex_regs_t is record
        rs1_data    : word;
        rs2_data    : word;
        npc         : word;
        alu_func    : alu_func_t;
        op2_src     : op2_src_t;
        insn_type   : insn_type_t;
        branch_type : branch_type_t;
        load_type   : load_type_t;
        store_type  : store_type_t;
        rd_addr     : std_logic_vector(4 downto 0);
        imm         : word;
    end record id_ex_regs_t;

    -- pipeline registers between EX and MEM stages
    type ex_mem_regs_t is record
        lmd     : word;
        load_pc : std_logic;
        npc     : word;
        ir      : word;
        b       : word;
    end record ex_mem_regs_t;

    -- constants
    constant c_if_id_regs_reset : if_id_regs_t := (ir  => (others => '0'),
                                                   npc => (others => '0'));

    constant c_id_ex_regs_reset : id_ex_regs_t := (rs1_data    => (others => '0'),
                                                   rs2_data    => (others => '0'),
                                                   npc         => (others => '0'),
                                                   alu_func    => ALU_NONE,
                                                   op2_src     => OP2_REG,
                                                   insn_type   => OP_ILLEGAL,
                                                   branch_type => BRANCH_NONE,
                                                   load_type   => LOAD_NONE,
                                                   store_type  => STORE_NONE,
                                                   rd_addr     => "00000", 
                                                   imm         => (others => '0'));

    -- print a string with a newline
    procedure println (str : in string);

    -- instruction formats
    type r_insn_t is (R_ADD, R_SLT, R_SLTU, R_AND, R_OR, R_XOR, R_SLL, R_SRL, R_SUB, R_SRA);
    type i_insn_t is (I_JALR, I_LB, I_LH, I_LW, I_LBU, I_LHU, I_ADDI, I_SLTI, I_SLTIU, I_XORI, I_ORI, I_ANDI, I_SLLI, I_SRLI, I_SRAI);
    type s_insn_t is (S_SB, S_SH, S_SW);
    type sb_insn_t is (SB_BEQ, SB_BNE, SB_BLT, SB_BGE, SB_BLTU, SB_BGEU);
    type u_insn_t is (U_LUI, U_AUIPC);
    type uj_insn_t is (UJ_JAL);
    
end package common;

package body common is

    -- print a string with a newline
    procedure println (str : in string) is
        variable l : line;
    begin  -- procedure println
        write(l, str);
        writeline(output, l);
    end procedure println;
    
end package body common;
