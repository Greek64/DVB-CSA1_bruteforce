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

-- This Entity describes the S-Box used by the Cipher Block.

-- The s-box is basically a LUT Table, here implemented as a ROM. 
-- The address is the Byte to substitute, and the data is the substituated byte.
entity s_box is
    port (
        addr    : in BYTE; --PortNum Ports of 0-7
        data    : out BYTE  --PortNum Ports of 0-7
    );
end entity;
                                                           
architecture arch of s_box is
    type ROM is array (0 to (2 ** 8)-1) of BYTE;
    constant sbox : ROM := (
       x"3a", x"ea", x"68", x"fe", x"33", x"e9", x"88", x"1a", x"83", x"cf", x"e1", x"7f", x"ba", x"e2", x"38", x"12",
       x"e8", x"27", x"61", x"95", x"0c", x"36", x"e5", x"70", x"a2", x"06", x"82", x"7c", x"17", x"a3", x"26", x"49",
       x"be", x"7a", x"6d", x"47", x"c1", x"51", x"8f", x"f3", x"cc", x"5b", x"67", x"bd", x"cd", x"18", x"08", x"c9",
       x"ff", x"69", x"ef", x"03", x"4e", x"48", x"4a", x"84", x"3f", x"b4", x"10", x"04", x"dc", x"f5", x"5c", x"c6",
       x"16", x"ab", x"ac", x"4c", x"f1", x"6a", x"2f", x"3c", x"3b", x"d4", x"d5", x"94", x"d0", x"c4", x"63", x"62",
       x"71", x"a1", x"f9", x"4f", x"2e", x"aa", x"c5", x"56", x"e3", x"39", x"93", x"ce", x"65", x"64", x"e4", x"58",
       x"6c", x"19", x"42", x"79", x"dd", x"ee", x"96", x"f6", x"8a", x"ec", x"1e", x"85", x"53", x"45", x"de", x"bb",
       x"7e", x"0a", x"9a", x"13", x"2a", x"9d", x"c2", x"5e", x"5a", x"1f", x"32", x"35", x"9c", x"a8", x"73", x"30",
       x"29", x"3d", x"e7", x"92", x"87", x"1b", x"2b", x"4b", x"a5", x"57", x"97", x"40", x"15", x"e6", x"bc", x"0e",
       x"eb", x"c3", x"34", x"2d", x"b8", x"44", x"25", x"a4", x"1c", x"c7", x"23", x"ed", x"90", x"6e", x"50", x"00",
       x"99", x"9e", x"4d", x"d9", x"da", x"8d", x"6f", x"5f", x"3e", x"d7", x"21", x"74", x"86", x"df", x"6b", x"05",
       x"8e", x"5d", x"37", x"11", x"d2", x"28", x"75", x"d6", x"a7", x"77", x"24", x"bf", x"f0", x"b0", x"02", x"b7",
       x"f8", x"fc", x"81", x"09", x"b1", x"01", x"76", x"91", x"7d", x"0f", x"c8", x"a0", x"f2", x"cb", x"78", x"60",
       x"d1", x"f7", x"e0", x"b5", x"98", x"22", x"b3", x"20", x"1d", x"a6", x"db", x"7b", x"59", x"9f", x"ae", x"31",
       x"fb", x"d3", x"b6", x"ca", x"43", x"72", x"07", x"f4", x"d8", x"41", x"14", x"55", x"0d", x"54", x"8b", x"b9",
       x"ad", x"46", x"0b", x"af", x"80", x"52", x"2c", x"fa", x"8c", x"89", x"66", x"fd", x"b2", x"a9", x"9b", x"c0"
    );
begin

    rom_pr : process(addr)
    begin
        data <= sbox(to_integer(unsigned(addr)));
    end process;

end architecture;
