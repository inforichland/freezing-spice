library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;
use work.decode_pkg.all;

entity pipeline is
    generic (g_initial_pc : unsigned(31 downto 0) := (others => '0'));
    port (clk            : in  std_logic;
          rst_n          : in  std_logic;
          insn_in        : in  word;
          insn_valid     : in  std_logic;
          data_in        : in  word;
          data_in_valid  : in  std_logic;
          data_out       : out word;
          data_out_valid : out std_logic);
end entity;

architecture Behavioral of pipeline is
    -- constants
    constant c_op_alu    : std_logic_vector(2 downto 0) := "001";  -- ALU instruction
    constant c_op_load   : std_logic_vector(2 downto 0) := "100";  -- load instruction
    constant c_op_store  : std_logic_vector(2 downto 0) := "101";  -- store instruction
    constant c_op_branch : std_logic_vector(2 downto 0) := "000";  -- branch instruction

    -- architectural registers
    signal pc : unsigned(31 downto 0) := g_initial_pc;  -- Program Counter

    -- pipeline registers
    signal if_id_regs : if_id_regs_t := c_if_id_regs_reset;
    signal id_ex_regs : id_ex_regs_t := c_id_ex_regs_reset;

    -- IF signals
    signal next_pc : unsigned(31 downto 0);

    -- ID signals
    signal id_decoded               : decoded_t;
    signal id_imm                   : word;
    signal id_rs1_data, id_rs2_data : word;
    signal id_rs1_addr, id_rs2_addr : std_logic_vector(4 downto 0);

    -- EX signals
    signal ex_opcode     : std_logic_vector(2 downto 0);
    signal ex_a          : word;
    signal ex_b          : word;
    signal ex_alu_output : word;

    -- MEM signals
    signal mem_branch_taken : std_logic;
    signal mem_branch_addr  : word;
