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

library unisim;
use unisim.vcomponents.all;

use work.typedef_package.all;

-- This Entity abstracts the clock generation sheme. It uses the Xilinx DCM_CLKGEN Primitive
-- inorder to generate a clk signal from a refernece clk and dynamically adjust this at runtime
-- throught the Configuration Ports.

entity clock_gen is
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
end entity;

architecture spartan_6 of clock_gen is
    
    --*****TYPE DEFINITIONS*****
    type FREQ_PROG_TYPE is (IDLE, LOADD_INIT1, LOADD_INIT2, LOADD1, LOADD2, LOADD3, LOADD4, LOADD5,
        LOADD6, LOADD7, LOADD8, GAP1_1, GAP1_2, GAP1_3, LOADM_INIT1, LOADM_INIT2, LOADM1, LOADM2, 
        LOADM3, LOADM4, LOADM5, LOADM6, LOADM7, LOADM8, GAP2_1, GAP2_2, GAP2_3, GO, DONE);
    
	--*****SIGNAL DECLARATION*****
	signal clkfx : std_logic;
	signal locked, clk_stable_sig, clken, dcm_reset : std_logic;
	signal status : std_logic_vector(2 downto 1);
	signal dcm_freerun : std_logic;
	signal progen, progdata : std_logic;
	--FREQ PROG
    signal freq_state : FREQ_PROG_TYPE := IDLE;
    
begin
	
	--This Primitive is responsible for the clk generation.
	dcm_clkgen_inst : DCM_CLKGEN
		generic map (
			CLKFX_DIVIDE    => 4,
			CLKFX_MULTIPLY  => 9,
			 
			SPREAD_SPECTRUM => "NONE",
			STARTUP_WAIT    => FALSE,
			CLKIN_PERIOD    => 20.833, -- 48 MHz USB clock in on ZTEX board
			CLKFX_MD_MAX    => 3.125   -- 150 MHz
			)
		port map (
			--*INPUT CLOCK*
			CLKIN       => ref_clk,
			--*OUTPUT CLOCKS*
			CLKFX       => clkfx,
			CLKFX180    => open,
			CLKFXDV     => open,
			--*DYNAMIC CONFIGURATION PORTS*
			PROGCLK     => progclk,
			PROGEN      => progen,
			PROGDATA    => progdata,
			PROGDONE    => progdone,
			--*CONTROL PORTS*
			RST         => dcm_reset,
			FREEZEDCM   => dcm_freerun,
			--*STATUS PORTS*
			LOCKED      => locked,
			STATUS      => status
			);
	
	--*****CLK CONTROL*****
    clk_stable_sig  <= locked and (not status(2));
    clken           <= clk_stable_sig and (not clken_n);
    dcm_reset       <= clk_reset or (status(2) and (not locked));
	clk_stable      <= clk_stable_sig;
	dcm_freerun     <= clk_stable_sig;
	
	-- This process is responsible for the dynamic frequency adjustment. It implements the necessary 
	-- SPI communication with the DCM_CLKGEN primitive inorder to set a new frequency scale factor.
	prg_prc : process(progclk)
	begin
	    if(rising_edge(progclk)) then
	        if(clk_reset = '1') then
	            progen      <= '0';
	            progdata    <= '0';
	            freq_state  <= IDLE;
	        else
	            --The states are used to simulate a SPI Master that is configuring the DCM_CLKGEN
                --according to "Spartan-6 FPGA Clocking Resources User Manual" Page 84
                case(freq_state) is
                    when IDLE =>
                        progen      <= '0';
                        progdata    <= '0';
                        if(do_prog = '1') then
                            freq_state <= LOADD_INIT1;
                        end if;
                    when LOADD_INIT1 =>
                        progen      <= '1';
                        progdata    <= '1';
                        freq_state  <= LOADD_INIT2;
                    when LOADD_INIT2 =>
                        progen      <= '1';
                        progdata    <= '0';
                        freq_state  <= LOADD1;
                    when LOADD1 =>
                        progen      <= '1';
                        progdata    <= d(0);
                        freq_state  <= LOADD2;
                    when LOADD2 =>
                        progen      <= '1';
                        progdata    <= d(1);
                        freq_state  <= LOADD3;
                    when LOADD3 =>
                        progen      <= '1';
                        progdata    <= d(2);
                        freq_state  <= LOADD4;
                    when LOADD4 =>
                        progen      <= '1';
                        progdata    <= d(3);
                        freq_state  <= LOADD5;
                    when LOADD5 =>
                        progen      <= '1';
                        progdata    <= d(4);
                        freq_state  <= LOADD6;
                    when LOADD6 =>
                        progen      <= '1';
                        progdata    <= d(5);
                        freq_state  <= LOADD7;
                    when LOADD7 =>
                        progen      <= '1';
                        progdata    <= d(6);
                        freq_state  <= LOADD8;
                    when LOADD8 =>
                        progen      <= '1';
                        progdata    <= d(7);
                        freq_state  <= GAP1_1;
                    when GAP1_1 =>
                        progen      <= '0';
                        progdata    <= '0';
                        freq_state  <= GAP1_2;
                    when GAP1_2 =>
                        progen      <= '0';
                        progdata    <= '0';
                        freq_state  <= GAP1_3;
                    when GAP1_3 =>
                        progen      <= '0';
                        progdata    <= '0';
                        freq_state  <= LOADM_INIT1;
                    when LOADM_INIT1 =>
                        progen      <= '1';
                        progdata    <= '1';
                        freq_state  <= LOADM_INIT2;
                    when LOADM_INIT2 =>
                        progen      <= '1';
                        progdata    <= '1';
                        freq_state  <= LOADM1;
                    when LOADM1 =>
                        progen      <= '1';
                        progdata    <= m(0);
                        freq_state  <= LOADM2;
                    when LOADM2 =>
                        progen      <= '1';
                        progdata    <= m(1);
                        freq_state  <= LOADM3;
                    when LOADM3 =>
                        progen      <= '1';
                        progdata    <= m(2);
                        freq_state  <= LOADM4;
                    when LOADM4 =>
                        progen      <= '1';
                        progdata    <= m(3);
                        freq_state  <= LOADM5;
                    when LOADM5 =>
                        progen      <= '1';
                        progdata    <= m(4);
                        freq_state  <= LOADM6;
                    when LOADM6 =>
                        progen      <= '1';
                        progdata    <= m(5);
                        freq_state  <= LOADM7;
                    when LOADM7 =>
                        progen      <= '1';
                        progdata    <= m(6);
                        freq_state  <= LOADM8;
                    when LOADM8 =>
                        progen      <= '1';
                        progdata    <= m(7);
                        freq_state  <= GAP2_1;
                    when GAP2_1 =>
                        progen      <= '0';
                        progdata    <= '0';
                        freq_state  <= GAP2_2;
                    when GAP2_2 =>
                        progen      <= '0';
                        progdata    <= '0';
                        freq_state  <= GAP2_3;
                    when GAP2_3 =>
                        progen      <= '0';
                        progdata    <= '0';
                        freq_state  <= GO;
                    when GO =>
                        progen      <= '1';
                        progdata    <= '0';
                        freq_state  <= DONE;
                    when DONE =>
                        progen      <= '0';
                        progdata    <= '0';
                        --Go back to the IDLE state only if the do_prog is low to prevent a fall 
                        --through, in case of the do_prog pulse being held high for to long.
                        if(do_prog = '0') then
                            freq_state  <= IDLE;
                        end if;
                    --NOTE:We are ignoring the Progdone from the perspective of this routine.
                    --The progdone is still exported and read by the software to detect errors.
                end case;
            end if;
        end if;
	end process;
	
	--This Primitive is responsible for feeding the DCM generated clk into the global clk network.
	bufgce_inst : BUFGCE
	port map (
		I   => clkfx,
		CE  => clken,
		O   => clk
	);
