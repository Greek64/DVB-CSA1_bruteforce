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
use ieee.numeric_std.all;

use work.typedef_package.all;

-- This Entity implements the initial expansion of the Common Key from 48 to 64 bits.

entity key_expand is
    port (
        key_in   : in CW_TYPE_SLV;
        key_out  : out WORD
    );
end entity;
                                                           
architecture arch of key_expand is
    signal a, b : BYTE_ARRAY;
    
begin
    
    -- This Process is only used to convert the Input Type to a custom type, inorder to make the 
    -- Key_expand proces more readable. It is optimized away by the compiler.
    conv : process(key_in)
    begin
        a(7) <= (others => '0');
        a(6) <= key_in(47 downto 40);
        a(5) <= key_in(39 downto 32);
        a(4) <= key_in(31 downto 24);
        a(3) <= (others => '0');
        a(2) <= key_in(23 downto 16);
        a(1) <= key_in(15 downto 8);
        a(0) <= key_in(7 downto 0);
    end process;
    
    -- The key_expand process expands the 48 bit key into a 64 bit key.
    -- The first 3 Bytes of the key_in are also the first 3 Bytes of key_out.
    -- The 4 Byte of the key_out is the SUM of the first 3 Bytes modulo 2⁸.
    -- The same operation is used for the other 4 Bytes.
    key_expand : process(a)
    begin
        b(0) <= a(0);
        b(1) <= a(1);
        b(2) <= a(2);
        b(3) <= std_logic_vector(signed(a(0)) + signed(a(1)) + signed(a(2)));
        b(4) <= a(4);
        b(5) <= a(5);
        b(6) <= a(6);
        b(7) <= std_logic_vector(signed(a(4)) + signed(a(5)) + signed(a(6)));
    end process;
    
    key_out <= from_BYTE_ARRAY(b);
    
end architecture;
