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
    signal insn_in       : word      := (others => '0');
    signal insn_addr     : word      := (others => '0');
    signal insn_valid    : std_logic := '0';
    signal data_in       : word      := (others => '0');
    signal data_in_valid : std_logic := '0';

    -- outputs
    signal data_write_en : std_logic;
    signal data_read_en  : std_logic;
    signal data_addr     : word;
    signal data_out      : word;

    -- simulation specific
    signal done         : boolean := false;
    constant clk_period : time    := 10 ns;  -- 100 MHz

    -- the program memory
    type ram_t is array(0 to 100) of word;
    constant rom : ram_t := (0      => encode_i_type(I_ADDI, "000000000100", 0, 1),        -- ADDI x0, x1, 4
                             4      => encode_i_type(I_ADDI, "000000001000", 0, 2),        -- ADDI x0, x2, 8
                             8      => encode_r_type(R_ADD, 1, 2, 3),                      -- ADD x1, x2, x3
                             12     => encode_u_type(U_LUI, "10000000000000000001", 4),    -- LUI 0x80001, x4
                             16     => encode_uj_type(UJ_JAL, "00000000000000010010", 6),  -- JAL 18, x6
                             20     => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                             24     => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                             28     => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                             32     => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                             36     => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                             40     => NOP,
                             44     => NOP,
                             48     => NOP,
                             52     => encode_r_type(R_ADD, 3, 4, 5),                      -- ADD x3, x4, x5
                             56     => encode_u_type(U_AUIPC, "10000000000000000001", 8),  -- AUIPC 0x80001, x8
                             -- should store the value in x8 into address 8 (offset 4 + value in x1 (4))
                             60     => encode_s_type(S_SW, "000000000100", 1, 8),          -- SW x1, x8, 4
                             -- load the halfword value that was just stored (into address 8) into register 9
                             64     => encode_i_type(I_LH, "000000001000", 0, 9),          -- LH x0, x9, 8
                             68     => encode_r_type(R_ADD, 8, 9, 10),                     -- ADD x8, x9, x10
                             -- loop back to the previous address
                             72     => encode_sb_type(SB_BNE, "111111111110", 9, 8),       -- BNE x9, x8, -4
                             76     => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1     -- this should not get executed
                             80     => encode_i_type(I_ADDI, "000000000011", 0, 1),  -- ADDI x0, x1, 3     -- this should not get executed
                             84     => encode_i_type(I_ADDI, "000000000111", 0, 1),  -- ADDI x0, x1, 3     -- this should not get executed
                             88     => encode_i_type(I_ADDI, "000000001111", 0, 1),  -- ADDI x0, x1, 3     -- this should not get executed
                             92     => encode_i_type(I_ADDI, "000000011111", 0, 1),  -- ADDI x0, x1, 3     -- this should not get executed
                             others => NOP);
    
    -- data memory
    signal ram : ram_t := (0      => "10000000000000001000000010000001",
                           others => (others => '0'));

    signal aux_addr : std_logic_vector(6 downto 0) := (others => '0');
    signal aux_in : word;
    signal aux_write : std_logic := '0';
begin

    instruction_memory : entity work.dpram(rtl)
        generic map (g_data_width => 32,
                     g_addr_width => 7,
                     g_init       => false,
                     g_init_file  => "")
        port map (clk    => clk,
                  addr_a => insn_addr(6 downto 0),
                  data_a => (others => '0'),
                  we_a   => '0',
                  q_a    => insn_in,
                  addr_b => aux_addr,
                  data_b => aux_in,
                  we_b   => aux_write,
                  q_b    => open);

    -- create a clock
    clk <= '0' when done else (not clk) after clk_period / 2;

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
            data_in       => data_in,
            data_out      => data_out,
            data_addr     => data_addr,
            data_write_en => data_write_en,
            data_read_en  => data_read_en,
            data_in_valid => data_in_valid);
    
    -- purpose: Provide stimulus to test the pipeline
    -- type   : combinational
    stimulus_proc : process is
        variable i : natural := 0;
    begin  -- process stimulus_proc
        -- reset sequence        
        println ("Beginning simulation");

        -- fill up the instruction memory
        rst_n <= '0';
        aux_write <= '1';
        while i <= ram'high loop
            aux_addr <= std_logic_vector(to_unsigned(i,7));
            aux_in <= rom(i);
            i := i + 4;
            wait for clk_period;
        end loop;
        aux_write <= '0';
        
        wait for clk_period * 2;
        rst_n <= '1';

        wait for clk_period;
        insn_valid <= '1';

        -- begin stimulus
        wait for clk_period * 45;

        -- finished with simulation
        ----------------------------------------------------------------
        println("Simulation complete");
        ----------------------------------------------------------------

        done <= true;
        wait;

    end process stimulus_proc;
    
end architecture testbench;
