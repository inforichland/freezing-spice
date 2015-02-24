library ieee;
use ieee.std_logic_1164.all;

use work.common.all;
use work.decode_pkg.all;

entity riscv_decoder is
    port (insn    : in  word;
          decoded : out decoded_t);     -- decoded data
end entity riscv_decoder;

architecture behavioral of riscv_decoder is
    signal decode : decoded_t;

    constant c_op_lui     : std_logic_vector(6 downto 0) := "0110111";
    constant c_op_auipc   : std_logic_vector(6 downto 0) := "0010111";
    constant c_op_jal     : std_logic_vector(6 downto 0) := "1101111";
    constant c_op_jalr    : std_logic_vector(6 downto 0) := "1100111";
    constant c_op_branch  : std_logic_vector(6 downto 0) := "1100011";
    constant c_op_load    : std_logic_vector(6 downto 0) := "0000011";
    constant c_op_store   : std_logic_vector(6 downto 0) := "0100011";
    constant c_op_alu_imm : std_logic_vector(6 downto 0) := "0010011";
    constant c_op_alu_reg : std_logic_vector(6 downto 0) := "0110011";
    constant c_op_fence   : std_logic_vector(6 downto 0) := "0001111";
    constant c_op_system  : std_logic_vector(6 downto 0) := "1110011";
    
begin  -- architecture behavioral

    -- assign entity outputs
    decoded <= decode;

    -- purpose: decode the MIPS32 instruction
    -- type   : combinational
    -- inputs : insn
    -- outputs: decode
    decode_proc : process (insn) is
        variable opcode : std_logic_vector(6 downto 0);
        variable funct3 : std_logic_vector(2 downto 0);
        variable decode : decoded_t := c_decoded_reset;
    begin  -- process decode_proc
        -- important fields
        opcode := insn(6 downto 0);
        funct3 := insn(14 downto 12);
        decode.rs1    := insn(19 downto 15);
        decode.rs2    := insn(24 downto 20);
        decode.rd     := insn(11 downto 7);

        case (opcode) is
            when c_op_lui =>
                decode.insn_type := OP_LUI;

            when c_op_auipc =>
                decode.insn_type := OP_AUIPC;

            when c_op_jal =>
                decode.insn_type := OP_JAl;
                decode.imm_type  := IMM_UJ;

            when c_op_jalr =>
                decode.insn_type := OP_JALR;
                decode.imm_type  := IMM_I;
                
            when c_op_branch =>
                decode.insn_type := OP_BRANCH;
                decode.imm_type  := IMM_SB;

                case (funct3) is
                    when "000" => decode.branch_type := BEQ;
                    when "001" => decode.branch_type := BNE;
                    when "100" => decode.branch_type := BLT;
                    when "101" => decode.branch_type := BGE;
                    when "110" => decode.branch_type := BLTU;
                    when "111" => decode.branch_type := BGEU;
                end case;
                
            when c_op_load =>
                decode.insn_type := OP_LOAD;
                decode.imm_type  := IMM_I;

                case (funct3) is
                    when "000" => decode.load_type := LB;
                    when "001" => decode.load_type := LH;
                    when "010" => decode.load_type := LW;
                    when "100" => decode.load_type := LBU;
                    when "101" => decode.load_type := LHU;
                end case;

            when c_op_store =>
                decode.insn_type := OP_STORE;
                decode.imm_type  := IMM_S;

                case (funct3) is
                    when "000" => decode.store_type := SB;
                    when "001" => decode.store_type := SH;
                    when "010" => decode.store_type := SW;
                end case;

            when c_op_alu_imm =>
                decode.insn_type := OP_ALU;
                decode.imm_type  := IMM_I;

                case (funct3) is
                    when "000" => decode.alu_func := ALU_ADD;
                    when "001" => decode.alu_func := ALU_SLL;
                    when "010" => decode.alu_func := ALU_SLT;
                    when "011" => decode.alu_func := ALU_SLTU;
                    when "100" => decode.alu_func := ALU_XOR;
                    when "110" => decode.alu_func := ALU_OR;
                    when "111" => decode.alu_func := ALU_AND;
                    when "101" =>
                        if (insn(30) = '1') then
                            decode.alu_func := ALU_SRA;
                        else
                            decode.alu_func := ALU_SRL;
                        end if;

                    when others => null;
                end case;

            when c_op_alu_reg =>
                decode.insn_type := OP_ALU;

                case (funct3) is
                    when "000" =>
                        if (insn(30) = '1') then
                            decode.alu_func := ALU_SUB;
                        else
                            decode.alu_func := ALU_ADD;
                        end if;
                    when "001" => decode.alu_func := ALU_SLL;
                    when "010" => decode.alu_func := ALU_SLT;
                    when "011" => decode.alu_func := ALU_SLTU;
                    when "100" => decode.alu_func := ALU_XOR;
                    when "101" =>
                        if (insn(30) = '1') then
                            decode.alu_func := ALU_SRA;
                        else
                            decode.alu_func := ALU_SRL;
                        end if;
                    when "110" => decode.alu_func := ALU_OR;
                    when "111" => decode.alu_func := ALU_AND;
                end case;

--            when c_op_fence =>
--                insn_type := OP_FENCE;
                
        end case;

        decoded <= decode;
        
    end process decode_proc;

end architecture behavioral;
