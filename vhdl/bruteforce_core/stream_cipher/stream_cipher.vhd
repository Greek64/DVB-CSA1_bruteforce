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

-- This is the Top Entity of the Stream Cipher that instantiates all subcomponents of the Stream 
-- Cipher.
-- It takes the first 64 bit Cipher Block (Scrambled Block) with the 64 bit Common Key and calculates 
-- the first Intermidiate Block, later used by the Block Cipher.

entity stream_cipher is
    port (
        clk     : in std_logic;
        CB0     : in WORD;
        key     : in WORD;
        SCB_out : out WORD
    );
end entity;
                 
--NOTE: This Design is based on unused Signals and the fact that they are optimized away by the 
-- Synthesis Tool. This is done to simplify the signal declaration and interconnection, but
-- still use as less resources as possible.
-- Two of the subcomponents control this via the generic map, which is constant and known during
-- synthesis and tell them which signals are relevant, which need to be latched and where to
-- put the output signals.

--NOTE: The D "register" is only considered a register during the Initialization Mode. Afterwards
-- it is calculated by the other Registers without the need of latching it. For more information 
-- read the comments in "sc_init_state.vhd"
                                                           
architecture arch of stream_cipher is

--PIPELINE STRUCTURE
------------------------------------------------
-- sc_fsr_init                                  
-- sc_init_state                                PIPELINE STAGE 1-32 (32 clk)
------------------------------------------------
-- sc_gen_state                                 PIPELINE STAGE 32-64 (32 clk)
------------------------------------------------

    --*****COMPONENT DECLARATION*****
    component sc_fsr_init is
        port (
            key     : in WORD;
            fsrA    : out SC_FSR;
            fsrB    : out SC_FSR;
            E       : out NIBBLE;
            F       : out NIBBLE;
            X       : out NIBBLE;
            Y       : out NIBBLE;
            Z       : out NIBBLE;
            D       : out NIBBLE;
            c       : out std_logic;
            p       : out std_logic;
            q       : out std_logic
        );
    end component;
    
    component sc_init_state is
        generic(
            INDEX : integer := 0
        );
        port (
            clk     : in std_logic;
            --SCRAMBLED BLOCK IN
            SB      : in BYTE_ARRAY;
            --STATE IN
            fsrA    : in SC_FSR;
            fsrB    : in SC_FSR;
            E       : in NIBBLE;
            F       : in NIBBLE;
            X       : in NIBBLE;
            Y       : in NIBBLE;
            Z       : in NIBBLE;
            D       : in NIBBLE;
            c       : in std_logic;
            p       : in std_logic;
            q       : in std_logic;
            --SCRAMBLED BLOCK OUT
            SB_out  : out BYTE_ARRAY;
            --STATE OUT
            fsrA_out: out SC_FSR;
            fsrB_out: out SC_FSR;
            E_out   : out NIBBLE;
            F_out   : out NIBBLE;
            X_out   : out NIBBLE;
            Y_out   : out NIBBLE;
            Z_out   : out NIBBLE;
            D_out   : out NIBBLE;
            c_out   : out std_logic;
            p_out   : out std_logic;
            q_out   : out std_logic
        );
    end component;
    
    component sc_gen_state is
        generic(
            INDEX : integer := 0
        );
        port (
            clk     : in std_logic;
            --STATE IN
            fsrA    : in SC_FSR;
            fsrB    : in SC_FSR;
            E       : in NIBBLE;
            F       : in NIBBLE;
            X       : in NIBBLE;
            Y       : in NIBBLE;
            Z       : in NIBBLE;
            c       : in std_logic;
            p       : in std_logic;
            q       : in std_logic;
            --KEY IN
            KEY     : in WORD;
            --STATE OUT
            fsrA_out: out SC_FSR;
            fsrB_out: out SC_FSR;
            E_out   : out NIBBLE;
            F_out   : out NIBBLE;
            X_out   : out NIBBLE;
            Y_out   : out NIBBLE;
            Z_out   : out NIBBLE;
            c_out   : out std_logic;
            p_out   : out std_logic;
            q_out   : out std_logic;
            --KEY OUT
            KEY_out : out WORD
        );
    end component;
    
    --*****TYPE DECLARATIONS*****
    type FSR_SIG is array ((SC_INIT_STAGES+SC_GEN_STAGES) downto 0) of SC_FSR;
    type NIBBLE_SIG is array ((SC_INIT_STAGES+SC_GEN_STAGES) downto 0) of NIBBLE;
    type NIBBLE_INIT_SIG is array (SC_INIT_STAGES downto 0) of NIBBLE; --Only used by the D "register"
    type SB_ARRAY is array (SC_INIT_STAGES downto 0) of BYTE_ARRAY;
    type KEY_ARRAY is array (SC_GEN_STAGES downto 0) of WORD;
    
    --*****SIGNAL DECLARATIONS*****
    signal fsrA_sig, fsrB_sig : FSR_SIG;
    signal E_sig, F_sig, X_sig, Y_sig, Z_sig : NIBBLE_SIG;
    signal D_sig : NIBBLE_INIT_SIG;
    signal c_sig, p_sig, q_sig : std_logic_vector((SC_INIT_STAGES+SC_GEN_STAGES) downto 0);
    signal SB_sig : SB_ARRAY;
    signal KEY_sig : KEY_ARRAY;
    
