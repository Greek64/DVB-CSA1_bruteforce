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

library unisim;
use unisim.vcomponents.all;

use work.typedef_package.all;

-- This is the top Entity of the whole FPGA implementation. It is responsible for the instantiation 
-- of all subcomponents and the communication with the Cypress FX2 USB Core. This Entity itself is
-- not affected by the reset signal. This means that data read from the USB is still valid after a 
-- reset.

entity top is
    port (
        clk_ztex        : in std_logic;
        reset           : in std_logic;
        cs              : in std_logic;
        clk_reset       : in std_logic;
        clken_n         : in std_logic;
        ifclk           : in std_logic;
        id              : in std_logic_vector(1 downto 0);
        fifo_data       : inout std_logic_vector(7 downto 0);
        fifo2_empty     : in std_logic;
        fifo4_empty     : in std_logic;
        fifo6_empty     : in std_logic;
        fifo6_pf        : in std_logic;
        fifo_addr       : out std_logic_vector(1 downto 0);
        sloe            : out std_logic;
        slrd            : out std_logic;
        slwr            : out std_logic;
        pktend          : out std_logic
    );
end entity;

   
architecture arch of top is
    
    --*****COMPONENT DECLARATION*****
    component clock_gen is
	    port(
		    ref_clk     : in std_logic;
            clk         : out std_logic;
            clk_stable  : out std_logic;
            ot          : out std_logic;
                    
            progclk     : in std_logic;
            do_prog     : in std_logic;
            m           : in BYTE;
            d           : in BYTE;
            progdone    : out std_logic;
            
            clk_reset   : in std_logic;
            clken_n     : in std_logic
	    );
    end component;
    
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
    
    component key_expand is
        port (
            key_in   : in CW_TYPE_SLV;
            key_out  : out WORD
        );
    end component;
    
    --*****CONSTANT DECLARATIONS*****
    constant FREQ_DATA_NUM : integer := 2;
    constant FREQ_DATA_WIDTH : integer := 8;
    constant FIFO2_ADDR : std_logic_vector(1 downto 0) := "00";
    constant FIFO4_ADDR : std_logic_vector(1 downto 0) := "01";
    constant FIFO6_ADDR : std_logic_vector(1 downto 0) := "10";
    constant SYNC_BYTE : std_logic_vector(BYTE_WIDTH-1 downto 0) := "10101010"; --0xAA
    
    --*****TYPE DEFINITIONS*****
    type FIFO_CTRL_TYPE is (FIFO2, FIFO2_READ_1, FIFO2_READ_2, FIFO2_CHECK, FIFO4, FIFO4_READ_1, 
        FIFO4_READ_2, FIFO4_CHECK, FIFO6, FIFO6_WRITE_1, FIFO6_WRITE_2, FIFO6_DONE);
    type FREQ_DATA_TYPE is array (FREQ_DATA_NUM-1 downto 0) of std_logic_vector(FREQ_DATA_WIDTH-1 downto 0);
    
    --*****SIGNAL DELARATIONS*****
    --CONTROL SIGNALS
    signal reset_buf, clk_reset_buf, clken_n_buf : std_logic := '0';
    --CLKGEN
    signal clk, clk_stable, slow_clk : std_logic;
    signal progdone : std_logic;
    --FPGA TOP
    signal key : BYTE_ARRAY;
    signal fpga_start_cw, key_out : CW_TYPE;
    signal cipher : CIPHER_ARRAY;
    signal done, found : std_logic;
    --FIFO CTRL
    signal fifo_state, fifo_state_next : FIFO_CTRL_TYPE := FIFO2;
    signal freq_data, freq_data_next : FREQ_DATA_TYPE := (others => (others => '0'));
    signal cnt, cnt_next : integer range 0 to (INPUT_DATA_BYTES+10) := 0;
    --INPUT
    signal input_data, input_data_next : INPUT_DATA_TYPE := (others => '0');
    --signifies a read transmission error
    signal tr_error, tr_error_next : std_logic := '1';
    --signifies a read transmission error of frequency data
    signal fr_error, fr_error_next : std_logic := '0';
    --Signals used by the 2 Stage FF synchronizer, for 4 Status bits that are read from the
    --slow_clk Domain.
    signal out_sync_1, out_sync_2 : std_logic_vector(3 downto 0);
    signal do_prog : std_logic;
    signal m, d : BYTE;

