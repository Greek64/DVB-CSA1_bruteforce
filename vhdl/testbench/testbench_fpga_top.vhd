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


entity testbench_fpga_top is
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



architecture arch of testbench_fpga_top is

    --Component Declaration
    component fpga_top is
        port (
            clk             : in std_logic;
            reset           : in std_logic;
            fpga_start_cw   : in CW_TYPE;
            cipher          : in CIPHER_ARRAY;
            done            : out std_logic;
            found           : out std_logic;
            key_out         : out CW_TYPE
        );
    end component;
    
    signal clk, reset, done, found : std_logic;
    signal cipher : CIPHER_ARRAY;
    signal key_out : CW_TYPE;
    
begin

    --Instantiate Component
    fpga_top_inst : fpga_top
        port map(
            clk             => clk,
            reset           => reset,
            fpga_start_cw   => x"F8E38E38E396",
            cipher          => cipher,
            done            => done,
            found           => found,
            key_out         => key_out
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
        reset       <= '0';
        cipher      <= (others => (others => (others => '0')));
        report "Initial Reset";
        pulse(reset, clk);
        report "Set Signals";
        cipher(0)(0)<= x"036a5cafbba7ca3b"; --Plaintext: 0x00000100
        cipher(0)(1)<= x"b56118697f5d5612";
        cipher(1)(0)<= x"833e4e9fd0b3db43"; --Plaintext: 0x00000101
        cipher(1)(1)<= x"9372ed6fa5141200";
        cipher(2)(0)<= x"cc87de0713b1f326"; --Plaintext: 0x00000102
        cipher(2)(1)<= x"891343377c554313";
--        cipher(3)(0)<= x"28c2e352a7111e03"; --Plaintext: 0x00000103
--        cipher(3)(1)<= x"af6b7f7a07989968";
        --Expected CW: 000000000010
        wait;
    end process;
    
    STIM : process(found)
    begin
        if(found = '1') then
            report "Key found" severity failure;
        end if;
    end process;
end architecture;