--	bufg_inst : BUFG
--		port map (
--			I => clkfx,
--			O => clk
--		);
	
end architecture;

architecture xilinx_7 of clock_gen is
    
    --*****TYPE DEFINITIONS*****
    
	--*****SIGNAL DECLARATION*****
	signal clk0, clk1, clkfb, clkfx : std_logic;
    signal alm : std_logic_vector(7 downto 0);
    signal clk_stable_sig : std_logic;
    signal clken : std_logic;
    
    -- Dynamic configuration for the MMCM has not been implemented, for the simple reason that
    -- it was made to complicated. Even if the theory still uses M and D values to calculate
    -- the output Frequency like in the DCM, and also accepts these values in the generics for
    -- the initial configuration, in order to configure the MMCM these values have to be 
    -- converted to "High" and "Low" Counters, along with a plethora of additional settings
    -- like "Edge".To top it up, everytime the M value is changed, some magic values have 
    -- to be updated and reconfigured in the MMCM, which would mean that either all 
    -- configurable Frequencies have to be pre-calculated, or a Lookup table has to be 
    -- implemented directly in VHDL along with overkill calculation logic.
    -- You can take a look at the XAPP888 reference implementation by Xilinx, inorder to 
    -- convince yourself on how utterly idiotic the MMCM is implemented. To be fair, the
    -- reference implementation uses the precalculation method, meaning that all calculations
    -- and magic number lookups are down during compilation. And it's written in Verilog.
    
    -- So, since the Xilinx 7 series board have an on-chip temperature sensor, the MMCM can be 
    -- configured with 2 Frequencies and switch between these two Frequencies according to the 
    -- temperature.
    