--NOTE: At first this architecture was using 2 Stage synchronized Handshake Signals to move Data
--between the slow_clk and clk Domain.
--This Design Implementation was changed, and the only two Stage Synchronizer used now is the out_sync 
--Signal (which is actually neither needed). We do not have to care about metastability issues 
--because of the following reasons:
--* The done and found Signals are starting low, and once set stay high until reset (sticky bit)
--* The key signal once set is kept constant until reset.
--* Even if the key is read out everytime the sw reads from this FPGA, the key is only taken into 
--  account if the found bit is set.
--* Inorder to prevent a metastable state of the Status Byte (The first Byte written by the FPGA) the
--  relevant Signals are synchronized via a 2 Stage FF. 
--  (Not necessary because of the reason below, but still implemented for completness sake).
--* From a metastable point of view, if the found/done bit is read during a transition we can read 
--  either a 1 or 0. But per definition the only transition that will happen is from 0 to 1 when the
--  FPGA is ready, and then stays there, which means that either way we can guarranty correct operation.

begin
    
    --********************CLOCK & CONTROL SIGNALS********************
    
    bufg_inst : BUFG
		port map (
			I => ifclk,
			O => slow_clk
		);
    
    --*CLOCK GENERATION*
    clkgen_inst : entity work.clock_gen(spartan_6)
	    port map(
		    ref_clk     => clk_ztex,
		    clk         => clk,
            clk_stable  => clk_stable,
            ot          => open,
		    progclk     => slow_clk,
		    do_prog     => do_prog,
            m           => m,
            d           => d,
		    progdone    => progdone,
		    clk_reset   => clk_reset_buf,
		    clken_n     => clken_n_buf
	    );
    
    d   <= freq_data(0);
    m   <= freq_data(1);
    
    --*CONTROL SIGNAL LATCH*
    -- Because of the nature of the Chip Select Signal, the control Signals are latched in order to
    -- allow the FX2 chip to select another FPGA, but for this FPGA to still keep this state.
    control_signal_prc : process(slow_clk)
    begin
        if(rising_edge(slow_clk)) then
            --Default Values
            reset_buf       <= reset_buf;
            clk_reset_buf   <= clk_reset_buf;
            clken_n_buf     <= clken_n_buf;
            if(cs = '1') then
                reset_buf       <= reset;
                clk_reset_buf   <= clk_reset;
                clken_n_buf     <= clken_n;
            end if;
        end if;
    end process;
    
    --********************BRUTEFORCE CORE********************
    --INPUT
    --48bit START CW        (6 Bytes)
    --64bit CB0 SAMPLE 1    (8 Bytes)
    --64bit CB1 SAMPLE 1    (8 Bytes)
    --64bit CB0 SAMPLE 2    (8 Bytes)
    --64bit CB1 SAMPLE 2    (8 Bytes)
    --64bit CB0 SAMPLE 3    (8 Bytes)
    --64bit CB1 SAMPLE 3    (8 Bytes)
    --TOTAL: 432bit (54 bytes)
    fpga_start_cw   <= unsigned(input_data((54*8)-1 downto 48*8));
    cipher(0)(0)    <= input_data((48*8)-1 downto 40*8);
    cipher(0)(1)    <= input_data((40*8)-1 downto 32*8);
    cipher(1)(0)    <= input_data((32*8)-1 downto 24*8);
    cipher(1)(1)    <= input_data((24*8)-1 downto 16*8);
    cipher(2)(0)    <= input_data((16*8)-1 downto 8*8);
    cipher(2)(1)    <= input_data((8*8)-1 downto 0*8);
    
    fpga_top_inst : fpga_top
        port map(
            clk             => clk,
            reset           => reset_buf,
            fpga_start_cw   => fpga_start_cw,
            cipher          => cipher,
            done            => done,
            found           => found,
            key_out         => key_out
        );
    
    key_expand_inst : key_expand
        port map(
            key_in                  => std_logic_vector(key_out),
            to_BYTE_ARRAY(key_out)  => key
        );
    
    --********************FX2 FIFO INTERFACE********************
    
    -- This process implements the main STate MAchine responsible for the communication with the USB
    -- EndPoints of the FX2 Chip. EP2 is data input for the bruteforce cores. EP4 is input data for 
    -- the dynamic frequency adjustment. EP6 is output and contains a status byte stating the momentary
    -- state of the FPGA, and the key found until now.
    fifo_ctrl : process(fifo_state, cnt, freq_data, cs, fifo2_empty, fifo4_empty,
    fifo6_empty, fifo_data, input_data, tr_error, input_data_next, 
    fifo6_pf, fr_error, out_sync_2, id, key)
    begin
        --*DEFAULT VALUES*
        fifo_state_next     <= fifo_state;
        sloe                <= 'Z';
        slrd                <= 'Z';
        slwr                <= 'Z';
        pktend              <= 'Z';
        fifo_addr           <= (others => 'Z');
        fifo_data           <= (others => 'Z');
        cnt_next            <= cnt;
        --Freq Prog
        do_prog             <= '0';
        freq_data_next      <= freq_data;
        --Input Data
        input_data_next     <= input_data;
        --Error Signals
        tr_error_next       <= tr_error;
        fr_error_next       <= fr_error;
        
        if(cs = '1') then
            --Drive Signals
            sloe        <= '1';
            slwr        <= '0';
            slrd        <= '0';
            pktend      <= '0';
            case(fifo_state) is
                --Check if EP2 has Data
                when FIFO2 =>
                    --Select FIFO2
                    fifo_addr   <= FIFO2_ADDR;
                    --If FIFO2 is empty transmission to next FIFO
                    if(fifo2_empty = '1') then
                        --NOTE: Due to the large setup time of the fifo_addr (25 ns according to 
                        -- CY7C68013 p.45), which is larger than the period of a single ifclk (slow_clk)
                        -- we have to select the next FIFO one clk before.
                        fifo_state_next <= FIFO4;
                        fifo_addr       <= FIFO4_ADDR;
                    else
                        fifo_state_next <= FIFO2_READ_1;
                        cnt_next        <= 0;
                    end if;
                --Read from EP2
                when FIFO2_READ_1 =>
                    --Select FIFO2
                    fifo_addr   <= FIFO2_ADDR;
                    --If FIFO2 is empty we finished reading out EP2
                    if(fifo2_empty = '1') then  
                        fifo_state_next <= FIFO2_CHECK;
                    else
                        fifo_state_next <= FIFO2_READ_2;
                    end if;
                when FIFO2_READ_2 =>
                    --Select FIFO2
                    fifo_addr   <= FIFO2_ADDR;
                    --Shift Data in
                    input_data_next(INPUT_DATA_WIDTH-1 downto INPUT_DATA_WIDTH-8) 
                        <= fifo_data;
                    input_data_next(INPUT_DATA_WIDTH-9 downto 0) 
                        <= input_data(INPUT_DATA_WIDTH-1 downto 8); 
                    slrd            <= '1';
                    cnt_next        <= cnt + 1;
                    fifo_state_next <= FIFO2_READ_1;
                --Check if correct amount of bytes read
                when FIFO2_CHECK =>
                    if(cnt = INPUT_DATA_BYTES) then
                        tr_error_next   <= '0';
                    else
                        tr_error_next   <= '1';
                    end if;
                    fifo_state_next <= FIFO4;
                    fifo_addr       <= FIFO4_ADDR;
                --Check if EP4 has data
                when FIFO4 =>
                    --Select FIFO4
                    fifo_addr   <= FIFO4_ADDR;
                    --If FIFO4 is empty transition to next FIFO
                    if(fifo4_empty = '1') then
                        fifo_state_next <= FIFO6;
                        fifo_addr       <= FIFO6_ADDR;
                    else
                        fifo_state_next <= FIFO4_READ_1;
                        cnt_next        <= 0;
                    end if;
                --Read from EP4
                when FIFO4_READ_1 =>
                    --Select FIFO4
                    fifo_addr   <= FIFO4_ADDR;
                    if(fifo4_empty = '1') then
                        fifo_state_next <= FIFO4_CHECK;
                    else
                        fifo_state_next <= FIFO4_READ_2;
                    end if;
                when FIFO4_READ_2 =>
                    --Select FIFO4
                    fifo_addr   <= FIFO4_ADDR;
                    freq_data_next(1)   <= fifo_data;
                    freq_data_next(0)   <= freq_data(1);
                    cnt_next            <= cnt + 1;
                    slrd                <= '1';
                    fifo_state_next     <= FIFO4_READ_1;
                --Check if correct amount of bytes read
                when FIFO4_CHECK =>
                    if(cnt = FREQ_DATA_NUM) then
                        fr_error_next   <= '0';
                        do_prog         <= '1';
                    else
                        fr_error_next   <= '1';
                    end if;
                    fifo_state_next <= FIFO6;
                    fifo_addr       <= FIFO6_ADDR;
                --*Handle EP6*
                when FIFO6 =>
                    --Select FIFO6
                    fifo_addr   <= FIFO6_ADDR;
                    --If EP6 awaits data transition to the first write state.
                    if(fifo6_pf = '1') then
                        fifo_state_next <= FIFO6_WRITE_1;
                        cnt_next        <= 0;
                    else
                        fifo_state_next <= FIFO2;
                        fifo_addr       <= FIFO2_ADDR;
                    end if;
                --OUTPUT
                --8bit  STATUS              (1 Byte)
                --64bit FOUND KEY           (8 Bytes)
                --TOTAL 72bit               (9 Bytes)
                when FIFO6_WRITE_1 =>
                    --Select FIFO6
                    fifo_addr <= FIFO6_ADDR;
                    --If FIFO6 is full or number reached transition to next FIFO
                    if(cnt = OUTPUT_DATA_BYTES or fifo6_pf = '0') then
                        fifo_state_next <= FIFO6_DONE;
                    else
                        fifo_state_next <= FIFO6_WRITE_2;
                    end if;
                when FIFO6_WRITE_2 =>
                    --Select FIFO6
                    fifo_addr <= FIFO6_ADDR;
                    --If FIFO6 is full transition to next FIFO
                    sloe            <= '0';
                    slwr            <= '1';
                    --If last Output Byte, write the status bits.
                    if(cnt = OUTPUT_DATA_BYTES-1) then
                        fifo_data       <= out_sync_2 & tr_error & fr_error & id;
                    else
                        fifo_data       <= key(cnt);
                    end if;
                    cnt_next        <= cnt + 1;
                    fifo_state_next <= FIFO6_WRITE_1;
                when FIFO6_DONE =>
                    --No error check, since it is the responsibility of the software.
                    fifo_state_next <= FIFO2;
                    fifo_addr       <= FIFO2_ADDR;
            end case;
        end if;
    end process;
    
    fifo_ctrl_sync : process(slow_clk)
    begin
        if(rising_edge(slow_clk)) then
            input_data  <= input_data_next;
            fifo_state  <= fifo_state_next;
            cnt         <= cnt_next;
            freq_data   <= freq_data_next;
            tr_error    <= tr_error_next;
            fr_error    <= fr_error_next;
            
            --2 Stage FF Synchronizers
            out_sync_1  <= done & found & clk_stable & progdone;
            out_sync_2  <= out_sync_1;
        end if;
    end process;
end architecture;
