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

-- This Entity implements a single Bruteforce Core. It contains the key generator that is 
-- responsible for feeding the underlying instantiated decode_core. It also contains the
-- necessary comparison logic to check the output of the decode_core and if the wanted common word
-- was found. Once the Key was found or the whole assigned key space of the core is iterated the
-- core stays in a suspended mode until the reset is pulled high, in which case the key generator
-- is reset and the Bruteforce procedure starts from the beginning.

entity core_control_unit is
    port (
        clk         : in std_logic;
        reset       : in std_logic;
        start_cw    : in CW_TYPE;
        cipher      : in CIPHER_ARRAY;
        stop_cw     : out CW_TYPE;
        done        : out std_logic;
        found       : out std_logic;
        key_out     : out CW_TYPE
    );
end entity;

--TODO: Last password check. (Should be all 1s).
   
architecture arch of core_control_unit is
    
    --*****COMPONENT DECLARATION*****
    component decode_core_unit is
        port (
            clk     : in std_logic;
            CB0     : in WORD;
            CB1     : in WORD;
            key     : in CW_TYPE_SLV;
            PB0     : out WORD
        );
    end component;

    --*****CONSTANT DECLARATIONS*****
    constant KNOWN_PLAINTEXT: std_logic_vector(23 downto 0) := x"000001";
    constant MAX_CW         : CW_TYPE := x"FFFFFFFFFFFF";
    constant MAX_DIV_SLV    : CW_TYPE := to_unsigned(MAX_CORE_NUM*MAX_FPGA_NUM, CW_WIDTH);
    constant MAX_CORE_SLV   : CW_TYPE := to_unsigned(MAX_CORE_NUM, CW_WIDTH);
    constant DIF            : CW_TYPE := (MAX_CW / MAX_DIV_SLV) + to_unsigned(1, CW_WIDTH);
    
    --*****TYPE DECLARATIONS*****
    subtype SAMPLE_TYPE is integer range 0 to SAMPLE_NUM;
    type KEYGEN_DELAY_ARRAY is array (DCU_STAGE_NUM-1 downto 0) of CW_TYPE;
    type SAMPLE_DELAY_ARRAY is array (DCU_STAGE_NUM-1 downto 0) of SAMPLE_TYPE;
    
    --*****SIGNAL DELARATIONS*****
    signal keygen, keygen_next, keygen_delay_next, key_out_next, key_out_sig : CW_TYPE;
    signal key_in_sig_next : CW_TYPE;
    signal key: CW_TYPE_SLV;
    signal enable, enable_next, found_next, done_next, done_sig, found_sig : std_logic;
    signal keygen_delay : KEYGEN_DELAY_ARRAY;
    signal sample_delay : SAMPLE_DELAY_ARRAY;
    signal sample_delay_next : SAMPLE_TYPE;
    signal PB0, CB0_next, CB1_next : WORD;
    signal stop_cw_sig_next : CW_TYPE;
    --*INITIAL RESET*
    --NOTE: Prevents propagation of metavalues in the first 64 clk of Simulation (Modelsim)
    signal key_in_sig, stop_cw_sig : CW_TYPE := (others => '0');
    signal CB0, CB1 : WORD := (others => '0');
    
