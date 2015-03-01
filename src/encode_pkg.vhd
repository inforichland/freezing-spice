library ieee;
use ieee.std_logic_1164.all;

use work.common.all;
use work.decode_pkg.all;

package encode_pkg is

    type u_insn_t is (U_LUI, U_AUIPC);
    type r_insn_t is (R_ADD, R_SLT, R_SLTU, R_AND, R_OR, R_XOR, R_SLL, R_SRL, R_SUB, R_SRA);
    type uj_type_t is (UJ_JAL);
    
    function encode_u_type (insn_type : u_insn_t;
                            imm_31_12 : std_logic_vector(31 downto 12);
                            rd        : std_logic_vector(4 downto 0))
        return word;

    function encode_r_type (insn_type    : r_insn_t;
                            rs1, rs2, rd : std_logic_vector(4 downto 0))
        return word;

    function encode_uj_type (insn_type : uj_type_t;
                             imm       : std_logic_vector(20 downto 1);
                             rd        : std_logic_vector(4 downto 0))
        return word;

end package encode_pkg;

package body encode_pkg is

    -- purpose: encode a U-type instruction
    function encode_u_type (insn_type : u_insn_t;
                            imm_31_12 : std_logic_vector(31 downto 12);
                            rd        : std_logic_vector(4 downto 0)) return word is
        variable result : word;
    begin  -- function encode_lui
        result(31 downto 12) := imm_31_12;
        result(11 downto 7)  := rd;
        case insn_type is
            when U_LUI   => result(6 downto 0) := c_op_lui;
            when U_AUIPC => result(6 downto 0) := c_op_auipc;
        end case;
        return result;
    end function encode_u_type;

    -- purpose: encode an R-type instruction
    function encode_r_type (insn_type    : r_insn_t;
                            rs1, rs2, rd : std_logic_vector(4 downto 0))
        return word is
        variable result : word;
    begin  -- function encode_r_type
        result(24 downto 20) := rs2;
        result(19 downto 15) := rs1;
        result(11 downto 7)  := rd;
        result(6 downto 0)   := c_op_reg;
        case insn_type is
            when R_ADD =>
                result(31 downto 25) := "0000000";
                result(14 downto 12) := "000";
            when R_SUB =>
                result(31 downto 25) := "0100000";
                result(14 downto 12) := "000";
            when R_SLL =>
                result(31 downto 25) := "0000000";
                result(14 downto 12) := "001";
            when R_SLT =>
                result(31 downto 25) := "0000000";
                result(14 downto 12) := "010";
            when R_SLTU =>
                result(31 downto 25) := "0000000";
                result(14 downto 12) := "011";
            when R_XOR =>
                result(31 downto 25) := "0000000";
                result(14 downto 12) := "100";
            when R_SRL =>
                result(31 downto 25) := "0000000";
                result(14 downto 12) := "101";
            when R_SRA =>
                result(31 downto 25) := "0100000";
                result(14 downto 12) := "101";
            when R_OR =>
                result(31 downto 25) := "0000000";
                result(14 downto 12) := "110";
            when R_AND =>
                result(31 downto 25) := "0000000";
                result(14 downto 12) := "111";
        end case;
    end function encode_r_type;

    -- purpose: encode a UJ-type instruction
    function encode_uj_type (
        insn_type : uj_type_t;
        imm       : std_logic_vector(20 downto 1);
        rd        : std_logic_vector(4 downto 0))
        return word is
        variable result : word;
    begin  -- function encode_uj_type
        result(31)           := imm(20);
        result(30 downto 21) := imm(10 downto 1);
        result(20)           := imm(11);
        result(19 downto 12) := imm(19 downto 12);
        result(11 downto 7)  := rd;
        case insn_type is
            when UJ_JAL => result(6 downto 0) := c_op_jal;
        end case;
        return result;
    end function encode_uj_type;
    
end package body encode_pkg;