begin
    
    
    -- Since no dynamic configuration
    progdone    <= '1';
    clk_stable  <= clk_stable_sig;
    clken       <= clk_stable_sig and (not clken_n);
    
    mmcm_inst : MMCME2_ADV
        generic map(
            BANDWIDTH            => "OPTIMIZED",
            CLKIN1_PERIOD        => 20.833, --48 MHz Input Period
            DIVCLK_DIVIDE        => 1,      --PFD 48 MHz
            CLKFBOUT_MULT_F      => 25.0,   --VCO 1200 MHz
            CLKOUT0_DIVIDE_F     => 6.315,  --190 MHz
            CLKOUT1_DIVIDE       => 12      --100 MHz
        )
        port map(
            -- Input clock control
            CLKINSEL            => '1',
            CLKIN1              => ref_clk,
            CLKIN2              => '0',
            CLKFBIN             => clkfb,
            -- Output clocks
            CLKFBOUT            => clkfb,
            CLKFBOUTB           => open,
            CLKOUT0             => clk0,
            CLKOUT0B            => open,
            CLKOUT1             => clk1,
            CLKOUT1B            => open,
            CLKOUT2             => open,
            CLKOUT2B            => open,
            CLKOUT3             => open,
            CLKOUT3B            => open,
            CLKOUT4             => open,
            CLKOUT5             => open,
            CLKOUT6             => open,
            -- Ports for dynamic reconfiguration
            DADDR               => (others => '0'),
            DCLK                => '0',
            DEN                 => '0',
            DWE                 => '0',
            DI                  => (others => '0'),
            DO                  => open,
            DRDY                => open,
            -- Ports for dynamic phase shift
            PSCLK               => '0',
            PSEN                => '0',
            PSINCDEC            => '0',
            PSDONE              => open,
            -- Other control and status signals
            LOCKED              => clk_stable_sig,
            CLKINSTOPPED        => open,
            CLKFBSTOPPED        => open,
            PWRDWN              => '0',
            RST                 => clk_reset
        );
	
    xadc_inst : XADC
		generic map(
			INIT_40 => X"0000", -- config reg 0 (Continuous Mode, No averaging)
			INIT_41 => X"810C", -- config reg 1 (Enable OT, enable ALM 0(Temp), Independent Mode)
			INIT_42 => X"0420", -- config reg 2 (Disable ADCB, CLK Division 4 (Irrelevant))
			INIT_48 => X"0800", -- Sequencer channel selection(Vp/Vn (ADCB))
			INIT_49 => X"0000", -- Sequencer channel selection
			INIT_4A => X"0000", -- Sequencer Average selection
			INIT_4B => X"0000", -- Sequencer Average selection
			INIT_4C => X"0000", -- Sequencer Bipolar selection
			INIT_4D => X"0000", -- Sequencer Bipolar selection
			INIT_4E => X"0000", -- Sequencer Acq time selection
			INIT_4F => X"0000", -- Sequencer Acq time selection
			INIT_50 => X"B363", -- Temp alarm trigger (80 C)
			INIT_51 => X"57E4", -- Vccint upper alarm limit (Default, Alarm Disabled)
			INIT_52 => X"A147", -- Vccaux upper alarm limit (Default, Alarm Disabled)
			INIT_53 => X"B883",  -- Temp alarm OT upper (90 C, Power Down)
			INIT_54 => X"AE4E", -- Temp alarm reset (70 C)
			INIT_55 => X"52C6", -- Vccint lower alarm limit (Default, Alarm Disabled)
			INIT_56 => X"9555", -- Vccaux lower alarm limit (Default, Alarm Disabled)
			INIT_57 => X"AE4E",  -- Temp alarm OT reset (70 C)
			INIT_58 => X"5999",  -- Vccbram upper alarm limit (Default, Alarm Disabled)
			INIT_5C => X"5111"  -- Vccbram lower alarm limit (Default, Alarm Disabled)
        )
		port map (
			CONVST              => '0',
			CONVSTCLK           => '0',
			DADDR               => (others => '0'),
			DCLK                => '0',
			DEN                 => '0',
			DI                  => (others => '0'),
			DWE                 => '0',
			RESET               => '0',
			VAUXN               => (others => '0'),
			VAUXP               => (others => '0'),
			ALM                 => alm, --alm(0) is Temperature Alarm
			BUSY                => open,
			CHANNEL             => open,
			DO                  => open,
			DRDY                => open,
			EOC                 => open,
			EOS                 => open,
			JTAGBUSY            => open,
			JTAGLOCKED          => open,
			JTAGMODIFIED        => open,
			OT                  => open, --Unnecessary, since Board powers down when OT is reached
			MUXADDR             => open,
			VN                  => '0',
			VP                  => '0'
        );
    
    ot <= alm(0); --Port OT out.
    
    bufgmux_inst : BUFGMUX
        port map(
            I0  => clk0,
            I1  => clk1,
            S   => alm(0),
            O   => clkfx
        );
    
	--This Primitive is responsible for feeding the DCM generated clk into the global clk network.
	bufgce_inst : BUFGCE
        port map (
            I   => clkfx,
            CE  => clken,
            O   => clk
        );
	
end architecture;