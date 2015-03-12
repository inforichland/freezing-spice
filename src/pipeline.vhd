library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.common.all;
use work.decode_pkg.all;
use work.encode_pkg.all;

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
end entity;

architecture Behavioral of pipeline is
    -- constants
    constant PC_SEQ        : std_logic_vector(1 downto 0) := "11";
    constant PC_JALR       : std_logic_vector(1 downto 0) := "01";
    constant PC_BRANCH_JAL : std_logic_vector(1 downto 0) := "10";

    -- pipeline registers between IF and ID stages
    signal if_id_regs_ir  : word                  := (others => '0');
    signal if_id_regs_npc : unsigned(31 downto 0) := (others => '0');

    -- pipeline registers between ID and EX stages
    signal id_ex_regs_rs1_data    : word                         := (others => '0');
    signal id_ex_regs_rs2_data    : word                         := (others => '0');
    signal id_ex_regs_npc         : unsigned(31 downto 0)        := (others => '0');
    signal id_ex_regs_alu_func    : alu_func_t                   := ALU_NONE;
    signal id_ex_regs_op2_src     : std_logic                    := '0';
    signal id_ex_regs_insn_type   : insn_type_t                  := OP_ILLEGAL;
    signal id_ex_regs_branch_type : branch_type_t                := BRANCH_NONE;
    signal id_ex_regs_load_type   : load_type_t                  := LOAD_NONE;
    signal id_ex_regs_store_type  : store_type_t                 := STORE_NONE;
    signal id_ex_regs_rf_wr_addr  : std_logic_vector(4 downto 0) := "00000";
    signal id_ex_regs_imm         : word                         := (others => '0');
    signal id_ex_regs_rf_wr_en    : std_logic                    := '0';
    signal id_ex_regs_use_imm     : std_logic                    := '0';

    -- pipeline registers between EX and MEM stages
    signal ex_mem_regs_jump_addr    : word                         := (others => '0');
    signal ex_mem_regs_lmd          : word                         := (others => '0');
    signal ex_mem_regs_load_pc      : std_logic                    := '0';
    signal ex_mem_regs_npc          : unsigned(31 downto 0)        := (others => '0');
    signal ex_mem_regs_load_type    : load_type_t                  := LOAD_NONE;
    signal ex_mem_regs_store_type   : store_type_t                 := STORE_NONE;
    signal ex_mem_regs_rf_wr_addr   : std_logic_vector(4 downto 0) := "00000";
    signal ex_mem_regs_rf_wr_data   : word                         := (others => '0');
    signal ex_mem_regs_rf_wr_en     : std_logic                    := '0';
    signal ex_mem_regs_imm          : word                         := (others => '0');
    signal ex_mem_regs_alu_output   : word                         := (others => '0');
    signal ex_mem_regs_insn_type    : insn_type_t                  := OP_ILLEGAL;
    signal ex_mem_regs_next_pc_addr : word                         := (others => '0');

    -- pipeline registers between MEM and WB stages
    signal mem_wb_regs_alu_output : word                         := (others => '0');
    signal mem_wb_regs_rf_wr_en   : std_logic                    := '0';
    signal mem_wb_regs_insn_type  : insn_type_t                  := OP_ILLEGAL;
    signal mem_wb_regs_rf_wr_addr : std_logic_vector(4 downto 0) := "00000";
    signal mem_wb_regs_lmd        : word                         := (others => '0');

    -- architectural registers
    signal pc      : unsigned(31 downto 0) := g_initial_pc;  -- Program Counter
    signal next_pc : unsigned(31 downto 0);

    -- stall signals
    signal hazard_stall : std_logic;
    signal cache_stall  : std_logic := '0';

    -- IF signals
    signal next_pc_sel : std_logic_vector(1 downto 0);

    -- ID signals
    signal id_decoded               : decoded_t;
    signal id_rs1_data, id_rs2_data : word;

    -- EX signals
    signal ex_opcode            : std_logic_vector(2 downto 0);
    signal ex_op1               : word;
    signal ex_op2               : word;
    signal ex_alu_output        : word;
    signal ex_jump_addr         : unsigned(31 downto 0);
    signal ex_branch_jal_target : unsigned(31 downto 0);
    signal ex_compare_result    : std_logic;

    -- MEM signals
    signal mem_load_pc       : std_logic;
    signal mem_next_pc_addr  : word;
    signal mem_data_addr     : word;
    signal mem_data_write_en : std_logic;
    signal mem_data_read_en  : std_logic;
    signal mem_data_out      : word;
    signal mem_data_in       : word;
    signal mem_data_in_valid : std_logic;

    -- WB signals
    signal wb_rf_wr_data : word;
    signal wb_rf_wr_addr : std_logic_vector(4 downto 0);
    signal wb_rf_wr_en   : std_logic;
