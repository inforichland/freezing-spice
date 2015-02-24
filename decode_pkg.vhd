library ieee;
use ieee.std_logic_1164.all;

package decode_pkg is

    type alu_func_t is (ALU_ADD, ALU_ADDU, ALU_SUB, ALU_SUBU, ALU_SLT, ALU_SLTU, ALU_AND, ALU_OR, ALU_XOR, ALU_SLL, ALU_SRA, ALU_SRL);
    type op2_src_t is (OP2_REG, OP2_IMM);
    type insn_type_t is (OP_ILLEGAL, OP_LUI, OP_AUIPC, OP_JAL, OP_JALR, OP_BRANCH, OP_LOAD, OP_STORE, OP_ALU);
    type imm_type_t is (IMM_R, IMM_I, IMM_S, IMM_SB, IMM_U, IMM_UJ);
    type branch_type_t is (BEQ, BNE, BLT, BGE, BLTU, BGEU);
    type load_type_t is (LB, LH, LW, LBU, LHU);
    type store_type_t is (SB, SH, SW);

    type decoded_t is record            -- decoded instruction
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
    end record decoded_t;

    constant c_decoded_reset : decoded_t := (ALU_ADD,
                                             OP2_REG,
                                             OP_ILLEGAL,
                                             IMM_R,
                                             BEQ,
                                             LB,
                                             SB,
                                             "00000",
                                             "00000",
                                             "00000");
    
end package decode_pkg;
