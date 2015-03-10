library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
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
        npc : unsigned(31 downto 0);    -- PC pipeline register
    end record if_id_regs_t;

    -- pipeline registers between ID and EX stages
    type id_ex_regs_t is record
        rs1_data    : word;
        rs2_data    : word;
        npc         : unsigned(31 downto 0);
        alu_func    : alu_func_t;
        op2_src     : op2_src_t;
        insn_type   : insn_type_t;
        branch_type : branch_type_t;
        load_type   : load_type_t;
        store_type  : store_type_t;
        rf_wr_addr  : std_logic_vector(4 downto 0);
        imm         : word;
        rf_wr_en    : std_logic;
    end record id_ex_regs_t;

    -- pipeline registers between EX and MEM stages
    type ex_mem_regs_t is record
        jump_addr  : word;
        lmd        : word;
        load_pc    : std_logic;
        npc        : unsigned(31 downto 0);
        load_type  : load_type_t;
        store_type : store_type_t;
        rf_wr_addr : std_logic_vector(4 downto 0);
        rf_wr_data : word;
        rf_wr_en   : std_logic;
        imm        : word;
        alu_output : word;
        insn_type  : insn_type_t;
    end record ex_mem_regs_t;

    type mem_wb_regs_t is record
        alu_output : word;
        rf_wr_en   : std_logic;
        insn_type  : insn_type_t;
        rf_wr_addr : std_logic_vector(4 downto 0);
        lmd        : word;
    end record mem_wb_regs_t;

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
                                                   rf_wr_addr  => "00000",
                                                   imm         => (others => '0'),
                                                   rf_wr_en    => '0');

    constant c_ex_mem_regs_reset : ex_mem_regs_t := (lmd        => (others => '0'),
                                                     load_pc    => '0',
                                                     jump_addr  => (others => '0'),
                                                     rf_wr_data => (others => '0'),
                                                     npc        => (others => '0'),
                                                     load_type  => LOAD_NONE,
                                                     store_type => STORE_NONE,
                                                     rf_wr_addr => "00000",
                                                     imm        => (others => '0'),
                                                     alu_output => (others => '0'),
                                                     rf_wr_en   => '0',
                                                     insn_type  => OP_ILLEGAL);

    constant c_mem_wb_regs_reset : mem_wb_regs_t := (alu_output => (others => '0'),
                                                     rf_wr_en   => '0',
                                                     insn_type  => OP_ILLEGAL,
                                                     rf_wr_addr => "00000",
                                                     lmd        => (others => '0'));

    -- print a string with a newline
    procedure println (str : in string);
    procedure print (slv       : in std_logic_vector);

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

    procedure print (slv : in std_logic_vector) is
        variable l : line;
    begin  -- procedure print
        for i in slv'range loop
            if slv(i) = '0' then
                write(l, string'("0"));
            elsif slv(i) = '1' then
                write(l, string'("1"));
            elsif slv(i) = 'X' then
                write(l, string'("X"));
            elsif slv(i) = 'U' then
                write(l, string'("U"));
            end if;
        end loop;  -- i
        writeline(output, l);
    end procedure print;
    
end package body common;
