library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;

entity mips is
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

architecture Behavioral of mips is
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
    signal id_imm             : word;
    signal id_addra, id_addrb : std_logic_vector(4 downto 0);
    signal id_rega, id_regb   : word;

    -- EX signals
    signal ex_opcode : std_logic_vector(2 downto 0);
    
begin

    -----------------------------
    -----------------------------
    -- Instruction fetch stage --
    -----------------------------
    -----------------------------

    -- decide on the next PC
    next_pc <= (pc + 4) when (ex_mem_regs.pc_sel = '1') else ex_mem_regs.branch_addr;

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

    -- extract information from IR
    id_imm   <= if_id_regs.ir(15 downto 0);
    id_addra <= if_id_regs.ir(10 downto 6);
    id_addrb <= if_id_regs.ir(15 downto 11);

    -- Instantiate the register file
    register_file : entity work.regfile(Behavioral)
        port map (clk   => clk,
                  rst_n => rst_n,
                  addra => id_addra,
                  addrb => id_addrb,
                  rega  => id_rega,
                  regb  => id_regb,
                  addrw => id_addrw,
                  we    => id_regfile_we);

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
                id_ex_regs.a   <= regs_a;
                id_ex_regs.b   <= regs_b;
                id_ex_regs.npc <= if_id_regs.npc;
                id_ex_regs.ir  <= if_id_regs.ir;
                id_ex_regs.imm <= sign_extend(id_imm);
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

    -- instantiate the Arithmetic/Logic Unit
    al_unit : entity work.alu(Behavioral)
        port map (func   => ex_alu_func,
                  a      => ex_a,
                  b      => ex_b,
                  result => ex_alu_output);

    -- purpose: Create the EX/MEM pipeline registers
    -- type   : sequential
    -- inputs : clk, rst_n
    -- outputs: ex_mem_regs
    ex_mem_regs_proc : process (clk, rst_n) is
    begin  -- process ex_mem_regs_proc
        if rst_n = '0' then             -- asynchronous reset (active low)
            ex_mem_regs <= c_ex_mem_regs_reset;
        elsif rising_edge(clk) then     -- rising clock edge
            ex_mem_regs.ir <= id_ex_regs.ir;
            if (ex_opcode = c_op_alu) then
                ex_mem_regs.alu_output <= ex_alu_output;
            elsif ((ex_opcode = c_op_load) or (ex_opcode = c_op_store)) then
                ex_mem_regs.alu_output <= unsigned(id_ex_regs.a) + unsigned(id_ex_regs.imm);
                ex_mem_regs.b          <= id_ex_regs.b;
            end if;
        end if;
    end process ex_mem_regs_proc;

end architecture Behavioral;
