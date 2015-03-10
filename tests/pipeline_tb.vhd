library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;
use work.decode_pkg.all;
use work.encode_pkg.all;

entity pipeline_tb is
end entity pipeline_tb;

architecture testbench of pipeline_tb is
    signal clk   : std_logic := '0';
    signal rst_n : std_logic := '1';

    -- inputs
    signal insn_in       : word      := (others => '0');
    signal insn_addr     : word      := (others => '0');
    signal insn_valid    : std_logic := '0';
    signal data_in       : word      := (others => '0');
    signal data_in_valid : std_logic := '0';

    -- outputs
    signal data_out      : word;
    signal data_write_en : std_logic;
    signal data_read_en  : std_logic;
    signal data_addr     : word;

    signal done         : boolean := false;
    constant clk_period : time    := 10 ns;  -- 100 MHz
begin  -- architecture testbench

    -- create a clock
    clk <= '0' when done else (not clk) after clk_period / 2;

    -- instantiate the unit under test
    uut : entity work.pipeline(Behavioral)
        generic map (
            g_initial_pc => (others => '0'),
            g_for_sim    => true)
        port map (
            clk           => clk,
            rst_n         => rst_n,
            insn_in       => insn_in,
            insn_addr     => insn_addr,
            insn_valid    => insn_valid,
            data_in       => data_in,
            data_out      => data_out,
            data_addr     => data_addr,
            data_write_en => data_write_en,
            data_read_en  => data_read_en,
            data_in_valid => data_in_valid);

    -- purpose: Provide stimulus to test the pipeline
    -- type   : combinational
    stimulus_proc : process is
    begin  -- process stimulus_proc
        -- reset sequence
        println ("Beginning simulation");
        rst_n <= '0';
        println ("in reset");
--        wait for clk_period;
        wait for clk_period * 10;
        rst_n <= '1';
        println ("out of reset");
        
        -- begin stimulus
        insn_valid <= '1';
        insn_in    <= encode_i_type(I_ADDI, "000000000100", 0, 1);
        wait for clk_period;
        println ("Sent first instruction");

        insn_in    <= encode_i_type(I_ADDI, "000000001000", 0, 2);
        wait for clk_period;
        insn_valid <= '0';

        wait for clk_period * 6;

        -- finished with simulation
        ----------------------------------------------------------------
        println("Simulation complete");
        ----------------------------------------------------------------

        done <= true;
        wait;

    end process stimulus_proc;
    
end architecture testbench;
