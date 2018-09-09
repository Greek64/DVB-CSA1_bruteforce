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
        clk             : in std_logic;
        reset           : in std_logic;
        fpga_start_cw   : in CW_TYPE;
        cipher          : in CIPHER_ARRAY;
        done            : out std_logic;
        found           : out std_logic;
        key_out         : out CW_TYPE
    );
end entity;

   
architecture arch of fpga_top is
    
    --*****COMPONENT DECLARATION*****
    component core_control_unit is
        port (
            clk         : in std_logic;
            reset       : in std_logic;
            start_cw    : in CW_TYPE;
            stop_cw     : in CW_TYPE;
            cipher      : in CIPHER_ARRAY;
            done        : out std_logic;
            found       : out std_logic;
            key_out     : out CW_TYPE
        );
    end component;
    
    --*****CONSTANTS DECLARATIONS*****
    constant MAX_CW         : CW_TYPE := x"FFFFFFFFFFFF";
    constant MAX_DIV_SLV    : CW_TYPE := to_unsigned(MAX_CORE_NUM*MAX_FPGA_NUM, CW_WIDTH);
    constant MAX_CORE_SLV   : CW_TYPE := to_unsigned(MAX_CORE_NUM, CW_WIDTH);
    constant DIF            : CW_TYPE := (MAX_CW / MAX_DIV_SLV) + to_unsigned(1, CW_WIDTH);
    
    --*****TYPE DECLARATIONS*****
    type CW_ARRAY_TYPE is array (MAX_CORE_NUM-1 downto 0) of CW_TYPE;
    
    --*****SIGNAL DELARATIONS*****
    signal done_array_sig, found_array_sig : std_logic_vector(MAX_CORE_NUM-1 downto 0);
    signal key_array_sig, start_cw_array, stop_cw_array, start_cw_array_next, stop_cw_array_next : CW_ARRAY_TYPE;
    signal start_delay : std_logic_vector(MAX_CORE_NUM downto 0);
    signal core_reset : std_logic;
    
begin
    
    
    adder_gen : for i in 0 to MAX_CORE_NUM-1 generate
    begin
        stop_cw_array_next(i)   <= start_cw_array(i) + DIF;
    end generate;
    
    start_cw_gen : for i in 0 to MAX_CORE_NUM-1 generate
    begin
        first_it : if(i = 0) generate
            start_cw_array_next(0) <= fpga_start_cw;
        end generate;
        
        rest_it : if(i /= 0) generate
            start_cw_array_next(i) <= stop_cw_array(i-1);
        end generate;
    end generate;
    
    
    --*Core Reset Signal*
    core_reset <= (not start_delay(MAX_CORE_NUM)) or reset;
    
    --*The Core generator*
    core_gen : for i in 0 to MAX_CORE_NUM-1 generate
    begin
        core_control_unit_inst : core_control_unit
            port map(
                clk         => clk,
                reset       => core_reset,
                start_cw    => start_cw_array(i),
                stop_cw     => stop_cw_array(i),
                cipher      => cipher,
                done        => done_array_sig(i),
                found       => found_array_sig(i),
                key_out     => key_array_sig(i)
            );
    end generate;
    
    --*All Cores are Done*
    done <= and_reduce(done_array_sig);
    
    --*At least one Core has found something*
    found <= or_reduce(found_array_sig);
    
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
    
    
    sync : process(clk)
    begin
        if(rising_edge(clk)) then
            if(reset = '1') then
                start_cw_array  <= (others => (others => '0'));
                stop_cw_array   <= (others => (others => '0'));
                start_delay     <= (others => '0');
            else
                start_cw_array  <= start_cw_array_next;
                stop_cw_array   <= stop_cw_array_next;
                start_delay     <= start_delay(MAX_CORE_NUM-1 downto 0) & "1"; --shift left with 1
            end if;
        end if;
    end process;
end architecture;