begin
    
    --NOTE: The propagation delay until all the cores have a stable start_Cw in their input port
    -- is not taken into account by the core. This has to be taken care by the overlying logic by
    -- pulling the rest high when the signals are stable. For that reason the stop_cw_sig is not
    -- inside the reset clause of the sync_prc.
    --*ADDER*
    stop_cw_sig_next <= start_cw + DIF;
    
    -- This process implements the key generator, which is basically a counter.
    -- The key generator only counts when the enable signal is held high. This is done to allow
    -- feedback of previous generated keys into the decode_core with new ciphertext samples.
    key_generator: process(enable, keygen)
    begin
        keygen_next <= keygen;
        if(enable = '1') then
            keygen_next <= keygen + to_unsigned(1, CW_WIDTH);
        end if;
    end process;
    
    -- Instantiation of the decode_core
    decode_core_unit_inst : decode_core_unit
        port map(
            clk     => clk,
            CB0     => CB0,
            CB1     => CB1,
            key     => key,
            PB0     => PB0
        );
        
    key <= std_logic_vector(key_in_sig);
    
    -- This process controls the flow of the decode_core. It controls the enable signal of the 
    -- key generator, directly assigns the inputs of the decode core and compares the output of
    -- the decoded core to the given plaintext. Once a key candidate is found the key is feeded back
    -- to the decode core with a new pair of ciphertext block samples. Once a key has iterated all 
    -- samples sucessfully the output ports are set and the core is put into standby.
    control_unit : process(keygen, cipher, done_sig, sample_delay, PB0, keygen_delay, stop_cw_sig)
    begin
        --*Default*
        enable_next         <= '1';
        key_in_sig_next     <= keygen;
        keygen_delay_next   <= keygen;
        sample_delay_next   <= 1;
        CB0_next            <= cipher(0)(0);
        CB1_next            <= cipher(0)(1);
        found_next          <= '0';
        key_out_next        <= (others => '0');
        done_next           <= '0';
        
        --*Disable Keygenerator if Done*
        if(done_sig = '1') then
            enable_next <= '0';
        end if;
        
        --*Check if Core has Output*
        if(sample_delay(DCU_STAGE_NUM-1) /= 0) then
            --*Check if Output is expected Plaintext*
            if(PB0(63 downto 40) = KNOWN_PLAINTEXT) then
                --*Check if last Sample*
                if(sample_delay(DCU_STAGE_NUM-1) = SAMPLE_NUM) then
                    found_next      <= '1';
                    done_next       <= '1';
                    key_out_next    <= keygen_delay(DCU_STAGE_NUM-1);
                else
                    enable_next         <= '0';
                    key_in_sig_next     <= keygen_delay(DCU_STAGE_NUM-1);
                    keygen_delay_next   <= keygen_delay(DCU_STAGE_NUM-1);
                    sample_delay_next   <= sample_delay(DCU_STAGE_NUM-1)+1;
                    CB0_next            <= cipher(sample_delay(DCU_STAGE_NUM-1))(0);
                    CB1_next            <= cipher(sample_delay(DCU_STAGE_NUM-1))(1);
                end if;
            end if;
            --*Check if iterated entire Keyspace*
            if(keygen_delay(DCU_STAGE_NUM-1) = stop_cw_sig) then
                done_next <= '1';
            end if;
        end if;
    end process;
    
    --*Output Signal Connections*
    done    <= done_sig;
    found   <= found_sig;
    key_out <= key_out_sig;
    stop_cw <= stop_cw_sig;
    
    sync : process(clk)
    begin
        if(rising_edge(clk)) then
            --*Stop_cw outside the reset clause*
            stop_cw_sig <= stop_cw_sig_next;
            if(reset = '1') then
                enable          <= '0';
                keygen          <= start_cw;
                key_in_sig      <= (others => '0');
                CB0             <= (others => '0');
                CB1             <= (others => '0');
                --TOGGLE SIGNALS
                found_sig       <= '0';
                key_out_sig     <= (others => '0');
                done_sig        <= '0';
                --DELAY LINES
                keygen_delay    <= (others => (others => '0'));
                sample_delay    <= (others => 0);
            else
                enable          <= enable_next;
                keygen          <= keygen_next;
                key_in_sig      <= key_in_sig_next;
                CB0             <= CB0_next;
                CB1             <= CB1_next;
                found_sig       <= found_sig;
                key_out_sig     <= key_out_sig;
                done_sig        <= done_sig;
                --TOGGLE SIGNALS
                if(found_next = '1') then
                    found_sig   <= found_next;
                    key_out_sig <= key_out_next;
                end if;
                if(done_next = '1') then
                    done_sig    <= '1';
                end if;
                --DELAY LINES
                keygen_delay(0) <= keygen_delay_next;
                sample_delay(0) <= sample_delay_next;
                for i in 1 to DCU_STAGE_NUM-1 loop
                    keygen_delay(i) <= keygen_delay(i-1);
                    sample_delay(i) <= sample_delay(i-1);
                end loop;
            end if;
        end if;
    end process;
end architecture;
