library ieee;
use ieee.std_logic_1164.all;

use work.decode_pkg.all;
use work.common.all;

entity riscv_decoder_tb is
end entity riscv_decoder_tb;

architecture testbench of riscv_decoder_tb is
    -- inputs
    signal insn : word;
    -- outputs
    signal decoded : decoded_t;
begin  -- architecture test

    -- purpose: provide stimulus and verification of riscv_decoder
    -- type   : combinational
    -- inputs : 
    -- outputs: asserts
    stimulus_proc: process is
    begin  -- process stimulus_proc

        -- LUI
        insn <= "01010101010101010101111110110111";
        wait for 1 us;
        assert decode.insn_type = OP_LUI report "Expecting LUI" severity error;
        assert decode.imm = "010101010101010101010000000000" report "Invalid Immediate Value (LUI)" severity error;

        -- AUIPC
        insn <= "10 1010101010 1010101010 1010010111";
        wait for 1 us;
        assert decode.insn_type = OP_AUIPC report "Expecting AUIPC" severity error;
        assert decode.imm = "" report "Invalid immediate (AUIPC)" severity error;

        -- JAL 11111111111110101010010101010100
        insn <= "11010101010010101010010101101111";
        wait for 1 us;
        assert decode.insn_type = OP_JAL report "Expecting JAL" severity error;
        assert decode.imm = "11111111111110101010010101010100" report "Invalid immediate (JAL)" severity error;

        -- @TODO etc.
        
    end process stimulus_proc;
    
end architecture test;
