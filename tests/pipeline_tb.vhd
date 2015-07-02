library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

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

    -- simulation specific
    signal done         : boolean := false;
    constant clk_period : time    := 10 ns;  -- 100 MHz

    -- 0 : 00000000010000000000000010010011   ADDI 4, x0, x1    (400093)
    -- 4 : 00000000100000000000000100010011   ADDI 8, x0, x2    (800113)
    -- 8 : 00000000001000001000000110110011   ADD  x1, x2, x3   (2081B3)
    --12 : 00000000000100011001000110010011   SLLI 1, x3, x4    (119213)
    --16 : 00000100000000000000000001101111   JAL  16, x0       (100006F)
    --20 : 00000000000000000000000000010011   NOP               (13)
    --24 : 00000000000000000000000000010011   NOP
    --28 : 00000000000000000000000000010011   NOP
    --32 : 00000000001100011000000110110011   ADD  x3, x4, x5   (4182B3)
    --36 : 00000000000000000000000000010011   JAL  0, x0        (6F)
    type ram_t is array (0 to 63) of word;
    constant ram : ram_t := (0      => encode_i_type(I_ADDI, "000000000100", 0, 1),
                             4      => encode_i_type(I_ADDI, "000000001000", 0, 2),
                             8      => encode_r_type(R_ADD, 1, 2, 3),
                             12     => encode_i_shift(I_SLLI, "00001", 3, 4),
                             16     => encode_uj_type(UJ_JAL, "00000000000000001000", 6),
                             20     => NOP,
                             24     => NOP,
                             28     => NOP,
                             32     => encode_r_type(R_ADD, 3, 4, 5),
                             36     => encode_uj_type(UJ_JAL, "00000000000000000000", 0),
                             others => NOP);

begin  -- architecture testbench

    -- create a clock
    clk <= '0' when done else (not clk) after clk_period / 2;

    -- purpose: provide 1-wait state RAM
    -- type   : sequential
    ram_proc : process (clk) is
        variable l : line;
    begin  -- process ram_proc
        if rst_n = '0' then
            insn_in    <= (others => '0');
            insn_valid <= '0';
        elsif rising_edge(clk) then            
            if (to_integer(unsigned(insn_addr)) <= to_integer(to_unsigned(36, 32))) then
                insn_in    <= ram(to_integer(unsigned(insn_addr)));
                insn_valid <= '1';
            else
                insn_in    <= (others => '0');
                insn_valid <= '0';
            end if;

            --write(l, to_integer(unsigned(insn_addr)));
            --write(l, string'(" : "));
            --write(l, insn_in);
            --writeline(output, l);
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
            data_in       => data_in,
            data_out      => data_out,
            data_addr     => data_addr,
            data_write_en => data_write_en,
            data_read_en  => data_read_en,
            data_in_valid => data_in_valid);

    -- purpose: Provide stimulus to test the pipeline
    -- type   : combinational
    stimulus_proc : process is
        variable l : line;
    begin  -- process stimulus_proc
        -- reset sequence        
        println ("Beginning simulation");

        rst_n <= '0';
        wait for clk_period * 5;
        rst_n <= '1';

        -- begin stimulus
        wait for clk_period * 15;

        -- finished with simulation
        ----------------------------------------------------------------
        println("Simulation complete");
        ----------------------------------------------------------------

        done <= true;
        wait;

    end process stimulus_proc;
    
end architecture testbench;
