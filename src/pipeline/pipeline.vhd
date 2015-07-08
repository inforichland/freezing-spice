-------------------------------------------------------------------------------
-- Title      : 5-stage RISCV integer pipeline
-- Project    : Freezing Spice
-------------------------------------------------------------------------------
-- File       : pipeline.vhd
-- Author     :   Tim Wawrzynczak
-- Created    : 2015-07-07
-- Last update: 2015-07-08
-- Platform   : FPGA
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: RV32I 5-stage ("classic MIPS") pipeline:
--   Instruction Fetch
--   Instruction Decode
--   Instruction Execute
--   Memory Access
--   Register File Writeback
-------------------------------------------------------------------------------
-- Copyright (c) 2015 
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- TODO:
--  - LUI
--  - AUIPC
--  - verify:
--    JALR
--    Branches
--    integer ops
--  - CSR
--  - Fences
--  - SCALL, SBREAK
-------------------------------------------------------------------------------


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
    signal id_ex_pc          : word                         := (others => '0');
    signal id_ex_rs1_addr    : std_logic_vector(4 downto 0) := (others => '0');
    signal id_ex_rs2_addr    : std_logic_vector(4 downto 0) := (others => '0');
    signal id_ex_op1         : word                         := (others => '0');
    signal id_ex_op2         : word                         := (others => '0');
    signal id_ex_ir          : word                         := NOP;
    signal id_ex_imm         : word                         := (others => '0');
    signal id_ex_insn_type   : insn_type_t                  := OP_ILLEGAL;
    signal id_ex_use_imm     : std_logic                    := '0';
    signal id_ex_alu_func    : alu_func_t                   := ALU_NONE;
    signal id_ex_branch_type : branch_type_t                := BRANCH_NONE;
    signal id_ex_rd_addr     : std_logic_vector(4 downto 0) := (others => '0');
    signal id_ex_load_type   : load_type_t                  := LOAD_NONE;
    signal id_ex_store_type  : store_type_t                 := STORE_NONE;
    signal id_ex_rf_we       : std_logic                    := '0';

    -------------------------------------------------
    -- EX signals
    -------------------------------------------------
    signal ex_d : ex_in;
    signal ex_q : ex_out;

    -------------------------------------------------
    -- EX/MEM pipeline registers
    -------------------------------------------------
    signal ex_mem_load_pc        : std_logic                    := '0';
    signal ex_mem_next_pc        : word                         := (others => '0');
    signal ex_mem_rf_data        : word                         := (others => '0');
    signal ex_mem_return_addr    : word                         := (others => '0');
    signal ex_mem_pc             : word                         := (others => '0');
    signal ex_mem_load_type      : load_type_t                  := LOAD_NONE;
    signal ex_mem_store_type     : store_type_t                 := STORE_NONE;
    signal ex_mem_rd_addr        : std_logic_vector(4 downto 0) := (others => '0');
    signal ex_mem_imm            : word                         := (others => '0');
    signal ex_mem_insn_type      : insn_type_t                  := OP_ILLEGAL;
    signal ex_mem_rf_we          : std_logic                    := '0';
    signal ex_mem_compare_result : std_logic;
    signal ex_mem_data_addr      : word                         := (others => '0');
    signal ex_mem_data_out       : word                         := (others => '0');

    -------------------------------------------------
    -- MEM signals
    -------------------------------------------------
    signal mem_we        : std_logic;
    signal mem_re        : std_logic;
    signal mem_data_addr : word;
    signal mem_data_out  : word;

    -------------------------------------------------
    -- MEM/WB pipeline registers
    -------------------------------------------------
    signal mem_wb_rd_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal mem_wb_rf_we   : std_logic                    := '0';
    signal mem_wb_rf_data : word                         := (others => '0');

    -------------------------------------------------
    -- WB signals
    -------------------------------------------------
    signal wb_rf_wr_addr : std_logic_vector(4 downto 0);
    signal wb_rf_wr_en   : std_logic;
    signal wb_rf_wr_data : word;

    -------------------------------------------------
    -- Stalling
    -------------------------------------------------
    signal branch_stall : std_logic;
    signal hazard_stall : std_logic;
    signal if_kill      : std_logic;
    signal id_kill      : std_logic;
    signal id_stall     : std_logic;
    signal full_stall   : std_logic;
    
