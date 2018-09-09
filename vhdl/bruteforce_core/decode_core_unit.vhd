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

-- This Entity is the Top Entity of the Decryption Modul and instantiates all needed 
-- subcomponents.
-- It decrypts the first 64 bit Block of Scrambled/Cipher Data.

entity decode_core_unit is
    port (
        clk     : in std_logic;
        CB0     : in WORD;
        CB1     : in WORD;
        key     : in CW_TYPE_SLV;
        PB0     : out WORD
    );
end entity;

architecture arch of decode_core_unit is

--PIPELINE STRUCTURE
------------------------------------------------------------------------
-- key_expand               CB0_sig                 CB1_delay           PIPELINE STAGE 1
------------------------------------------------------------------------(1 clk)
-- block_cipher(57 clk)     stream_cipher(64 clk)   CB1_delay(64 clk)   PIPELINE STAGE 2-65 (64 clk)
-- BCB_delay(7 clk)
------------------------------------------------------------------------
-- BCB_delay                IB_sig                                      PIPELINE STAGE 66
------------------------------------------------------------------------(1 clk)
-- PB0                                                                  PIPELINE STAGE 67
------------------------------------------------------------------------(1 clk)

    --*****COMPONENT DECLARATION*****
    component key_expand is
        port (
            key_in   : in CW_TYPE_SLV;
            key_out  : out WORD
        );
    end component;
    
    component block_cipher is
        generic(
            DECRYPT : boolean := true
        );
        port (
            clk     : in std_logic;
            data    : in WORD;
            key     : in WORD;
            result  : out WORD
        );
    end component;
    
    component stream_cipher is
        port (
            clk     : in std_logic;
            CB0     : in WORD;
            key     : in WORD;
            SCB_out : out WORD
        );
    end component;
    
    --*****CONSTANT DECLARATION*****
    constant CB1_DELAY_NUM : integer := SC_STAGE_NUM+1;
    constant BCB_DELAY_NUM : integer := (SC_STAGE_NUM-BC_STAGE_NUM)+1;
    
    --*****TYPE DECLARATION*****
    type CB1_DELAY_ARRAY is array (CB1_DELAY_NUM-1 downto 0) of WORD;
    type BCB_DELAY_ARRAY is array (BCB_DELAY_NUM-1 downto 0) of WORD;
    
    --*****SIGNAL DECLARATION*****    
    signal key_sig_next, CB0_sig_next, SCB_sig, BCB_out, IB_sig_next, PB_sig_next : WORD;
    --*INITIAL RESET*
    signal key_sig, CB0_sig, IB_sig, PB_sig : WORD := (others => '0');
    signal CB1_delay : CB1_DELAY_ARRAY := (others => (others => '0'));
    signal BCB_delay : BCB_DELAY_ARRAY := (others => (others => '0'));
    
begin
    
    --TODO: Try to remove a few stages.
    
    --*****PIPELINE STAGE 1*****
    key_expand_inst : key_expand
        port map(
            key_in  => key,
            key_out => key_sig_next
        );
    
    CB0_sig_next <= CB0;
    
    
    --*****PIPELINE STAGE 2-65*****
    
    stream_cipher_inst : stream_cipher
        port map(
            clk     => clk,
            CB0     => CB0_sig,
            key     => key_sig,
            SCB_out => SCB_sig
        );
    
    block_cipher_inst : block_cipher
        port map(
            clk     => clk,
            data    => CB0_sig,
            key     => key_sig,
            result  => BCB_out
        );
    
    --*****PIPELINE STAGE 66*****
    
    sc_xor : process(CB1_delay, SCB_sig)
    begin
        IB_sig_next <= CB1_delay(CB1_DELAY_NUM-1) xor SCB_sig;
    end process;
    
    --*****PIPELINE STAGE 67*****
    
    bc_xor : process(IB_sig, BCB_delay)
    begin
        PB_sig_next <= IB_sig xor BCB_delay(BCB_DELAY_NUM-1);
    end process;
    
    --*****END OF PIPELINE*****
    
    PB0 <= PB_sig;
    
    sync : process(clk)
    begin
        if(rising_edge(clk)) then
            --PIPELINE REGISTERS
            key_sig     <= key_sig_next;
            CB0_sig     <= CB0_sig_next;
            IB_sig      <= IB_sig_next;
            PB_sig      <= PB_sig_next;
            --DELAY LINES
            CB1_delay(0) <= CB1;
            for i in 1 to CB1_DELAY_NUM-1 loop
                CB1_delay(i) <= CB1_delay(i-1);
            end loop;
            BCB_delay(0) <= BCB_out;
            for i in 1 to BCB_DELAY_NUM-1 loop
                BCB_delay(i) <= BCB_delay(i-1);
            end loop;
        end if;
    end process;
    
end architecture;
