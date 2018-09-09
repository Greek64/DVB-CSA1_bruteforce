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

-- This Entity describes the permutation that is used during a round function of the Cipher Block.

entity round_perm is
    port (
        input   : in BYTE;
        output  : out BYTE
    );
end entity;
                                                           
architecture arch of round_perm is
begin

perm : process(input)
begin
    output(1) <= input(0);
    output(7) <= input(1);
    output(5) <= input(2);
    output(4) <= input(3);
    output(2) <= input(4);
    output(6) <= input(5);
    output(0) <= input(6);
    output(3) <= input(7);
end process;

end architecture;
