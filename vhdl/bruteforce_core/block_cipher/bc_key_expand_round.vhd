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

-- This Entity describes a Round function used by the Key Expand function of the Cipher Block.

entity bc_key_expand_round is
    port (
        key_in   : in WORD;
        key_out  : out WORD
    );
end entity;
                                                           
architecture arch of bc_key_expand_round is

signal p : WORD;

begin

perm : process(key_in)
begin
    p(19) <= key_in(0);
    p(27) <= key_in(1);
    p(55) <= key_in(2);
    p(46) <= key_in(3);
    p(01) <= key_in(4);
    p(15) <= key_in(5);
    p(36) <= key_in(6);
    p(22) <= key_in(7);
    p(56) <= key_in(8);
    p(61) <= key_in(9);
    p(39) <= key_in(10);
    p(21) <= key_in(11);
    p(54) <= key_in(12);
    p(58) <= key_in(13);
    p(50) <= key_in(14);
    p(28) <= key_in(15);
    p(07) <= key_in(16);
    p(29) <= key_in(17);
    p(51) <= key_in(18);
    p(06) <= key_in(19);
    p(33) <= key_in(20);
    p(35) <= key_in(21);
    p(20) <= key_in(22);
    p(16) <= key_in(23);
    p(47) <= key_in(24);
    p(30) <= key_in(25);
    p(32) <= key_in(26);
    p(63) <= key_in(27);
    p(10) <= key_in(28);
    p(11) <= key_in(29);
    p(04) <= key_in(30);
    p(38) <= key_in(31);
    p(62) <= key_in(32);
    p(26) <= key_in(33);
    p(40) <= key_in(34);
    p(18) <= key_in(35);
    p(12) <= key_in(36);
    p(52) <= key_in(37);
    p(37) <= key_in(38);
    p(53) <= key_in(39);
    p(23) <= key_in(40);
    p(59) <= key_in(41);
    p(41) <= key_in(42);
    p(17) <= key_in(43);
    p(31) <= key_in(44);
    p(00) <= key_in(45);
    p(25) <= key_in(46);
    p(43) <= key_in(47);
    p(44) <= key_in(48);
    p(14) <= key_in(49);
    p(02) <= key_in(50);
    p(13) <= key_in(51);
    p(45) <= key_in(52);
    p(48) <= key_in(53);
    p(03) <= key_in(54);
    p(60) <= key_in(55);
    p(49) <= key_in(56);
    p(08) <= key_in(57);
    p(34) <= key_in(58);
    p(05) <= key_in(59);
    p(09) <= key_in(60);
    p(42) <= key_in(61);
    p(57) <= key_in(62);
    p(24) <= key_in(63);
end process;

key_out <= p;

end architecture;
