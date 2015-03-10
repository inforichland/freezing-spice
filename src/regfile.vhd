library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;

entity regfile is
    port (clk   : in  std_logic;
          addra : in  std_logic_vector(4 downto 0);
          addrb : in  std_logic_vector(4 downto 0);
          rega  : out word;
          regb  : out word;
          addrw : in  std_logic_vector(4 downto 0);
          dataw : in  word;
          we    : in  std_logic);
end entity regfile;

architecture rtl of regfile is
    type regbank_t is array (0 to 31) of word;

    signal regbank : regbank_t := (others => (others => '0'));
begin  -- architecture Behavioral

    -- purpose: create registers
    -- type   : sequential
    -- inputs : clk
    -- outputs: 
    registers_proc : process (clk) is
    begin  -- process registers_proc
        if rising_edge(clk) then
            if (we = '1') then
                regbank(to_integer(unsigned(addrw))) <= dataw;
            end if;
        end if;
    end process registers_proc;

    -- asynchronous read
    rega <= regbank(to_integer(unsigned(addra)));
    regb <= regbank(to_integer(unsigned(addrb)));
    
end architecture rtl;
