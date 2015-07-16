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

    -- the program memory
    type ram_t is array(0 to 76) of word;
    constant rom : ram_t := (0      => encode_i_type(I_ADDI, "000000000100", 0, 1),             -- ADDI x0, x1, 4
                             4      => encode_i_type(I_ADDI, "000000001000", 0, 2),             -- ADDI x0, x2, 8
                             8      => encode_r_type(R_ADD, 1, 2, 3),                           -- ADD x1, x2, x3
--                             12     => encode_i_shift(I_SLLI, "00001", 3, 4),
                             12     => encode_u_type(U_LUI, "10000000000000000001", 4),         -- LUI 0x80001, x4
                             16     => encode_uj_type(UJ_JAL, "00000000000000010010", 6),       -- JAL 18, x6
                             20     => encode_i_type(I_ADDI, "000000000001", 0, 1),             -- ADDI x0, x1, 1      -- this should not get executed
                             24     => encode_i_type(I_ADDI, "000000000001", 0, 1),             -- ADDI x0, x1, 1      -- this should not get executed
                             28     => encode_i_type(I_ADDI, "000000000001", 0, 1),             -- ADDI x0, x1, 1      -- this should not get executed
                             32     => encode_i_type(I_ADDI, "000000000001", 0, 1),             -- ADDI x0, x1, 1      -- this should not get executed
                             36     => NOP,
                             40     => NOP,
                             44     => NOP,
                             48     => NOP,
                             52     => encode_r_type(R_ADD, 3, 4, 5),                           -- ADD x3, x4, x5
                             56     => encode_u_type(U_AUIPC, "10000000000000000001", 8),       -- AUIPC 0x80001, x8
                             60     => encode_i_type(I_LW, "000000000000", 0, 9),               -- LW x0, x9, 0
                             64     => encode_r_type(R_ADD, 8, 9, 10),                          -- ADD x8, x9, x10
                             68     => encode_uj_type(UJ_JAL, "00000000000000000000", 7),       -- JAL 0, x7
                             72     => encode_i_type(I_ADDI, "000000000001", 0, 1),             -- ADDI x0, x1, 1     -- this should not get executed
                             76     => encode_i_type(I_ADDI, "000000000011", 0, 1),             -- ADDI x0, x1, 3     -- this should not get executed
                             others => NOP);

    -- data memory
    signal ram : ram_t := (0 => "10000000000000000000000000000001",
                           others => (others => '0'));
    
begin  -- architecture testbench

    -- create a clock
    clk <= '0' when done else (not clk) after clk_period / 2;

    -- purpose: instruction memory
    rom_proc : process (clk, rst_n) is
        variable l : line;
    begin  -- process ram_proc
        if rst_n = '0' then
            insn_in    <= (others => '0');
            insn_valid <= '0';
        elsif rising_edge(clk) then
            insn_valid <= '1';

            if (to_integer(unsigned(insn_addr)) <= to_integer(to_unsigned(rom'high, 32))) then
                insn_in <= rom(to_integer(unsigned(insn_addr)));
            else
                insn_in <= NOP;
            end if;
        end if;
    end process rom_proc;

    -- purpose: data memory
    ram_proc : process (clk, rst_n) is
        variable addr : integer;
    begin
        if rst_n = '0' then
            data_in_valid <= '0';
        elsif rising_edge(clk) then
            data_in_valid <= '0';
            
            addr := to_integer(unsigned(data_addr));
            if data_write_en = '1' then
                ram(addr) <= data_out;
            elsif data_read_en = '1' then
                data_in <= ram(addr);
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
        wait for clk_period * 2;
        rst_n <= '1';

        -- begin stimulus
        wait for clk_period * 30;

        -- finished with simulation
        ----------------------------------------------------------------
        println("Simulation complete");
        ----------------------------------------------------------------

        done <= true;
        wait;

    end process stimulus_proc;
    
end architecture testbench;
