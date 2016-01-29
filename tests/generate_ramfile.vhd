library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.common.all;
use work.encode_pkg.all;
use work.test_config.all;

entity generate_ramfile is
end entity generate_ramfile;

architecture script of generate_ramfile is
    
    type ram_t is array (natural range 0 to 128) of word;
    constant test1 : ram_t := (0 => encode_i_type(I_ADDI, "000000000100", 0, 1),  -- ADDI x0, x1, 4
                               4 => encode_i_type(I_ADDI, "000000001000", 0, 2),  -- ADDI x0, x2, 8
                               8 => encode_r_type(R_ADD, 1, 2, 3),  -- ADD x1, x2, x3
                               12 => encode_u_type(U_LUI, "10000000000000000001", 4),  -- LUI 0x80001, x4
                               16 => encode_uj_type(UJ_JAL, "00000000000000010010", 6),  -- JAL 18, x6
                               20 => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                               24 => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                               28 => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                               32 => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                               36 => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1      -- this should not get executed
                               40 => NOP,
                               44 => NOP,
                               48 => NOP,
                               52 => encode_r_type(R_ADD, 3, 4, 5),  -- ADD x3, x4, x5
                               56 => encode_u_type(U_AUIPC, "10000000000000000001", 8),  -- AUIPC 0x80001, x8
                               -- store the value in x8 into address 8 (offset 4 + value in x1 (4))
                               60 => encode_s_type(S_SW, "000000000100", 1, 8),  -- SW x1, x8, 4
                               -- load the halfword value that was just stored (into address 8) into register 9
                               64 => encode_i_type(I_LH, "000000001000", 0, 9),  -- LH x0, x9, 8
                               68 => encode_r_type(R_ADD, 8, 9, 10),  -- ADD x8, x9, x10
                               -- loop back to the previous address
                               -- encode_sb_type(SB_BNE, "111111111110", 9, 8),  -- BNE x9, x8, -4
                               72 => encode_sb_type(SB_BNE, "000000001000", 9, 8),  -- BNE x9, x8, 16
                               76 => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1     -- this should not get executed
                               80 => encode_i_type(I_ADDI, "000000000011", 0, 1),  -- ADDI x0, x1, 3     -- this should not get executed
                               84 => encode_i_type(I_ADDI, "000000000111", 0, 1),  -- ADDI x0, x1, 3     -- this should not get executed
                               88 => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 3     -- this should not get executed
                               92 => encode_i_type(I_ADDI, "000000011111", 1, 11),  -- ADDI x0, x1, 3     -- this should not get executed
                               96 => NOP,
                               others => (others => '0'));

    -- purpose: Generate ramfiles
    procedure main is
        file test1file   : text open write_mode is pipeline_tb_test_vector_input_filename;
        variable outline : line;
    begin  -- procedure main

        --
        -- Create test1 file
        --
        for i in test1'range loop
            write(outline, test1(i));
            writeline(test1file, outline);
        end loop;  -- i
    end procedure main;

begin  -- architecture script
    
    main_proc : process is
        variable outline : line;
    begin  -- process main_proc
        main;
        write(outline, string'("Done."));
        writeline(output, outline);
        wait;
    end process main_proc;
    
end architecture script;

