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

-- This Entity describes the very first Internal State of the Stream Cipher before it goes into
-- Initialization Mode.

entity sc_fsr_init is
    port (
        key     : in WORD;
        fsrA    : out SC_FSR;
        fsrB    : out SC_FSR;
        E       : out NIBBLE;
        F       : out NIBBLE;
        X       : out NIBBLE;
        Y       : out NIBBLE;
        Z       : out NIBBLE;
        D       : out NIBBLE;
        c       : out std_logic;
        p       : out std_logic;
        q       : out std_logic
    );
end entity;
                                                           
architecture arch of sc_fsr_init is

    signal key_swap : WORD;

begin
    
    --*****PROCESS DECLARATION*****
    
    -- Nibble Swap the Common Word
    key_swap <= nibble_swap(key);
    
    --Initialise the FSRs
    load_key : process(key_swap)
    begin
        fsrA <= (others => (others => '0'));
        fsrB <= (others => (others => '0'));
        
        for i in 0 to 7 loop
            for j in 0 to SC_FSR_WIDTH-1 loop
                fsrA(i)(j) <= key_swap((4*i)+j);
                fsrB(i)(j) <= key_swap(32+(4*i)+j);
            end loop;
        end loop;
    end process;
    
    --Initialise the rest of the states
    E <= (others => '0');
    F <= (others => '0');
    X <= (others => '0');
    Y <= (others => '0');
    Z <= (others => '0');
    D <= (others => '0');
    c <= '0';
    p <= '0';
    q <= '0';
    
end architecture;
