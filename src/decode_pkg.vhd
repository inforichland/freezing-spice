library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

use work.common.all;

package decode_pkg is
    -- Enumerated types
    type alu_func_t is (ALU_NONE, ALU_ADD, ALU_ADDU, ALU_SUB, ALU_SUBU, ALU_SLT, ALU_SLTU, ALU_AND, ALU_OR, ALU_XOR, ALU_SLL, ALU_SRA, ALU_SRL);
    type op1_src_t is (OP1_REG, OP1_NPC);
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
        opcode      : std_logic_vector(6 downto 0);
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
                                             imm         => (others => '0'),
                                             opcode      => (others => 'X'));

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

    procedure print (insn_type : in insn_type_t);
    procedure print (slv       : in std_logic_vector);
    
end package decode_pkg;

package body decode_pkg is

    procedure print (insn_type : in insn_type_t) is
        variable l : line;
    begin
        write(l, string'("Instruction type: "));
        if insn_type = OP_LUI then
            write(l, string'("LUI"));
            writeline(output, l);
        elsif insn_type = OP_AUIPC then
            write(l, string'("AUIPC"));
            writeline(output, l);
        elsif insn_type = OP_JAL then
            write(l, string'("JAL"));
            writeline(output, l);
        elsif insn_type = OP_JALR then
            write(l, string'("JALR"));
            writeline(output, l);
        elsif insn_type = OP_BRANCH then
            write(l, string'("BRANCH"));
            writeline(output, l);
        elsif insn_type = OP_LOAD then
            write(l, string'("LOAD"));
            writeline(output, l);
        elsif insn_type = OP_STORE then
            write(l, string'("STORE"));
            writeline(output, l);
        elsif insn_type = OP_ALU then
            write(l, string'("ALU"));
            writeline(output, l);
        else
            write(l, string'("ILLEGAL"));
            writeline(output, l);
        end if;
    end procedure print;

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

end package body decode_pkg;
