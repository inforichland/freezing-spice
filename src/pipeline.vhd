library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;
use work.decode_pkg.all;

entity pipeline is
    generic (g_initial_pc : unsigned(31 downto 0) := (others => '0')
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
end entity;

architecture Behavioral of pipeline is
    -- architectural registers
    signal pc : unsigned(31 downto 0) := g_initial_pc;  -- Program Counter

    -- stall signals
    signal hazard_stall : std_logic;
    signal cache_stall  : std_logic;

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
    signal ex_opcode         : std_logic_vector(2 downto 0);
    signal ex_a              : word;
    signal ex_b              : word;
    signal ex_alu_output     : word;
    signal ex_jump_back_addr : unsigned(31 downto 0);

    -- MEM signals
    signal mem_load_pc       : std_logic;
    signal mem_next_pc_addr  : word;
    signal mem_data_addr     : word;
    signal mem_data_write_en : std_logic;
    signal mem_data_read_en  : std_logic;
    signal mem_data_out      : word;
    signal mem_data_in       : word;
    signal mem_data_in_valid : std_logic;
begin

    -- Assign outputs
    data_read_en <= '1' when id_ex_regs.insn_type = OP_LOAD else '0';

    -- Determine when to stall the pipeline because of structural hazards
    hazard_stall <= '1' when (((id_ex_regs.rd_addr = id_decoded.rs1) and (id_decoded.rs1 /= "00000") and (id_ex_regs.rf_wen = '1') and (id_decoded.rs1_rd = '1'))
                              or ((ex_mem_regs.rd_addr = id_decoded.rs1) and (id_decoded.rs1 /= "00000") and (ex_mem_regs.rf_wen = '1') and (id_decoded.rs1_rd = '1'))
                              or ((mem_wb_regs.rd_addr = id_decoded.rs1) and (id_decoded.rs1 /= "00000") and (mem_wb_regs.rf_wen = '1') and (id_decoded.rs1_rd = '1'))
                              or ((id_ex_regs.rd_addr = id_decoded.rs2) and (id_decoded.rs2 /= "00000") and (id_ex_regs.rf_wen = '1') and (id_decoded.rs2_rd = '1'))
                              or ((ex_mem_regs.rd_addr = id_decoded.rs2) and (id_decoded.rs2 /= "00000") and (ex_mem_regs.rf_wen = '1') and (id_decoded.rs2_rd = '1'))
                              or ((mem_wb_regs.rd_addr = id_decoded.rs2) and (id_decoded.rs2 /= "00000") and (mem_wb_regs.rf_wen = '1') and (id_decoded.rs2_rd = '1'))
                              or ((ex_mem_regs.insn_type = OP_LOAD) and (id_ex_regs.rd_addr = id_decoded.rs1) and (id_ex_regs.rd_addr /= "00000") and (id_decoded.rs1_rd))
                              or ((ex_mem_regs.insn_type = OP_LOAD) and (id_ex_regs.rd_addr = id_decoded.rs2) and (id_ex_regs.rd_addr /= "00000") and (id_decoded.rs2_rd)));



    -----------------------------
    -----------------------------
    -- Instruction fetch stage --
    -----------------------------
    -----------------------------

    -- purpose: create the PC register
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: pc
    pc_proc : process (clk, rst_n) is
    begin  -- process pc_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            g_initial_pc <= (others => '0');
        elsif rising_edge(clk) then
            if (hazard_stall = '0') and (cache_stall = '0') then
                case (next_pc_sel) is
                    when PC_SEQ        => pc <= pc + to_unsigned(4, 32);
                    when PC_BRANCH_JAL => pc <= ex_branch_jal_target;
                    when PC_JALR       => pc <= ex_mem_regs.alu_output;
                    when others        => null;
                end if;
            end if;
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

    -- print some decoded information when simulating
    print_decode : if g_for_sim = true generate
        -- purpose: Print out information about decoded instruction
        -- type   : combinational
        -- inputs : id_decoded
        -- outputs: 
        print_decode_proc : process (id_decoded) is
        begin  -- process print_decode_proc
            print (id_decoded.insn_type);
            print (if_id_regs.ir);
        end process print_decode_proc;
    end generate print_decode;

    instruction_decoder : entity work.riscv_decoder(Behavioral)
        port map (insn    => if_id_regs.ir,
                  decoded => id_decoded);

    register_file : entity work.regfile(Behavioral)
        port map (clk   => clk,
                  rst_n => rst_n,
                  addra => id_rs1_addr,
                  addrb => id_rs2_addr,
                  rega  => id_rs1_data,
                  regb  => id_rs2_data,
                  addrw => wb_rd_addr,
                  we    => wb_regfile_we);

    -- determine if a stall of the ID stage is required
    id_stall <= insn_valid;

    -- purpose: Create the ID/EX pipeline registers
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: id_ex_regs
    id_ex_regs_proc : process (clk, rst_n) is
    begin  -- process id_ex_regs_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            id_ex_regs <= c_id_ex_regs_reset;
        elsif rising_edge(clk) then     -- rising clock edge
            if (id_stall = '0') then
                id_ex_regs.rs1_data    <= id_rs1_data;
                id_ex_regs.rs2_data    <= id_rs2_data;
                id_ex_regs.npc         <= if_id_regs.npc;
                id_ex_regs.alu_func    <= id_decoded.alu_func;
                id_ex_regs.op2_src     <= id_decoded.op2_src;
                id_ex_regs.insn_type   <= id_decoded.insn_type;
                id_ex_regs.branch_type <= id_decoded.branch_type;
                id_ex_regs.load_type   <= id_decoded.load_type;
                id_ex_regs.store_type  <= id_decoded.store_type;
                id_ex_regs.rd_addr     <= id_decoded.rd;
                id_ex_regs.imm         <= id_decoded.imm;
            end if;
        end if;
    end process id_ex_regs_proc;

    -------------------
    -------------------
    -- Execute stage --
    -------------------
    -------------------

    -- the address to write to 'rd' during a JAL or JALR
    ex_jump_back_addr <= unsigned(id_ex_regs.npc) + to_unsigned(4, 3);

    -- choose first operand for ALU
    ex_op1 <= id_ex_regs.npc when (id_ex_regs.insn_type = OP_BRANCH or
                                   id_ex_regs.insn_type = OP_JAL or
                                   id_ex_regs.insn_type = OP_JALR)
              else id_ex_regs.rs1_data;

    -- choose second operand for ALU
    ex_op2 <= id_ex_regs.imm when (id_ex_regs.insn_type = OP_ALU or
                                   id_ex_regs.insn_type = OP_BRANCH or
                                   id_ex_regs.insn_type = OP_JAL or
                                   id_ex_regs.insn_type = OP_JALR)
              else id_ex_regs.rs2_data;

    -- instantiate the Arithmetic/Logic Unit
    arithmetic_logic_unit : entity work.alu(Behavioral)
        port map (func   => id_ex_regs.alu_func,
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
            ex_mem_regs.load_pc <= '0';

            -- pipeline registers
            ex_mem_regs.alu_output     <= ex_alu_output;
            ex_mem_regs.jump_back_addr <= ex_jump_back_addr;
            ex_mem_regs.npc            <= id_ex_regs.npc;
            ex_mem_regs.load_type      <= id_ex_regs.load_type;
            ex_mem_regs.store_type     <= id_ex_regs.store_type;
            ex_mem_regs.rd_addr        <= id_ex_regs.rd_addr;
            ex_mem_regs.imm            <= id_ex_regs.imm;

            if (ex_compare_result = '1' or ex_insn_type = OP_JAL or ex_insn_type = OP_JALR) then
                ex_mem_regs.load_pc = '1';
            end if;
        end if;
    end process ex_mem_regs_proc;


    ------------------
    ------------------
    -- Memory stage --
    ------------------
    ------------------

    mem_load_pc      <= ex_mem_regs.load_pc;
    mem_next_pc_addr <= ex_mem_regs.alu_output;

    -- create memory interface
    mem_data_addr     <= ex_mem_regs.alu_output;
    mem_data_write_en <= '1' when mem_insn_type = OP_STORE else '0';
    mem_data_read_en  <= '1' when mem_insn_type = OP_LOAD  else '0';
    mem_data_out      <= ex_mem_regs.b;
    mem_data_in       <= data_in;
    mem_data_in_valid <= data_in_valid;

    -- purpose: create pipeline registers between MEM and WB
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: mem_wb_regs
    mem_wb_regs : process (clk, rst_n) is
    begin  -- process mem_wb_regs
        if rst_n = '0' then             -- asynchronous reset (active low)
            mem_wb_regs <= c_mem_wb_regs_reset;
        elsif rising_edge(clk) then     -- rising clock edge
            mem_wb_regs.alu_output <= ex_mem_regs.alu_output;
            mem_wb_regs.rf_wr_en   <= ex_mem_regs.rf_wr_en;
            mem_wb_regs.insn_type  <= ex_mem_regs.insn_type;
            mem_wb_regs.rf_wr_addr <= ex_mem_regs.rf_wr_addr;
        end if;
    end process mem_wb_regs;

    ---------------------
    ---------------------
    -- Writeback stage --
    ---------------------
    ---------------------

    rf_wr_addr <= mem_wb_regs.rf_wr_addr;
    rf_wr_en   <= '1' when (mem_wb_regs.insn_type = OP_ALU or mem_wb_regs.insn_type = OP_LOAD) else '0';

    -- purpose: perform register file writeback
    -- type   : combinational
    -- inputs : mem_wb_regs
    -- outputs: register file signals
    writeback_proc : process (mem_wb_regs) is
    begin  -- process writeback_proc
        if wb_insn_type = OP_LOAD then
            rf_addrw <= mem
        end if;

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
