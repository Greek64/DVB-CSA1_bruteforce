--DVB-CSA1 Brute-force FPGA Implementation
--Copyright (C) 2018  Ioannis Daktylidis
--
--This program is free software: you can redistribute it and/or modify
--it under the terms of the GNU General Public License as published by
--the Free Software Foundation, either version 3 of the License, or
--(at your option) any later version.
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU General Public License for more details.
--
--You should have received a copy of the GNU General Public License
--along with this program.  If not, see <http://www.gnu.org/licenses/>.

library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;

use work.typedef_package.all;

-- This Entity describes the Key Expand funtion of the Cipher Block that is used to expand the 64 bit
-- Common Key to a 448 bit expanded key.

entity bc_key_expand is
    port (
        clk     : in std_logic;
        key_in  : in WORD;
        key_out : out BC_KEY
    );
end entity;
                                          
architecture arch of bc_key_expand is
    
    --*****COMPONENT DECLARATION*****
    component bc_key_expand_round is
        port (
            key_in   : in WORD;
            key_out  : out WORD
        );
    end component;
    
    --******TYPE DECLARATION*****
    type KEY_SIGNAL is array (BC_KEY_EXP_STAGES-1 downto 0) of WORD;
    type CONST_ARRAY is array (0 to (ROUND_NUM/BYTE_WIDTH)-1) of WORD;

    --*****SIGNAL DECLARATION*****
    signal key_tmp, key_sig_next : KEY_SIGNAL;
    --*INITIAL RESET*
    signal key_sig : KEY_SIGNAL := (others => (others => '0'));
    
    --*****CONSTANT DECLARATION*****
    constant const : CONST_ARRAY := (
        x"0000000000000000", x"0101010101010101", x"0202020202020202", x"0303030303030303", 
        x"0404040404040404", x"0505050505050505", x"0606060606060606"
    );
    
    --******FUNCTION DECLARATION******
    function from_KEY_SIG(a : KEY_SIGNAL) return std_logic_vector is
        variable ret : std_logic_vector(BC_KEY_EXP_WIDTH-1 downto 0);
        variable x : integer range 0 to BC_KEY_EXP_WIDTH-1;
    begin
        for i in 0 to BC_KEY_EXP_STAGES-1 loop
            x := (i*WORD_WIDTH); 
            ret(x+(WORD_WIDTH-1) downto x) := a(i);
        end loop;
        return ret;  
    end function;
    
begin
    
    -- Initial Key load.
    key_tmp(BC_KEY_EXP_STAGES-1) <= key_in;
    
    -- STEP 1: Key Expansion via defined Key Schedule Round Permutation.
    bc_key_expand_stage_gen : for i in BC_KEY_EXP_STAGES-1 downto 1 generate
    begin
        --*****COMPONENT INSTANTIATION*****
        bc_key_expand_round_inst : bc_key_expand_round
            port map(
                key_in   => key_tmp(i),
                key_out  => key_tmp(i-1)
            );
    end generate;
    
    -- STEP 2 : Final xor with predefined constants
    xor_prc : process(key_tmp)
    begin
        for i in BC_KEY_EXP_STAGES-1 downto 0 loop
            key_sig_next(i) <= key_tmp(i) xor const(i);
        end loop;
    end process;
    
    -- Reconvert to std_logic_vector
    key_out <= from_KEY_SIG(key_sig);
    
    sync : process(clk)
    begin
        if(rising_edge(clk)) then
            key_sig <= key_sig_next;
        end if;
    end process;
end architecture;
