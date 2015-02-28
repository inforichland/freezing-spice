library ieee;
use ieee.std_logic_1164.all;

use work.common.all;

package decode_pkg is
    -- Enumerated types
    type alu_func_t is (ALU_NONE, ALU_ADD, ALU_ADDU, ALU_SUB, ALU_SUBU, ALU_SLT, ALU_SLTU, ALU_AND, ALU_OR, ALU_XOR, ALU_SLL, ALU_SRA, ALU_SRL);
    type op2_src_t is (OP2_REG, OP2_IMM);
    type insn_type_t is (OP_ILLEGAL, OP_LUI, OP_AUIPC, OP_JAL, OP_JALR, OP_BRANCH, OP_LOAD, OP_STORE, OP_ALU);
    type imm_type_t is (IMM_NONE, IMM_I, IMM_S, IMM_B, IMM_U, IMM_J);
    type branch_type_t is (BRANCH_NONE, BEQ, BNE, BLT, BGE, BLTU, BGEU);
    type load_type_t is (LOAD_NONE, LB, LH, LW, LBU, LHU);
    type store_type_t is (STORE_NONE, SB, SH, SW);

    -- structure for decoded instruction    
    type decoded_t is record
        alu_func    : alu_func_t;
        op2_src     : op2_src_t;
        insn_type   : insn_type_t;
        imm_type    : imm_type_t;
        branch_type : branch_type_t;
        load_type   : load_type_t;
        store_type  : store_type_t;
        rs1         : std_logic_vector(4 downto 0);
        rs2         : std_logic_vector(4 downto 0);
        rd          : std_logic_vector(4 downto 0);
        imm         : word;
    end record decoded_t;

    constant c_decoded_reset : decoded_t := (alu_func    => ALU_NONE,
                                             op2_src     => OP2_REG,
                                             insn_type   => OP_ILLEGAL,
                                             imm_type    => IMM_NONE,
                                             branch_type => BRANCH_NONE,
                                             load_type   => LOAD_NONE,
                                             store_type  => STORE_NONE,
                                             rs1         => "00000",
                                             rs2         => "00000",
                                             rd          => "00000",
                                             imm         => (others => '0'));

    -- Constants
    constant c_op_load     : std_logic_vector(6 downto 0) := "0000011";
    constant c_op_misc_mem : std_logic_vector(6 downto 0) := "0001111";
    constant c_op_imm      : std_logic_vector(6 downto 0) := "0010011";
    constant c_op_auipc    : std_logic_vector(6 downto 0) := "0010111";
    constant c_op_store    : std_logic_vector(6 downto 0) := "0100011";
    constant c_op_reg      : std_logic_vector(6 downto 0) := "0110011";
    constant c_op_lui      : std_logic_vector(6 downto 0) := "0110111";
    constant c_op_branch   : std_logic_vector(6 downto 0) := "1100011";
    constant c_op_jalr     : std_logic_vector(6 downto 0) := "1100111";
    constant c_op_jal      : std_logic_vector(6 downto 0) := "1101111";
    constant c_op_system   : std_logic_vector(6 downto 0) := "1110011";
    
end package decode_pkg;
