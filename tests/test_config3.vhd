library ieee;
use ieee.std_logic_1164.all;
use work.encode_pkg.all;
use work.common.all;

package test_config is

    constant pipeline_tb_test_vector_input_filename : string := "sim/test3.vec";

    -- arrays of instructions
    type ram_t is array (natural range 0 to 128) of word;

    -- add 8 to x0 in x0  (make sure x0 doesn't actually get changed)
    -- add 8 to x0 in x1  (make sure x1 gets 4)
    -- add x0, x1 to x2   (make sure x2 gets 8)
    -- add x1, x2 to x3   (make sure x3 gets 12)
    -- beq x2, x1 -16

    -- Test 3 (TODO): WAW, WAR, RAW, reads/writes to register 0,
    -- incorrectly-predicted-taken backwards branch
    constant test3 : ram_t := (0      => encode_i_type(I_ADDI, "000000001000", 0, 0),
                               4      => encode_i_type(I_ADDI, "000000000100", 0, 1),
                               8      => encode_r_type(R_ADD, 0, 1, 2),
                               12     => encode_r_type(R_ADD, 1, 2, 3),
                               16     => encode_sb_type(SB_BEQ, "111111111000", 1, 2),
                               20     => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1
                               24     => encode_i_type(I_ADDI, "000000000011", 0, 1),  -- ADDI x0, x1, 3
                               28     => encode_i_type(I_ADDI, "000000000111", 0, 1),  -- ADDI x0, x1, 7
                               32     => encode_i_type(I_ADDI, "000000000001", 0, 1),  -- ADDI x0, x1, 1
                               36     => encode_i_type(I_ADDI, "000000011111", 1, 11),  -- ADDI x1, x11, 20
                               others => NOP);

    type test_config_t is record
        filename : string(1 to 13);
        test     : ram_t;
    end record test_config_t;

    constant test_configuration : test_config_t := ("sim/test3.vec", test3);

end package test_config;
