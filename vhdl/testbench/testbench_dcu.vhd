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

--use work.converters.all;
use work.typedef_package.all;


entity testbench_dcu is
    -- This procedure pulses the given Signal for 1 clk cycle
    procedure 
        pulse(
            signal a : inout std_logic;
            signal clk : in std_logic
        ) is
    begin
        a <= '1';
        wait until rising_edge(clk);
        a <= '0';
    end procedure;
end entity;



architecture arch of testbench_dcu is

    --Component Declaration
    component decode_core_unit is
        port (
            clk     : in std_logic;
            reset   : in std_logic;
            CB0     : in WORD;
            CB1     : in WORD;
            key     : in CW_TYPE_SLV;
            PB0     : out WORD
        );
    end component;
    
    signal clk, reset : std_logic;
    signal CB0, CB1, PB0 : WORD;
    signal key : CW_TYPE_SLV;
    
begin

    --Instantiate Component
    decode_core_inst : decode_core_unit
        port map(
            clk     => clk,
            reset   => reset,
            CB0     => CB0,
            CB1     => CB1,
            key     => key,
            PB0     => PB0
        );
    
    clk_prc : process
    begin
        clk <= '1';
        wait for 1 ps;
        clk <= '0';
        wait for 1 ps;
    end process;


    process
    begin
        report "Testbench initialized";
        report "Initialising Signals";
        reset   <= '0';
        CB0     <= (others => '0');
        CB1     <= (others => '0');
        key     <= (others => '0');
        report "Initial Reset";
        pulse(reset, clk);
        report "Set Signals";
        CB0     <= x"9F251F9FC95B0F3A";
        CB1     <= x"2724051104739F17";
        key     <= x"665544332211"; --Expected: 0xCAFE000000000000
        wait until rising_edge(clk);
        CB0     <= x"AFDD89D0AE1218BE";
        CB1     <= x"65AF469259C4CD75";
        key     <= x"FFFFFFFFFFFF"; --Expected: 0xEC88E0D775ED292D
        wait until rising_edge(clk);
        CB0     <= x"AFDD89D0AE1218BE";
        CB1     <= x"65AF469259C4CD75";
        key     <= x"123456789abc"; --Expected: 0xCAFE000000000000
        wait;
    end process;
end architecture;
