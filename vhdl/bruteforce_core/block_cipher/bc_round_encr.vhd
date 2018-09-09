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

-- This Entity describes a Round Function of the Cipher Block in Encryption Mode.

entity bc_round_encr is
    port (
        round_in    : in WORD;
        key         : in BYTE;
        round_out   : out WORD
    );
end entity;


                                                           
architecture arch of bc_round_encr is
    
    --*****COMPONENT DACLARATION*****
    component round_perm is
        port (
            input   : in BYTE;
            output  : out BYTE
        );
    end component;
    
    component s_box is
        port (
            addr    : in BYTE; --PortNum Ports of 0-7
            data    : out BYTE  --PortNum Ports of 0-7
        );
    end component;
    
    --*****SIGNAL DECLARATION*****
    signal r_in, r_out : BYTE_ARRAY;
    signal p : BYTE;
    signal s_addr, s : BYTE;

begin
    
    --*****COMPONENT INSTANTIATION*****
    s_box_inst : s_box
        port map(
            addr    => s_addr,
            data    => s
        );
    
    round_perm_inst : round_perm
        port map(
            input   => s,
            output  => p
        );
    
    --Tranformation to/from custom types (This is optimized away)
    r_in        <= to_BYTE_ARRAY(round_in);
    round_out   <= from_BYTE_ARRAY(r_out);
    
    --No operation allowed in Port Maps, so...here is a signal
    s_addr <= r_in(0) xor key;
    
    --*****PROCESSES*****
    round_function : process(r_in, p, s)
    begin
        r_out(7) <= r_in(6);
        r_out(6) <= r_in(5) xor r_in(7);
        r_out(5) <= r_in(4) xor r_in(7);
        r_out(4) <= r_in(3) xor r_in(7);
        r_out(3) <= r_in(2);
        r_out(2) <= r_in(1) xor p;
        r_out(1) <= r_in(0);
        r_out(0) <= r_in(7) xor s;
    end process;
    
end architecture;
