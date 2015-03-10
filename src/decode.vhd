library ieee;
use ieee.std_logic_1164.all;

use work.common.all;
use work.decode_pkg.all;

entity decoder is
    port (insn    : in    word;
          decoded : inout decoded_t);   -- decoded data
end entity decoder;

architecture behavioral of decoder is
    -- Enumerated types
    type imm_type_t is (IMM_NONE, IMM_I, IMM_S, IMM_B, IMM_U, IMM_J);
begin  -- architecture behavioral

    -- purpose: decode the RISCV instruction
    -- type   : combinational
    -- inputs : insn
    -- outputs: decode
    decode_proc : process (insn) is
        variable opcode   : std_logic_vector(6 downto 0);
        variable funct3   : std_logic_vector(2 downto 0);
        variable imm_type : imm_type_t := IMM_NONE;
    begin  -- process decode_proc
        -- defaults & important fields
        opcode             := insn(6 downto 0);
        funct3             := insn(14 downto 12);
        decoded.rs1        <= insn(19 downto 15);
        decoded.rs2        <= insn(24 downto 20);
        decoded.rd         <= insn(11 downto 7);
        decoded.opcode     <= opcode;
        decoded.rs1_rd     <= '0';
        decoded.rs2_rd     <= '0';
        decoded.alu_func   <= ALU_NONE;
        decoded.op2_src    <= '0';
        decoded.insn_type  <= OP_ILLEGAL;
        decoded.load_type  <= LOAD_NONE;
        decoded.store_type <= STORE_NONE;
        decoded.imm        <= (others => '0');
        decoded.rs1_rd     <= '0';
        decoded.rs2_rd     <= '0';
        decoded.use_imm    <= '0';

        case (opcode) is
            -- Load Upper Immediate
            when c_op_lui =>
                decoded.insn_type <= OP_LUI;
                imm_type          := IMM_U;

            -- Add Upper Immediate to PC
            when c_op_auipc =>
                decoded.insn_type <= OP_AUIPC;
                imm_type          := IMM_U;

            -- Jump And Link
            when c_op_jal =>
                decoded.insn_type <= OP_JAL;
                imm_type          := IMM_J;

            -- Jump And Link Register
            when c_op_jalr =>
                decoded.insn_type <= OP_JALR;
                imm_type          := IMM_I;
                decoded.rs1_rd    <= '1';

            -- Branch to target address, if condition is met
            when c_op_branch =>
                decoded.insn_type <= OP_BRANCH;
                imm_type          := IMM_B;
                decoded.rs1_rd    <= '1';
                decoded.rs2_rd    <= '1';

                case (funct3) is
                    when "000"  => decoded.branch_type <= BEQ;
                    when "001"  => decoded.branch_type <= BNE;
                    when "100"  => decoded.branch_type <= BLT;
                    when "101"  => decoded.branch_type <= BGE;
                    when "110"  => decoded.branch_type <= BLTU;
                    when "111"  => decoded.branch_type <= BGEU;
                    when others => null;
                end case;

            -- load data from memory
            when c_op_load =>
                decoded.insn_type <= OP_LOAD;
                imm_type          := IMM_I;
                decoded.rs1_rd    <= '1';

                case (funct3) is
                    when "000"  => decoded.load_type <= LB;
                    when "001"  => decoded.load_type <= LH;
                    when "010"  => decoded.load_type <= LW;
                    when "100"  => decoded.load_type <= LBU;
                    when "101"  => decoded.load_type <= LHU;
                    when others => null;
                end case;

            -- store data to memory
            when c_op_store =>
                decoded.insn_type <= OP_STORE;
                imm_type          := IMM_S;
                decoded.rs1_rd    <= '1';
                decoded.rs2_rd    <= '1';

                case (funct3) is
                    when "000"  => decoded.store_type <= SB;
                    when "001"  => decoded.store_type <= SH;
                    when "010"  => decoded.store_type <= SW;
                    when others => null;
                end case;

            -- perform computation with immediate value and a register
            when c_op_imm =>
                decoded.insn_type <= OP_ALU;
                decoded.op2_src   <= '1';
                imm_type          := IMM_I;
                decoded.rs1_rd    <= '1';
                decoded.use_imm   <= '1';

                case (funct3) is
                    when "000" => decoded.alu_func <= ALU_ADD;
                    when "001" => decoded.alu_func <= ALU_SLL;
                    when "010" => decoded.alu_func <= ALU_SLT;
                    when "011" => decoded.alu_func <= ALU_SLTU;
                    when "100" => decoded.alu_func <= ALU_XOR;
                    when "110" => decoded.alu_func <= ALU_OR;
                    when "111" => decoded.alu_func <= ALU_AND;
                    when "101" =>
                        if (insn(30) = '1') then
                            decoded.alu_func <= ALU_SRA;
                        else
                            decoded.alu_func <= ALU_SRL;
                        end if;

                    when others => null;
                end case;

            -- perform computation with two register values
            when c_op_reg =>
                decoded.insn_type <= OP_ALU;
                decoded.rs1_rd    <= '1';
                decoded.rs2_rd    <= '1';

                case (funct3) is
                    when "000" =>
                        if (insn(30) = '1') then
                            decoded.alu_func <= ALU_SUB;
                        else
                            decoded.alu_func <= ALU_ADD;
                        end if;
                    when "001" => decoded.alu_func <= ALU_SLL;
                    when "010" => decoded.alu_func <= ALU_SLT;
                    when "011" => decoded.alu_func <= ALU_SLTU;
                    when "100" => decoded.alu_func <= ALU_XOR;
                    when "101" =>
                        if (insn(30) = '1') then
                            decoded.alu_func <= ALU_SRA;
                        else
                            decoded.alu_func <= ALU_SRL;
                        end if;
                    when "110"  => decoded.alu_func <= ALU_OR;
                    when "111"  => decoded.alu_func <= ALU_AND;
                    when others => null;
                end case;

                -- @TODO other insnructions
                --when c_op_misc_mem =>
                --    insn_type <= OP_FENCE;
                --when c_op_system =>
                --    insn_type <= OP_SYSTEM;

            when others =>
                decoded.insn_type <= OP_ILLEGAL;
                
        end case;

        -- decode and sign-extend the immediate value
        case imm_type is
            when IMM_I =>
                for i in 31 downto 11 loop
                    decoded.imm(i) <= insn(31);
                end loop;
                decoded.imm(10 downto 5) <= insn(30 downto 25);
                decoded.imm(4 downto 1)  <= insn(24 downto 21);
                decoded.imm(0)           <= insn(20);

            when IMM_S =>
                for i in 31 downto 11 loop
                    decoded.imm(i) <= insn(31);
                end loop;  -- i
                decoded.imm(10 downto 5) <= insn(30 downto 25);
                decoded.imm(4 downto 1)  <= insn(11 downto 8);
                decoded.imm(0)           <= insn(7);

            when IMM_B =>
                for i in 31 downto 13 loop
                    decoded.imm(i) <= insn(31);
                end loop;  -- i
                decoded.imm(12)          <= insn(31);
                decoded.imm(11)          <= insn(7);
                decoded.imm(10 downto 5) <= insn(30 downto 25);
                decoded.imm(4 downto 1)  <= insn(11 downto 8);
                decoded.imm(0)           <= '0';

            when IMM_U =>
                decoded.imm(31)           <= insn(31);
                decoded.imm(30 downto 20) <= insn(30 downto 20);
                decoded.imm(19 downto 12) <= insn(19 downto 12);
                decoded.imm(11 downto 0)  <= (others => '0');

            when IMM_J =>
                for i in 31 downto 20 loop
                    decoded.imm(i) <= insn(31);
                end loop;  -- i
                decoded.imm(19 downto 12) <= insn(19 downto 12);
                decoded.imm(11)           <= insn(20);
                decoded.imm(10 downto 5)  <= insn(30 downto 25);
                decoded.imm(4 downto 1)   <= insn(24 downto 21);
                decoded.imm(0)            <= '0';
                
            when others => decoded.imm <= (others => '0');
        end case;
        
    end process decode_proc;

end architecture behavioral;