begin

    -----------------------------
    -----------------------------
    -- Instruction fetch stage --
    -----------------------------
    -----------------------------

    -- decide on the next PC
    next_pc <= (pc + 4) when (mem_branch_taken = '1') else unsigned(mem_branch_addr);

    -- purpose: create the PC register
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: pc
    pc_proc : process (clk, rst_n) is
    begin  -- process pc_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            g_initial_pc <= (others => '0');
        elsif rising_edge(clk) then
            pc <= next_pc;
        end if;
    end process pc_proc;

    -- purpose: Create the IF/ID pipeline registers
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: if_id_regs
    if_id_regs_proc : process (clk, rst_n) is
    begin  -- process if_id_regs_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            if_id_regs <= c_if_id_regs_reset;
        elsif rising_edge(clk) then     -- rising clock edge
            if (insn_valid = '1') then
                if_id_regs.ir  <= insn_in;
                if_id_regs.npc <= next_pc;
            end if;
        end if;
    end process if_id_regs_proc;

    ------------------------------
    ------------------------------
    -- Instruction decode stage --
    ------------------------------
    ------------------------------

    instruction_decoder : entity work.riscv_decoder(Behavioral)
        port map (insn    => if_id_regs.ir,
                  decoded => id_decoded);

    -- extract information from decoder
    id_imm      <= id_decoded.imm;
    id_rs1_addr <= id_decoded.rs1;
    id_rs2_addr <= id_decoded.rs2;
    id_rd_addr  <= id_decoded.rd;

    -- Instantiate the register file
    register_file : entity work.regfile(Behavioral)
        port map (clk   => clk,
                  rst_n => rst_n,
                  addra => id_rs1_addr,
                  addrb => id_rs2_addr,
                  rega  => id_rs1_data,
                  regb  => id_rs2_data,
                  addrw => wb_rd_addr,
                  we    => wb_regfile_we);

    -- purpose: Create the ID/EX pipeline registers
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: id_ex_regs
    id_ex_regs_proc : process (clk, rst_n) is
    begin  -- process id_ex_regs_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            id_ex_regs <= c_id_ex_regs_reset;
        elsif rising_edge(clk) then     -- rising clock edge
            if (insn_valid = '1') then
                id_ex_regs.rs1 <= id_rs1_data;
                id_ex_regs.rs2 <= id_rs2_data;
                id_ex_regs.npc <= if_id_regs.npc;
                id_ex_regs.ir  <= if_id_regs.ir;
                id_ex_regs.imm <= id_imm;
            end if;
        end if;
    end process id_ex_regs_proc;

    -------------------
    -------------------
    -- Execute stage --
    -------------------
    -------------------

    -- extract information from IR
    ex_opcode <= id_ex_regs.ir(31 downto 29);

    -- purpose: choose operands for ALU
    -- type   : combinational
    -- inputs : id_ex_regs
    -- outputs: ex_*
    ops_sel_proc : process (id_ex_regs) is
    begin  -- process ops_sel_proc
        if id_ex_regs.insn_type = OP_ALU then
            ex_op1 <= id_ex_regs.rs1;
            ex_op2 <= id_ex_regs.imm;
        elsif id_ex_regs.insn_type = OP_BRANCH then
            ex_op1 <= id_ex_regs.npc;
            ex_op2 <= id_ex_regs.imm(29 downto 2) & "00";  -- shift left 2
        else
            ex_op1 <= id_ex_regs.rs1;
            ex_op2 <= id_ex_regs.rs2;
        end if;
    end process ops_sel_proc;

    -- instantiate the Arithmetic/Logic Unit
    arithmetic_logic_unit : entity work.alu(Behavioral)
        port map (func   => ex_alu_func,
                  a      => ex_op1,
                  b      => ex_op2,
                  result => ex_alu_output);

    -- check truth of conditionals for branch instructions
    conditionals : entity work.compare_unit(behavioral)
        port map (branch_type    => id_ex_regs.branch_type,
                  op1            => ex_op1,
                  op2            => ex_op2,
                  compare_result => ex_compare_result);

    -- purpose: Create the EX/MEM pipeline registers
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: ex_mem_regs
    ex_mem_regs_proc : process (clk, rst_n) is
    begin  -- process ex_mem_regs_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            ex_mem_regs <= c_ex_mem_regs_reset;
        elsif rising_edge(clk) then     -- rising clock edge
            -- defaults
            ex_mem_regs.ir           <= id_ex_regs.ir;
            ex_mem_regs.branch_taken <= '0';

            if (ex_insn_type = OP_ALU) then
                ex_mem_regs.alu_output <= ex_alu_output;
            elsif ((ex_insn_type = OP_LOAD) or (ex_insn_type = OP_STORE)) then
                ex_mem_regs.alu_output <= ex_alu_output;
                ex_mem_regs.op2        <= id_ex_regs.op2;
            elsif (ex_insn_type = OP_JAL or ex_insn_type = OP_JALR or ex_compare_result = '1') then
                ex_mem_regs.branch_taken = '1';
            end if;
        end if;
    end process ex_mem_regs_proc;


    ------------------
    ------------------
    -- Memory stage --
    ------------------
    ------------------

    mem_branch_taken <= ex_mem_regs.branch_taken;
    mem_branch_addr  <= ex_mem_regs.alu_output;

    -- purpose: create pipeline registers between MEM and WB
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: mem_wb_regs
    mem_wb_regs : process (clk, rst_n) is
    begin  -- process mem_wb_regs
        if rst_n = '0' then             -- asynchronous reset (active low)
            mem_wb_regs <= c_mem_wb_regs_reset;
        elsif rising_edge(clk) then     -- rising clock edge
            -- defaults
            mem_wb_regs.ir         <= ex_mem_regs.ir;
            mem_wb_regs.alu_output <= ex_mem_regs.alu_output;
            mem_wb_regs.rd_en      <= '0';
            mem_wb_regs.wr_en      <= '0';

            if mem_opcode = c_load then
                mem_wb_regs.lmd   <= data_in;
                mem_wb_regs.rd_en <= '1';
            elsif mem_opcode = c_store then
                mem_wb_regs.data_out_addr <= ex_mem_regs.alu_output;
                mem_wb_regs.data_out      <= ex_mem_regs.b;
                mem_wb_regs.wr_en         <= '1';
            end if;
        end if;
    end process mem_wb_regs;

    ---------------------
    ---------------------
    -- Writeback stage --
    ---------------------
    ---------------------

    -- purpose: perform register file writeback
    -- type   : combinational
    -- inputs : mem_wb_regs
    -- outputs: register file signals
    writeback_proc : process (mem_wb_regs) is
    begin  -- process writeback_proc
        if write_to_rd then
            rf_addrw <= mem_wb_regs.ir(RD);
            rf_wdata <= mem_wb_regs.alu_output;
            rf_wr_en <= '1';
        elsif write_to_rt then
            rf_addrw <= mem_wb_regs.ir(RT);
            rf_wdata <= mem_wb_regs.alu_output;
            rf_wr_en <= '1';
        elsif is_load_insn = '1' then
            rf_addrw <= mem_wb_regs.ir(RT);
            rf_wdata <= mem_wb_regs.lmd;
            rf_wr_en <= '1';
        else
            rf_addrw <= (others => '0');
            rf_wdata <= (others => '0');
            rf_wr_en <= '0';
        end if;
    end process writeback_proc;
    
end architecture Behavioral;