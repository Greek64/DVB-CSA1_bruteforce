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

--This Entity contains the 7 S-Boxes used by the Stream Cipher to calculate it's next state.
--TODO: reference

entity sc_sbox is
    port (
        addr1    : in std_logic_vector(4 downto 0);
        addr2    : in std_logic_vector(4 downto 0);
        addr3    : in std_logic_vector(4 downto 0);
        addr4    : in std_logic_vector(4 downto 0);
        addr5    : in std_logic_vector(4 downto 0);
        addr6    : in std_logic_vector(4 downto 0);
        addr7    : in std_logic_vector(4 downto 0);
        data1    : out std_logic_vector(1 downto 0);
        data2    : out std_logic_vector(1 downto 0);
        data3    : out std_logic_vector(1 downto 0);
        data4    : out std_logic_vector(1 downto 0);
        data5    : out std_logic_vector(1 downto 0);
        data6    : out std_logic_vector(1 downto 0);
        data7    : out std_logic_vector(1 downto 0)
    );
end entity;
                                                           
architecture arch of sc_sbox is

    --*****TYPE DEFINITIONS*****
    type ROM is array (0 to 31) of std_logic_vector(1 downto 0);
    
    --*****CONSTANT DEFINITIONS*****
    constant sbox1 : ROM := (
       "10", "00", "01", "01", "10", "11", "11", "00", "11", "10", "10", "00", "01", "01", "00", "11", 
       "00", "11", "11", "00", "10", "10", "01", "01", "10", "10", "00", "11", "01", "01", "11", "00"
    );
    constant sbox2 : ROM := (
        "11", "01", "00", "10", "10", "11", "11", "00", "01", "11", "10", "01", "00", "00", "01", "10", 
        "11", "01", "00", "11", "11", "10", "00", "10", "00", "00", "01", "10", "10", "01", "11", "01"
    );
    constant sbox3 : ROM := (
        "10", "00", "01", "10", "10", "11", "11", "01", "01", "01", "00", "11", "11", "00", "10", "00", 
        "01", "11", "00", "01", "11", "00", "10", "10", "10", "00", "01", "10", "00", "11", "11", "01"
    );
    constant sbox4 : ROM := (
        "11", "01", "10", "11", "00", "10", "01", "10", "01", "10", "00", "01", "11", "00", "00", "11", 
        "01", "00", "11", "01", "10", "11", "00", "11", "00", "11", "10", "00", "01", "10", "10", "01"
    );
    constant sbox5 : ROM := (
        "10", "00", "00", "01", "11", "10", "11", "10", "00", "01", "11", "11", "01", "00", "10", "01", 
        "10", "11", "10", "00", "00", "11", "01", "01", "01", "00", "11", "10", "11", "01", "00", "10"
    );
    constant sbox6 : ROM := (
        "00", "01", "10", "11", "01", "10", "10", "00", "00", "01", "11", "00", "10", "11", "01", "11", 
        "10", "11", "00", "10", "11", "00", "01", "01", "10", "01", "01", "10", "00", "11", "11", "00"
    );
    constant sbox7 : ROM := (
        "00", "11", "10", "10", "11", "00", "00", "01", "11", "00", "01", "11", "01", "10", "10", "01", 
        "01", "00", "11", "11", "00", "01", "01", "10", "10", "11", "01", "00", "10", "11", "00", "10"
    );
begin

    rom1_prc : process(addr1)
    begin
        data1 <= sbox1(to_integer(unsigned(addr1)));
    end process;
    
    rom2_prc : process(addr2)
    begin
        data2 <= sbox2(to_integer(unsigned(addr2)));
    end process;
    
    rom3_prc : process(addr3)
    begin
        data3 <= sbox3(to_integer(unsigned(addr3)));
    end process;
    
    rom4_prc : process(addr4)
    begin
        data4 <= sbox4(to_integer(unsigned(addr4)));
    end process;
    
    rom5_prc : process(addr5)
    begin
        data5 <= sbox5(to_integer(unsigned(addr5)));
    end process;
    
    rom6_prc : process(addr6)
    begin
        data6 <= sbox6(to_integer(unsigned(addr6)));
    end process;
    
    rom7_prc : process(addr7)
    begin
        data7 <= sbox7(to_integer(unsigned(addr7)));
    end process;
end architecture;
