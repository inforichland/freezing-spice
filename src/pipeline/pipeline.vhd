library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.common.all;
use work.if_pkg.all;
use work.id_pkg.all;
use work.ex_pkg.all;

entity pipeline is
    generic (g_initial_pc : unsigned(31 downto 0) := (others => '0');
             g_for_sim    : boolean               := false);
    port (clk   : in std_logic;
          rst_n : in std_logic;

          -- Instruction interface
          insn_in    : in  word;
          insn_valid : in  std_logic;
          insn_addr  : out word;

          -- Data interface
          data_in       : in  word;
          data_out      : out word;
          data_addr     : out word;
          data_write_en : out std_logic;
          data_read_en  : out std_logic;
          data_in_valid : in  std_logic);
end entity pipeline;

architecture Behavioral of pipeline is

    -------------------------------------------------
    -- IF signals
    -------------------------------------------------
    signal if_d : if_in;
    signal if_q : if_out;

    -------------------------------------------------
    -- IF/ID pipeline registers
    -------------------------------------------------
    signal if_id_ir : word := (others => '0');
    signal if_id_pc : word := (others => '0');

    -------------------------------------------------
    -- ID signals
    -------------------------------------------------
    signal id_d     : id_in;
    signal id_q     : id_out;
    signal rs1_data : word;
    signal rs2_data : word;

    -------------------------------------------------
    -- ID/EX pipeline registers
    -------------------------------------------------
    signal id_ex_pc       : word                         := (others => '0');
    signal id_ex_rs1_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal id_ex_rs2_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal id_ex_op1      : word                         := (others => '0');
    signal id_ex_op2      : word                         := (others => '0');
    signal id_ex_ir       : word                         := (others => '0');

    -------------------------------------------------
    -- EX signals
    -------------------------------------------------
    signal ex_d : ex_in;
    signal ex_q : ex_out;

    -------------------------------------------------
    -- EX/MEM pipeline registers
    -------------------------------------------------
    
begin  -- architecture Behavioral

    ---------------------------------------------------
    -- Instruction fetch
    ---------------------------------------------------

    -- inputs
    if_d.stall   <= '0';
    if_d.load_pc <= '0';
    if_d.next_pc <= (others => '0');

    -- outputs
    insn_addr <= if_q.fetch_addr;

    -- instantiation
    if_stage : entity work.instruction_fetch(Behavioral)
        port map (clk, rst_n, if_d, if_q);

    -------------------------------------------------
    -- IF/ID pipeline registers
    -------------------------------------------------

    if_id_reg_proc : process (clk, rst_n) is
    begin  -- process if_id_reg_proc
        if (rst_n = '0') then           -- asynchronous reset (active low)
            if_id_ir <= (others => '0');
            if_id_pc <= (others => '0');
        elsif (rising_edge(clk)) then
            if_id_ir <= insn_in;
            if_id_pc <= if_q.pc;
        end if;
    end process if_id_reg_proc;

    ---------------------------------------------------
    -- Instruction decode
    ---------------------------------------------------

    -- register file
    register_file : entity work.regfile(rtl)
        port map (clk   => clk,
                  addra => id_q.rs1,
                  addrb => id_q.rs2,
                  rega  => rs1_data,
                  regb  => rs2_data,
                  addrw => "00000",          --wb_rf_wr_addr,
                  dataw => (others => '0'),  --wb_rf_wr_data,
                  we    => '0');             --wb_rf_wr_en);

    -- inputs
    id_d.instruction <= if_id_ir;

    -- instantiation
    id_stage : entity work.instruction_decoder(Behavioral)
        port map (id_d, id_q);

    ---------------------------------------------------
    -- ID/EX pipeline registers
    ---------------------------------------------------

    id_ex_reg_proc : process (clk, rst_n) is
    begin  -- process id_ex_reg_proc
        if (rst_n = '0') then           -- asynchronous reset (active low)
            id_ex_pc       <= (others => '0');
            id_ex_rs1_addr <= (others => '0');
            id_ex_rs2_addr <= (others => '0');
            id_ex_op1      <= (others => '0');
            id_ex_op2      <= (others => '0');
            id_ex_ir       <= (others => '0');
        elsif (rising_edge(clk)) then   -- rising clock edge
            -- needed for EX stage
            id_ex_pc       <= if_id_pc;
            id_ex_rs1_addr <= id_q.rs1;
            id_ex_rs2_addr <= id_q.rs2;
            id_ex_op1      <= rs1_data;
            id_ex_op2      <= rs2_data;
            id_ex_ir       <= if_id_ir;
            id_ex_insn_type   <= id_q.insn_type;
            id_ex_use_imm     <= id_q.use_imm;
            id_ex_alu_func    <= id_q.alu_func;
            id_ex_branch_type <= id_q.branch_type;

            -- needed for later stages
            id_ex_rd_addr <= id_q.rd; -- destination register address
            id_ex_load_type <= id_q.load_type;
            id_ex_store_type <= id_q.store_type;
        end if;
    end process id_ex_reg_proc;

    ---------------------------------------------------
    -- print instructions as they are issued
    ---------------------------------------------------
    print_decode : if (g_for_sim = true) generate
        print_decode_proc : process (id_ex_ir, id_ex_pc) is
            variable l : line;
        begin  -- process print_decode_proc
            write(l, to_integer(unsigned(id_ex_pc)));
            write(l, string'("  : "));
            write(l, hstr(id_ex_ir));
            writeline(output, l);
        end process print_decode_proc;
    end generate print_decode;

    ---------------------------------------------------
    -- Instruction execution stage
    ---------------------------------------------------

    -- inputs
    ex_d.insn_type   <= id_ex_insn_type;
    ex_d.npc         <= id_ex_pc;
    ex_d.rs1         <= id_ex_op1;
    ex_d.rs2         <= id_ex_op2;
    ex_d.use_imm     <= id_ex_use_imm;
    ex_d.alu_func    <= id_ex_alu_func;
    ex_d.branch_type <= id_ex_branch_type;

    -- instantiation
    ex_stage : entity work.instruction_executor(Behavioral)
        port map (ex_d, ex_q);

    ---------------------------------------------------
    -- EX/MEM pipeline registers
    ---------------------------------------------------

    -- purpose: Pipeline data between EX and MEM stages
    ex_mem_regs_proc : process (clk, rst_n) is
    begin  -- process ex_mem_regs_proc
        if (rst_n = '0') then           -- asynchronous reset (active low)

        elsif (rising_edge(clk)) then

        end if;
    end process ex_mem_regs_proc;
end architecture Behavioral;
