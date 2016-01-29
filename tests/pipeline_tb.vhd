library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.common.all;
use work.id_pkg.all;
use work.encode_pkg.all;

entity pipeline_tb is
end entity pipeline_tb;

architecture testbench of pipeline_tb is
    signal clk   : std_logic := '0';
    signal rst_n : std_logic := '1';

    -- inputs
    signal insn_in        : word      := (others => '0');
    signal insn_addr      : word      := (others => '0');
    signal insn_valid     : std_logic := '0';
    signal data_in        : word      := (others => '0');
    signal data_in2       : word      := (others => '0');
    signal data_in_valid  : std_logic := '0';
    signal data_in_valid2 : std_logic := '0';

    -- outputs
    signal data_write_en : std_logic;
    signal data_read_en  : std_logic;
    signal data_addr     : word;
    signal data_out      : word;

    -- simulation specific
    signal done         : boolean := false;
    constant clk_period : time    := 10 ns;  -- 100 MHz

    -- data memory
    type ram_t is array(0 to 100) of word;    
    signal ram : ram_t := (0      => "10000000000000001000000010000001",
                           others => (others => '0'));
begin

    instruction_memory : entity work.dpram(rtl)
        generic map (g_data_width => 32,
                     g_addr_width => 7,
                     g_init       => true,
                     g_init_file  => "test1.vec")
        port map (clk    => clk,
                  addr_a => insn_addr(6 downto 0),
                  data_a => (others => '0'),
                  we_a   => '0',
                  q_a    => insn_in,
                  addr_b => (others => '0'),
                  data_b => (others => '0'),
                  we_b   => '0',
                  q_b    => open);

    -- create a clock
    clk <= '0' when done else (not clk) after clk_period / 2;

    -- purpose: data memory
    ram_proc : process (clk, rst_n) is
        variable addr : integer;
    begin
        if rst_n = '0' then
            data_in_valid <= '0';
            data_in_valid2 <= '0';
        elsif rising_edge(clk) then
            data_in_valid <= '0';

            data_in2 <= data_in;
            data_in_valid2 <= data_in_valid;
            
            addr := to_integer(unsigned(data_addr));
            if data_write_en = '1' then
                ram(addr) <= data_out;
            elsif data_read_en = '1' then
                data_in       <= ram(addr);
                data_in_valid <= '1';
            end if;
        end if;
    end process ram_proc;

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
            data_in       => data_in2,
            data_out      => data_out,
            data_addr     => data_addr,
            data_write_en => data_write_en,
            data_read_en  => data_read_en,
            data_in_valid => data_in_valid2);

    -- purpose: Provide stimulus to test the pipeline
    stimulus_proc : process is
        variable i : natural := 0;
    begin  -- process stimulus_proc
        -- reset sequence        
        println ("Beginning simulation");

        -- fill up the instruction memory
        rst_n     <= '0';
        wait for clk_period * 2;
        rst_n <= '1';

        -- begin stimulus
        wait for clk_period;
        insn_valid <= '1';

        -- run for a bit.
        wait for clk_period * 30;

        -- finished with simulation
        ----------------------------------------------------------------
        println("Simulation complete");
        ----------------------------------------------------------------

        done <= true;
        wait;

    end process stimulus_proc;
    
end architecture testbench;
