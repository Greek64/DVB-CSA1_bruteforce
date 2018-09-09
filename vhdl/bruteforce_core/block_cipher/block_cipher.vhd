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

-- This Entity describes describes a Block Cipher that takes a 64 bit input and a 64 bit Key and 
-- generates a 64 bit output (Scrambled or Plain depending on the Mode of Operation 
-- [Encryption/Decryption])

entity block_cipher is
    generic(
        DECRYPT : boolean := true
    );
    port (
        clk     : in std_logic;
        data    : in WORD;
        key     : in WORD;
        result  : out WORD := (others => '0')
    );
end entity;

architecture arch of block_cipher is
    
--PIPELINE STRUCTURE
------------------------------------------------
-- bc_key_expand    data_delay                  PIPELINE STAGE 1
------------------------------------------------(1 clk)
-- bc_round_decr/bc_round_encr                  PIPELINE STAGE 2-57 (55 clk)
------------------------------------------------(1 clk)

    --*****COMPONENT DECLARATION*****
    component bc_key_expand is
        port (
            clk     : in std_logic;
            key_in  : in WORD;
            key_out : out BC_KEY
        );
    end component;
    
    component bc_round_decr is
        port (
            round_in    : in WORD;
            key         : in BYTE;
            round_out   : out WORD
        );
    end component;
    
    component bc_round_encr is
        port (
            round_in    : in WORD;
            key         : in BYTE;
            round_out   : out WORD
        );
    end component;
    
    --*****TYPE DECLARATION*****
    type ROUND_ARRAY is array (ROUND_NUM-1 downto 0) of WORD;
    type KEY_ARRAY is array (ROUND_NUM-1 downto 0) of BYTE;
    type KEY_SIGNAL is array (ROUND_NUM-1 downto 0) of KEY_ARRAY;
    
    --*****SIGNAL DECLARATION*****
    signal round_sig_next : ROUND_ARRAY;
    signal key_out : KEY_ARRAY;
    --*INITIAL RESET*
    signal round_sig : ROUND_ARRAY := (others => (others => '0'));
    signal bc_key_sig : KEY_SIGNAL := (others => (others => (others => '0')));
    signal data_delay : WORD := (others => '0');
    --Vivado workaround
    signal key_out_tr : BC_KEY;
    
    --*****FUNCTION DECLARATION*****
    function to_KEY_ARRAY(a : std_logic_vector((ROUND_NUM*BYTE_WIDTH)-1 downto 0)) return KEY_ARRAY is
        variable ret : KEY_ARRAY;
        variable x : integer range 0 to (ROUND_NUM*BYTE_WIDTH)-1;
    begin
        for i in 0 to ROUND_NUM-1 loop
            x := (i*BYTE_WIDTH); 
            ret(i) := a(x+(BYTE_WIDTH-1) downto x);
        end loop;
        return ret;        
    end function;
    
begin
    
    --*****PIPELNE STAGE 1*****

    bc_key_expand_inst : bc_key_expand
        port map(
            clk     => clk,
            key_in  => key,
            key_out => key_out_tr
        );
    
    --Done outside the port map, because Vivado doesn't support this "feature"
    key_out <= to_KEY_ARRAY(key_out_tr);
    
    --*****PIPELINE STAGE 2-57*****
    
    bc_round_gen : for i in 0 to ROUND_NUM-1 generate
    begin
        --Switch between Encryption and Decryption Implementation
        decrypt_inst : if (DECRYPT = true) generate
            bc_round_decr_inst : bc_round_decr
                port map(
                    round_in    => round_sig(i),
                    key         => bc_key_sig(i)((ROUND_NUM-1)-i),
                    round_out   => round_sig_next(i)
                );
        end generate;
        encrypt_inst : if (DECRYPT = false) generate
            bc_round_encr_inst : bc_round_encr
                port map(
                    round_in    => round_sig(i),
                    key         => bc_key_sig(i)(i),
                    round_out   => round_sig_next(i)
                );
        end generate;
    end generate;
    
    --*****END OF PIPELINE*****
    
    sync : process(clk, key_out, data_delay)
    begin
        if(rising_edge(clk)) then
            --PIPELINE REGISTERS
            data_delay  <= data;
            for i in 1 to ROUND_NUM-1 loop
                round_sig(i)<= round_sig_next(i-1);
            end loop;
            --We only Latch the values that are still relevant for the rest of the stages.
            --Since on decryption the Key is used backwards, we need an If case that switches 
            --between the two
            if(DECRYPT = true) then
                for i in 1 to ROUND_NUM-1 loop
                    for j in 0 to (ROUND_NUM-1)-i loop
                        bc_key_sig(i)(j) <= bc_key_sig(i-1)(j);
                    end loop;   
                end loop;
            else
                for i in 1 to ROUND_NUM-1 loop
                    for j in i to ROUND_NUM-1 loop
                        bc_key_sig(i)(j) <= bc_key_sig(i-1)(j);
                    end loop;   
                end loop;
            end if;
            result  <= round_sig_next(ROUND_NUM-1);
        end if;
        --NOTE: Because of driver conflicts this is declared asynchronously inside the sync Process
        bc_key_sig(0)   <= key_out;
        round_sig(0)    <= data_delay;
    end process;
    
end architecture;