begin

    -- Assign outputs
    data_read_en  <= '1' when id_ex_regs_insn_type = OP_LOAD else '0';
    data_write_en <= mem_data_write_en;
    insn_addr     <= std_logic_vector(pc);

    -- Determine when to stall the pipeline because of structural hazards
    hazard_stall <= '1' when (((id_ex_regs_rf_wr_addr = id_decoded.rs1) and (id_decoded.rs1 /= "00000") and (id_ex_regs_rf_wr_en = '1') and (id_decoded.rs1_rd = '1'))
                               or ((ex_mem_regs_rf_wr_addr = id_decoded.rs1) and (id_decoded.rs1 /= "00000") and (ex_mem_regs_rf_wr_en = '1') and (id_decoded.rs1_rd = '1'))
                              or ((mem_wb_regs_rf_wr_addr = id_decoded.rs1) and (id_decoded.rs1 /= "00000") and (mem_wb_regs_rf_wr_en = '1') and (id_decoded.rs1_rd = '1'))
                              or ((id_ex_regs_rf_wr_addr = id_decoded.rs2) and (id_decoded.rs2 /= "00000") and (id_ex_regs_rf_wr_en = '1') and (id_decoded.rs2_rd = '1'))
                              or ((ex_mem_regs_rf_wr_addr = id_decoded.rs2) and (id_decoded.rs2 /= "00000") and (ex_mem_regs_rf_wr_en = '1') and (id_decoded.rs2_rd = '1'))
                              or ((mem_wb_regs_rf_wr_addr = id_decoded.rs2) and (id_decoded.rs2 /= "00000") and (mem_wb_regs_rf_wr_en = '1') and (id_decoded.rs2_rd = '1'))
                              or ((ex_mem_regs_insn_type = OP_LOAD) and (id_ex_regs_rf_wr_addr = id_decoded.rs1) and (id_ex_regs_rf_wr_addr /= "00000") and (id_decoded.rs1_rd = '1'))
                              or ((ex_mem_regs_insn_type = OP_LOAD) and (id_ex_regs_rf_wr_addr = id_decoded.rs2) and (id_ex_regs_rf_wr_addr /= "00000") and (id_decoded.rs2_rd = '1')))
                    else '0';

    -----------------------------
    -----------------------------
    -- Instruction fetch stage --
    -----------------------------
    -----------------------------

    next_pc_sel <= PC_BRANCH_JAL when (ex_mem_regs_load_pc = '1' and (ex_mem_regs_insn_type = OP_BRANCH or ex_mem_regs_insn_type = OP_JAL)) else
                   PC_JALR when (ex_mem_regs_load_pc = '1' and ex_mem_regs_insn_type = OP_JALR) else
                   PC_SEQ;

    next_pc <= pc + to_unsigned(4, 32) when next_pc_sel = PC_SEQ else
               unsigned(ex_mem_regs_next_pc_addr) when next_pc_sel = PC_BRANCH_JAL else
               ex_branch_jal_target               when next_pc_sel = PC_JALR else
               pc;

    -- purpose: create the PC register
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: pc
    pc_proc : process (clk, rst_n) is
    begin  -- process pc_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            pc <= g_initial_pc;
        elsif rising_edge(clk) then
            if (hazard_stall = '0') and (cache_stall = '0') then
                pc <= next_pc;
            end if;
        end if;
    end process pc_proc;

    --purpose: Create the IF/ID pipeline registers
    --type   : sequential
    --inputs : clk, rst_n
    --outputs: if_id_regs
    if_id_regs_proc : process (clk, rst_n) is
    begin  -- process if_id_regs_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            if_id_regs_ir  <= NOP;
            if_id_regs_npc <= (others => '0');
        elsif rising_edge(clk) then     -- rising clock edge
            if (hazard_stall = '0') and (cache_stall = '0') then
                -- determine when to insert a pipeline bubble
                if ((id_ex_regs_insn_type = OP_BRANCH) or (id_ex_regs_insn_type = OP_JAL) or (id_ex_regs_insn_type = OP_JALR) or (insn_valid = '0')) then
                    if_id_regs_ir <= NOP;
                else
                    if_id_regs_ir <= insn_in;
                end if;

                -- pipeline the PC
                if_id_regs_npc <= pc;
            end if;
        end if;
    end process if_id_regs_proc;

    ------------------------------
    ------------------------------
    -- Instruction decode stage --
    ------------------------------
    ------------------------------

    instruction_decoder : entity work.decoder(Behavioral)
        port map (insn    => if_id_regs_ir,
                  decoded => id_decoded);

    register_file : entity work.regfile(rtl)
        port map (clk   => clk,
                  addra => id_decoded.rs1,
                  addrb => id_decoded.rs2,
                  rega  => id_rs1_data,
                  regb  => id_rs2_data,
                  addrw => wb_rf_wr_addr,
                  dataw => wb_rf_wr_data,
                  we    => wb_rf_wr_en);

    -- purpose: Create the ID/EX pipeline registers
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: id_ex_regs
    id_ex_regs_proc : process (clk, rst_n) is
    begin  -- process id_ex_regs_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            id_ex_regs_rf_wr_en    <= '0';
            id_ex_regs_rs1_data    <= (others => '0');
            id_ex_regs_rs2_data    <= (others => '0');
            id_ex_regs_npc         <= (others => '0');
            id_ex_regs_alu_func    <= ALU_NONE;
            id_ex_regs_op2_src     <= '0';
            id_ex_regs_insn_type   <= OP_ILLEGAL;
            id_ex_regs_branch_type <= BRANCH_NONE;
            id_ex_regs_load_type   <= LOAD_NONE;
            id_ex_regs_store_type  <= STORE_NONE;
            id_ex_regs_imm         <= (others => '0');
            id_ex_regs_rf_wr_addr  <= (others => '0');
            id_ex_regs_use_imm     <= '0';
        elsif rising_edge(clk) then     -- rising clock edge
            -- default values
            id_ex_regs_rf_wr_en <= '0';

            if (hazard_stall = '0' and cache_stall = '0') then
                if (id_ex_regs_branch_type /= BRANCH_NONE or
                    id_ex_regs_insn_type = OP_JAL or id_ex_regs_insn_type = OP_JALR or
                    ex_mem_regs_insn_type = OP_JAL or ex_mem_regs_insn_type = OP_JALR) then  -- control transfer - kill the instruction
                    id_ex_regs_rs1_data    <= (others => '0');
                    id_ex_regs_rs2_data    <= (others => '0');
                    id_ex_regs_npc         <= (others => '0');
                    id_ex_regs_alu_func    <= ALU_NONE;
                    id_ex_regs_op2_src     <= '0';
                    id_ex_regs_insn_type   <= OP_ILLEGAL;
                    id_ex_regs_branch_type <= BRANCH_NONE;
                    id_ex_regs_load_type   <= LOAD_NONE;
                    id_ex_regs_store_type  <= STORE_NONE;
                    id_ex_regs_rf_wr_addr  <= "00000";
                    id_ex_regs_rf_wr_en    <= '0';
                    id_ex_regs_use_imm     <= '0';
                else
                    id_ex_regs_rs1_data    <= id_rs1_data;
                    id_ex_regs_rs2_data    <= id_rs2_data;
                    id_ex_regs_npc         <= if_id_regs_npc;
                    id_ex_regs_alu_func    <= id_decoded.alu_func;
                    id_ex_regs_op2_src     <= id_decoded.op2_src;
                    id_ex_regs_insn_type   <= id_decoded.insn_type;
                    id_ex_regs_branch_type <= id_decoded.branch_type;
                    id_ex_regs_load_type   <= id_decoded.load_type;
                    id_ex_regs_store_type  <= id_decoded.store_type;
                    id_ex_regs_imm         <= id_decoded.imm;
                    id_ex_regs_use_imm     <= id_decoded.use_imm;

                    -- determine if the register file will be written as a result
                    -- of this instruction
                    if (next_pc_sel = PC_SEQ) then
                        id_ex_regs_rf_wr_addr <= id_decoded.rd;
                        if (id_decoded.insn_type = OP_ALU or id_decoded.insn_type = OP_LOAD or id_decoded.insn_type = OP_JALR or id_decoded.insn_type = OP_JAL) then
                            if (id_decoded.rd /= "00000") then
                                id_ex_regs_rf_wr_en <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            else
                -- stalled
                id_ex_regs_rs1_data    <= (others => '0');
                id_ex_regs_rs2_data    <= (others => '0');
                id_ex_regs_npc         <= (others => '0');
                id_ex_regs_alu_func    <= ALU_NONE;
                id_ex_regs_op2_src     <= '0';
                id_ex_regs_insn_type   <= OP_ILLEGAL;
                id_ex_regs_branch_type <= BRANCH_NONE;
                id_ex_regs_load_type   <= LOAD_NONE;
                id_ex_regs_store_type  <= STORE_NONE;
                id_ex_regs_rf_wr_addr  <= "00000";
                id_ex_regs_rf_wr_en    <= '0';
                id_ex_regs_use_imm     <= '0';
            end if;
        end if;
    end process id_ex_regs_proc;

    -- print instructions as they are issued
    print_decode : if (g_for_sim = true) generate
        -- purpose: Print out information about decoded instruction
        -- type   : combinational
        -- inputs : id_decoded
        -- outputs: 
        print_decode_proc : process (id_ex_regs_insn_type, id_ex_regs_npc) is
            variable l : line;
        begin  -- process print_decode_proc
            write(l, id_ex_regs_insn_type);
            write(l, string'("  : "));
            write(l, to_integer(id_ex_regs_npc));
            writeline(output, l);
        end process print_decode_proc;
    end generate print_decode;

    -------------------
    -------------------
    -- Execute stage --
    -------------------
    -------------------

    ex_branch_jal_target <= unsigned(id_ex_regs_npc) + unsigned(id_ex_regs_rs2_data);

    -- the address to write to 'rd' during a JAL or JALR
    ex_jump_addr <= unsigned(id_ex_regs_npc) + to_unsigned(4, 32);

    -- choose first operand for ALU
    ex_op1 <= std_logic_vector(id_ex_regs_npc) when (id_ex_regs_insn_type = OP_BRANCH or
                                                     id_ex_regs_insn_type = OP_JAL or
                                                     id_ex_regs_insn_type = OP_JALR)
              else id_ex_regs_rs1_data;

    -- choose second operand for ALU
    ex_op2 <= id_ex_regs_imm when ((id_ex_regs_insn_type = OP_ALU and id_ex_regs_use_imm = '1') or
                                   id_ex_regs_insn_type = OP_BRANCH or
                                   id_ex_regs_insn_type = OP_JAL or
                                   id_ex_regs_insn_type = OP_JALR)
              else id_ex_regs_rs2_data;

    ---- instantiate the Arithmetic/Logic Unit
    arithmetic_logic_unit : entity work.alu(Behavioral)
        port map (alu_func => id_ex_regs_alu_func,
                  op1      => ex_op1,
                  op2      => ex_op2,
                  result   => ex_alu_output);

    -- check truth of conditionals for branch instructions
    conditionals : entity work.compare_unit(behavioral)
        port map (branch_type    => id_ex_regs_branch_type,
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
            ex_mem_regs_load_pc    <= '0';
            ex_mem_regs_alu_output <= (others => '0');
            ex_mem_regs_jump_addr  <= (others => '0');
            ex_mem_regs_npc        <= (others => '0');
            ex_mem_regs_load_type  <= LOAD_NONE;
            ex_mem_regs_store_type <= STORE_NONE;
            ex_mem_regs_rf_wr_addr <= (others => '0');
            ex_mem_regs_imm        <= (others => '0');
            ex_mem_regs_insn_type  <= OP_ILLEGAL;
            ex_mem_regs_rf_wr_en   <= '0';
        elsif rising_edge(clk) then     -- rising clock edge
            -- defaults
            ex_mem_regs_load_pc <= '0';

            if cache_stall = '0' then
                -- pipeline registers
                ex_mem_regs_alu_output <= ex_alu_output;
                ex_mem_regs_jump_addr  <= std_logic_vector(ex_jump_addr);
                ex_mem_regs_npc        <= id_ex_regs_npc;
                ex_mem_regs_load_type  <= id_ex_regs_load_type;
                ex_mem_regs_store_type <= id_ex_regs_store_type;
                ex_mem_regs_rf_wr_addr <= id_ex_regs_rf_wr_addr;
                ex_mem_regs_imm        <= id_ex_regs_imm;
                ex_mem_regs_insn_type  <= id_ex_regs_insn_type;
                ex_mem_regs_rf_wr_en   <= id_ex_regs_rf_wr_en;

                if (id_ex_regs_insn_type = OP_JAL or id_ex_regs_insn_type = OP_BRANCH) then
                    ex_mem_regs_next_pc_addr <= ex_alu_output;
                else
                    ex_mem_regs_next_pc_addr <= ex_mem_regs_jump_addr;
                end if;

                if (ex_compare_result = '1' or id_ex_regs_insn_type = OP_JAL or id_ex_regs_insn_type = OP_JALR) then
                    ex_mem_regs_load_pc <= '1';
                end if;
            end if;
        end if;
    end process ex_mem_regs_proc;

    ------------------
    ------------------
    -- Memory stage --
    ------------------
    ------------------

    -- create memory interface
    mem_data_addr     <= ex_mem_regs_alu_output;
    mem_data_write_en <= '1' when ex_mem_regs_insn_type = OP_STORE else '0';
    mem_data_read_en  <= '1' when ex_mem_regs_insn_type = OP_LOAD  else '0';
    mem_data_out      <= ex_mem_regs_rf_wr_data;
    mem_data_in       <= data_in;
    mem_data_in_valid <= data_in_valid;

    -- purpose: create pipeline registers between MEM and WB
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: mem_wb_regs
    mem_wb_regs_proc : process (clk, rst_n) is
    begin  -- process mem_wb_regs
        if rst_n = '0' then             -- asynchronous reset (active low)
            mem_wb_regs_alu_output <= (others => '0');
            mem_wb_regs_rf_wr_en   <= '0';
            mem_wb_regs_insn_type  <= OP_ILLEGAL;
            mem_wb_regs_rf_wr_addr <= "00000";
        elsif rising_edge(clk) then     -- rising clock edge
            if cache_stall = '0' then
                mem_wb_regs_alu_output <= ex_mem_regs_alu_output;
                mem_wb_regs_rf_wr_en   <= ex_mem_regs_rf_wr_en;
                mem_wb_regs_insn_type  <= ex_mem_regs_insn_type;
                mem_wb_regs_rf_wr_addr <= ex_mem_regs_rf_wr_addr;
            end if;

        end if;
    end process mem_wb_regs_proc;

    ---------------------
    ---------------------
    -- Writeback stage --
    ---------------------
    ---------------------

    -- purpose: perform register file writeback
    -- type   : combinational
    -- inputs : mem_wb_regs
    -- outputs: register file write signals
    writeback_proc : process (mem_wb_regs_rf_wr_addr, mem_wb_regs_rf_wr_en, mem_wb_regs_insn_type, mem_wb_regs_lmd, mem_wb_regs_alu_output) is
    begin  -- process writeback_proc
        wb_rf_wr_addr <= mem_wb_regs_rf_wr_addr;
        wb_rf_wr_en   <= mem_wb_regs_rf_wr_en;

        if mem_wb_regs_insn_type = OP_LOAD then
            wb_rf_wr_data <= mem_wb_regs_lmd;
        else
            wb_rf_wr_data <= mem_wb_regs_alu_output;
        end if;
    end process writeback_proc;

end architecture Behavioral;
