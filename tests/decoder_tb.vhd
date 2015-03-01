library ieee;
use ieee.std_logic_1164.all;

use work.decode_pkg.all;
use work.common.all;
use work.encode_pkg.all;

entity decoder_tb is
end entity decoder_tb;

architecture testbench of decoder_tb is
    -- inputs
    signal insn : word;
    -- outputs
    signal decoded : decoded_t;
begin  -- architecture test

    uut : entity work.decoder(behavioral)
        port map (insn    => insn,
                  decoded => decoded);
    
    -- purpose: provide stimulus and verification of the RISCV decoder
    -- type   : combinational
    -- inputs : 
    -- outputs: asserts
    stimulus_proc: process is
    begin  -- process stimulus_proc

        -- LUI
        insn <= encode_u_type(U_LUI, "01010101010101010101", "11111");
        wait for 1 ns;
        assert decoded.insn_type = OP_LUI report "Expecting LUI" severity error;
        assert decoded.imm = "01010101010101010101000000000000" report "Invalid Immediate Value (LUI)" severity error;
        assert decoded.rd = "11111" report "Invalid Rd (LUI)" severity error;
        
        -- AUIPC
        insn <= encode_u_type(U_AUIPC, "10101010101010101010", "10101");
        --insn <= "10101010101010101010101010010111";
        wait for 1 ns;
        assert decoded.insn_type = OP_AUIPC report "Expecting AUIPC" severity error;
        assert decoded.imm = "10101010101010101010000000000000" report "Invalid immediate (AUIPC)" severity error;
        assert decoded.rd = "10101" report "Invalid Rd (AUIPC)" severity error;
        
        -- JAL
        insn <= encode_uj_type(UJ_JAL, "11010101001010101010", "01010");
        wait for 1 ns;
        assert decoded.insn_type = OP_JAL report "Expecting JAL" severity error;
        assert decoded.imm = "11111111111110101010010101010100" report "Invalid immediate (JAL)" severity error;
        assert decoded.rd = "01010" report "Invalid Rd (JAL)" severity error;

        -- JALR
        insn <= "11001100110000100000010101100111";
        wait for 1 ns;
        assert decoded.insn_type = OP_JALR report "Expecting JALR" severity error;
        assert decoded.imm = "11111111111111111111110011001100" report "Invalid immediate (JALR)" severity error;

        -- BEQ
--        insn <= "0111000" & 
        
        ----------------------------------------------------------------
        println("Simulation complete");
        ----------------------------------------------------------------

        wait;
        
    end process stimulus_proc;
    
end architecture testbench;