begin
    
    --*****PIPELINE STAGE 1-32*****
    
    --*INITIAL STREAM CIPHER STATE*
    sc_fsr_init_inst : sc_fsr_init
        port map (
            key     => key,
            fsrA    => fsrA_sig(0),
            fsrB    => fsrB_sig(0),
            E       => E_sig(0),
            F       => F_sig(0),
            X       => X_sig(0),
            Y       => Y_sig(0),
            Z       => Z_sig(0),
            D       => D_sig(0),
            c       => c_sig(0),
            p       => p_sig(0),
            q       => q_sig(0)
        );
    
    SB_sig(0)   <= to_BYTE_ARRAY(CB0);
    
    --*STREAM CIPHER INITIALIZATION MODE*
    sc_init_state_gen :  for i in 1 to SC_INIT_STAGES generate
    begin
        sc_init_state_inst : sc_init_state
            generic map(
                INDEX   => i-1
            )
            port map(
                clk     => clk,
                SB      => SB_sig(i-1),
                fsrA    => fsrA_sig(i-1),
                fsrB    => fsrB_sig(i-1),
                E       => E_sig(i-1),
                F       => F_sig(i-1),
                X       => X_sig(i-1),
                Y       => Y_sig(i-1),
                Z       => Z_sig(i-1),
                D       => D_sig(i-1),
                c       => c_sig(i-1),
                p       => p_sig(i-1),
                q       => q_sig(i-1),
                SB_out  => SB_sig(i),
                fsrA_out=> fsrA_sig(i),
                fsrB_out=> fsrB_sig(i),
                E_out   => E_sig(i),
                F_out   => F_sig(i),
                X_out   => X_sig(i),
                Y_out   => Y_sig(i),
                Z_out   => Z_sig(i),
                D_out   => D_sig(i),
                c_out   => c_sig(i),
                p_out   => p_sig(i),
                q_out   => q_sig(i)
            );
    end generate;
    
    --*****PIPELINE STAGE 33-64*****
    
    KEY_sig(0)  <= (others => '0');
    
    --*STREAM CIPHER GENERATION MODE*
    sc_gen_state_gen :  for i in SC_INIT_STAGES+1 to SC_INIT_STAGES+SC_GEN_STAGES generate
    begin
        sc_gen_state_inst : sc_gen_state
            generic map(
                INDEX   => i-(SC_INIT_STAGES+1)
            )
            port map(
                clk     => clk,
                fsrA    => fsrA_sig(i-1),
                fsrB    => fsrB_sig(i-1),
                E       => E_sig(i-1),
                F       => F_sig(i-1),
                X       => X_sig(i-1),
                Y       => Y_sig(i-1),
                Z       => Z_sig(i-1),
                c       => c_sig(i-1),
                p       => p_sig(i-1),
                q       => q_sig(i-1),
                KEY     => KEY_sig(i-SC_INIT_STAGES-1),
                fsrA_out=> fsrA_sig(i),
                fsrB_out=> fsrB_sig(i),
                E_out   => E_sig(i),
                F_out   => F_sig(i),
                X_out   => X_sig(i),
                Y_out   => Y_sig(i),
                Z_out   => Z_sig(i),
                c_out   => c_sig(i),
                p_out   => p_sig(i),
                q_out   => q_sig(i),
                KEY_out => KEY_sig(i-SC_INIT_STAGES)
            );
    end generate;
    
    SCB_out <= KEY_sig(SC_GEN_STAGES);
    
    --*****PIPELINE STAGE END*****
end architecture;
