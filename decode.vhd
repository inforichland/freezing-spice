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
        variable decode : decoded_t;
    begin  -- process decode_proc
        -- defaults & important fields
        decode     := c_decoded_reset;
        opcode     := insn(6 downto 0);
        funct3     := insn(14 downto 12);
        decode.rs1 := insn(19 downto 15);
        decode.rs2 := insn(24 downto 20);
        decode.rd  := insn(11 downto 7);

        case (opcode) is
            -- Load Upper Immediate
            when c_op_lui =>
                decode.insn_type := OP_LUI;
                decode.imm_type := IMM_U;

            -- Add Upper Immediate to PC
            when c_op_auipc =>
                decode.insn_type := OP_AUIPC;
                decode.imm_type := IMM_U;

            -- Jump And Link
            when c_op_jal =>
                decode.insn_type := OP_JAl;
                decode.imm_type  := IMM_J;

            -- Jump And Link Register
            when c_op_jalr =>
                decode.insn_type := OP_JALR;
                decode.imm_type  := IMM_I;

            -- Branch to target address, if condition is met
            when c_op_branch =>
                decode.insn_type := OP_BRANCH;
                decode.imm_type  := IMM_B;

                case (funct3) is
                    when "000" => decode.branch_type := BEQ;
                    when "001" => decode.branch_type := BNE;
                    when "100" => decode.branch_type := BLT;
                    when "101" => decode.branch_type := BGE;
                    when "110" => decode.branch_type := BLTU;
                    when "111" => decode.branch_type := BGEU;
                end case;

            -- load data from memory
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

            -- store data to memory
            when c_op_store =>
                decode.insn_type := OP_STORE;
                decode.imm_type  := IMM_S;

                case (funct3) is
                    when "000" => decode.store_type := SB;
                    when "001" => decode.store_type := SH;
                    when "010" => decode.store_type := SW;
                end case;

            -- perform computation with immediate value and a register
            when c_op_imm =>
                decode.insn_type := OP_ALU;
                decode.imm_type  := IMM_I;
                decode.op2_src   := OP2_IMM;

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

            -- perform computation with two register values
            when c_op_reg =>
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

                -- @TODO other instructions
                --when c_op_misc_mem =>
                --    insn_type := OP_FENCE;
                --when c_op_system =>
                --    insn_type := OP_SYSTEM;
                
        end case;

        -- decode and sign-extend the immediate value
        case decode.imm_type is
            when IMM_I  => decode.imm := (31 downto 11 => insn(31), inst(30 downto 25), inst(24 downto 21), inst(20));
            when IMM_S  => decode.imm := (31 downto 11 => insn(31), inst(30 downto 25), inst(11 downto 8), inst(7));
            when IMM_B  => decode.imm := (31 downto 12 => insn(31), inst(7), inst(30 downto 25), inst(11 downto 8), '0');
            when IMM_U  => decode.imm := (inst(31), inst(30 downto 20), inst(19 downto 12), 12 downto 0 => '0');
            when IMM_J  => decode.imm := (31 downto 20 => insn(31), inst(19 downto 12), inst(20), inst(30 downto 25), insn(24 downto 21), '0');
            when others => decode.imm := (others => '0');
        end case;
        
    end process decode_proc;

end architecture behavioral;
