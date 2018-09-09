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
use ieee.std_logic_misc.all; --and_reduce

use work.typedef_package.all;

entity fpga_top is
    port (
        clk         : in std_logic;
        reset       : in std_logic;
        fpga_num    : in FPGA_NUM_TYPE;
        cipher      : in CIPHER_ARRAY;
        done        : out std_logic;
        found       : out std_logic;
        key_out     : out CW_TYPE
    );
end entity;

   
architecture arch of fpga_top is
    
    --*****COMPONENT DECLARATION*****
    component core_control_unit is
        generic(
            CORE_NUM : integer
        );
        port (
            clk         : in std_logic;
            reset       : in std_logic;
            fpga_num    : in FPGA_NUM_TYPE;
            cipher      : in CIPHER_ARRAY;
            done        : out std_logic;
            found       : out std_logic;
            key_out     : out CW_TYPE
        );
    end component;
    
    --*****TYPE DECLARATIONS*****
    type CW_ARRAY_TYPE is array (MAX_CORE_NUM-1 downto 0) of CW_TYPE;
    
    --*****SIGNAL DELARATIONS*****
    signal done_array_sig, found_array_sig : std_logic_vector(MAX_CORE_NUM-1 downto 0);
    signal key_array_sig : CW_ARRAY_TYPE;
    signal found_sig : std_logic;
    
begin

    core_gen : for i in 0 to MAX_CORE_NUM-1 generate
    begin
        core_control_unit_inst : core_control_unit
            generic map(
                CORE_NUM    => i
            )
            port map(
                clk         => clk,
                reset       => reset,
                fpga_num    => fpga_num,
                cipher      => cipher,
                done        => done_array_sig(i),
                found       => found_array_sig(i),
                key_out     => key_array_sig(i)
            );
    end generate;
    
    --*All Cores are Done*
    done <= and_reduce(done_array_sig) or found_sig;
    
    --*At least one Core has found something*
    found_sig   <= or_reduce(found_array_sig);
    found       <= found_sig;
    
    key_out_prc : process(found_array_sig, key_array_sig)
    begin
        key_out <= (others => '0');
        for i in 0 to MAX_CORE_NUM-1 loop
            if(found_array_sig(i) = '1') then
                key_out <= key_array_sig(i);
            end if;
            exit;
        end loop;
    end process;
    
end architecture;