begin  -- architecture Behavioral

    -------------------------------------------------
    -- Detect when stalling is necessary
    -------------------------------------------------
    branch_stall <= '1' when (id_ex_insn_type = OP_JAL or id_ex_insn_type = OP_JALR or
                              (id_ex_insn_type = OP_BRANCH and ex_q.compare_result = '1')) else '0';
    id_stall   <= hazard_stall or branch_stall;
    if_kill    <= ex_mem_load_pc or (not insn_valid);
    id_kill    <= ex_mem_load_pc;
    full_stall <= '0';

    -- Determine when to stall the pipeline because of structural hazards
    hazard_stall <= '1' when (((id_ex_rd_addr = id_q.rs1) and (id_q.rs1 /= "00000") and (id_ex_rf_we = '1') and (id_q.rs1_rd = '1'))
                              or ((ex_mem_rd_addr = id_q.rs1) and (id_q.rs1 /= "00000") and (ex_mem_rf_we = '1') and (id_q.rs1_rd = '1'))
                              or ((mem_wb_rd_addr = id_q.rs1) and (id_q.rs1 /= "00000") and (mem_wb_rf_we = '1') and (id_q.rs1_rd = '1'))
                              or ((id_ex_rd_addr = id_q.rs2) and (id_q.rs2 /= "00000") and (id_ex_rf_we = '1') and (id_q.rs2_rd = '1'))
                              or ((ex_mem_rd_addr = id_q.rs2) and (id_q.rs2 /= "00000") and (ex_mem_rf_we = '1') and (id_q.rs2_rd = '1'))
                              or ((mem_wb_rd_addr = id_q.rs2) and (id_q.rs2 /= "00000") and (mem_wb_rf_we = '1') and (id_q.rs2_rd = '1'))
                              or ((ex_mem_insn_type = OP_LOAD) and (id_ex_rd_addr = id_q.rs1) and (id_ex_rd_addr /= "00000") and (id_q.rs1_rd = '1'))
                              or ((ex_mem_insn_type = OP_LOAD) and (id_ex_rd_addr = id_q.rs2) and (id_ex_rd_addr /= "00000") and (id_q.rs2_rd = '1')))
                    else '0';

    ---------------------------------------------------
    -- Instruction fetch
    ---------------------------------------------------

    -- inputs
    if_d.stall   <= ex_mem_load_pc or hazard_stall or branch_stall;
    if_d.load_pc <= ex_mem_load_pc;
    if_d.next_pc <= ex_mem_next_pc;

    -- outputs
    insn_addr    <= if_q.fetch_addr;
    data_read_en <= '1' when id_ex_insn_type = OP_LOAD else '0';

    -- instantiation
    if_stage : entity work.instruction_fetch(Behavioral)
        port map (clk, rst_n, if_d, if_q);

    -------------------------------------------------
    -- IF/ID pipeline registers
    -------------------------------------------------

    if_id_reg_proc : process (clk, rst_n) is
    begin  -- process if_id_reg_proc
        if (rst_n = '0') then           -- asynchronous reset (active low)
            if_id_ir <= NOP;
            if_id_pc <= (others => '0');
        elsif (rising_edge(clk)) then
            if (id_stall = '0' and full_stall = '0') then
                if (if_kill = '1') then
                    if_id_ir <= NOP;
                else
                    if_id_ir <= insn_in;
                end if;

                if_id_pc <= if_q.pc;
                
            end if;
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
                  addrw => wb_rf_wr_addr,
                  dataw => wb_rf_wr_data,
                  we    => wb_rf_wr_en);

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
            id_ex_ir       <= NOP;
        elsif (rising_edge(clk)) then
            if (id_stall = '0' and full_stall = '0') then
                id_ex_rs1_addr <= id_q.rs1;
                id_ex_rs2_addr <= id_q.rs2;
                id_ex_op1      <= rs1_data;
                id_ex_op2      <= rs2_data;
                id_ex_use_imm  <= id_q.use_imm;

                if (id_kill = '1') then
                    id_ex_ir          <= NOP;
                    id_ex_rd_addr     <= (others => '0');
                    id_ex_insn_type   <= OP_ILLEGAL;
                    id_ex_rf_we       <= '0';
                    id_ex_use_imm     <= '0';
                    id_ex_imm         <= (others => '0');
                    id_ex_alu_func    <= ALU_NONE;
                    id_ex_branch_type <= BRANCH_NONE;
                    id_ex_load_type   <= LOAD_NONE;
                    id_ex_store_type  <= STORE_NONE;
                else
                    id_ex_pc          <= if_id_pc;
                    id_ex_ir          <= if_id_ir;
                    id_ex_rd_addr     <= id_q.rd;
                    id_ex_insn_type   <= id_q.insn_type;
                    id_ex_rf_we       <= id_q.rf_we;
                    id_ex_use_imm     <= id_q.use_imm;
                    id_ex_imm         <= id_q.imm;
                    id_ex_alu_func    <= id_q.alu_func;
                    id_ex_branch_type <= id_q.branch_type;
                    id_ex_load_type   <= id_q.load_type;
                    id_ex_store_type  <= id_q.store_type;
                end if;
            elsif (id_stall = '1' and full_stall = '0') then
                id_ex_ir          <= NOP;
                id_ex_rd_addr     <= (others => '0');
                id_ex_insn_type   <= OP_ILLEGAL;
                id_ex_rf_we       <= '0';
                id_ex_use_imm     <= '0';
                id_ex_imm         <= (others => '0');
                id_ex_alu_func    <= ALU_NONE;
                id_ex_branch_type <= BRANCH_NONE;
                id_ex_load_type   <= LOAD_NONE;
                id_ex_store_type  <= STORE_NONE;
            end if;
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
    ex_d.imm         <= id_ex_imm;

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
            ex_mem_load_pc     <= '0';
            ex_mem_next_pc     <= (others => '0');
            ex_mem_rf_data     <= (others => '0');
            ex_mem_return_addr <= (others => '0');
            ex_mem_pc          <= (others => '0');
            ex_mem_load_type   <= LOAD_NONE;
            ex_mem_store_type  <= STORE_NONE;
            ex_mem_rd_addr     <= (others => '0');
            ex_mem_imm         <= (others => '0');
            ex_mem_insn_type   <= OP_ILLEGAL;
            ex_mem_rf_we       <= '0';
        elsif (rising_edge(clk)) then
            -- check for branches
            if (id_ex_insn_type = OP_JAL or id_ex_insn_type = OP_JALR or
                (id_ex_insn_type = OP_BRANCH and ex_q.compare_result = '1')) then
                ex_mem_load_pc <= '1';
                ex_mem_next_pc <= ex_q.alu_result;
            else
                ex_mem_load_pc <= '0';
            end if;

            -- return address for JAL/JALR
            if (id_ex_insn_type = OP_JAL or id_ex_insn_type = OP_JALR) then
                ex_mem_rf_data <= ex_q.return_addr;
            else
                ex_mem_rf_data <= ex_q.alu_result;
            end if;

            -- memory address for loads / stores
            if (id_ex_insn_type = OP_LOAD or id_ex_insn_type = OP_STORE) then
                ex_mem_data_addr <= ex_q.alu_result;
            end if;

            ex_mem_data_out   <= id_ex_op2;
            ex_mem_pc         <= id_ex_pc;
            ex_mem_load_type  <= id_ex_load_type;
            ex_mem_store_type <= id_ex_store_type;
            ex_mem_rd_addr    <= id_ex_rd_addr;
            ex_mem_imm        <= id_ex_imm;
            ex_mem_insn_type  <= id_ex_insn_type;
            ex_mem_rf_we      <= id_ex_rf_we;
        end if;
    end process ex_mem_regs_proc;

    ---------------------------------------------------
    -- Memory stage
    ---------------------------------------------------

    -- TODO! loads and stores

    -- memory access logic
    mem_we        <= '1' when ex_mem_insn_type = OP_STORE else '0';
    mem_re        <= '1' when ex_mem_insn_type = OP_LOAD  else '0';
    mem_data_addr <= ex_mem_data_addr;
    mem_data_out  <= ex_mem_data_out;

    ---------------------------------------------------
    -- MEM/WB pipeline registers
    ---------------------------------------------------

    -- purpose: Create the MEM/WB pipeline registers
    mem_wb_regs : process (clk, rst_n) is
    begin  -- process mem_wb_regs
        if (rst_n = '0') then           -- asynchronous reset (active low)
            mem_wb_rd_addr <= (others => '0');
            mem_wb_rf_we   <= '0';
            mem_wb_rf_data <= (others => '0');
        elsif (rising_edge(clk)) then
            mem_wb_rd_addr <= ex_mem_rd_addr;
            mem_wb_rf_we   <= ex_mem_rf_we;
            mem_wb_rf_data <= ex_mem_rf_data;
        end if;
    end process mem_wb_regs;

    ---------------------------------------------------
    -- Writeback stage
    ---------------------------------------------------
    wb_rf_wr_addr <= mem_wb_rd_addr;
    wb_rf_wr_en   <= mem_wb_rf_we;
--    wb_rf_wr_data <= mem_wb_regs_lmd when (mem_wb_regs_insn_type = OP_LOAD) else mem_wb_regs_alu_output;
    wb_rf_wr_data <= mem_wb_rf_data;

end architecture Behavioral;
