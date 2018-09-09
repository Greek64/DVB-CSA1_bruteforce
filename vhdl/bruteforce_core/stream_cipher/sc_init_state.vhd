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

-- This entity calculates the next internal state of the Stream Cipher during it's Initialization
-- Mode. It takes the current State as Input and calculates, latches and outputs the next state
-- as Output.
-- The INDEX Generic identifies the stage of the Initialization Mode (The Initialization Mode has 
-- 32 stages) and is used to parse the first Scrambled Byte used for the Initialization mode 
-- correctly and to only latch Data that the next stages need.

--NOTE: Even though the Papers explicitly state that the the D nibble is not a register and that the 
-- effective state size of the Stream Cipher is only 103 bits, in the Initialization State the 
-- calculation of the fsrA needs the PREVIOUS D state, that is no longer calculable by the current
-- Registers states. That brings the need to latch the D State and use it in the next Initialization
-- Clk. This effectively increases the state size of the Stream Cipher during it's initialization 
-- State by 4 bits. After the Initialization State the D can be calculated from the existing Registers 
-- States and has no longer the need to be latched.

entity sc_init_state is
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
        SB_out  : out BYTE_ARRAY := (others => (others => '0'));
        --STATE OUT
        fsrA_out: out SC_FSR := (others => (others => '0'));
        fsrB_out: out SC_FSR := (others => (others => '0'));
        E_out   : out NIBBLE := (others => '0');
        F_out   : out NIBBLE := (others => '0');
        X_out   : out NIBBLE := (others => '0');
        Y_out   : out NIBBLE := (others => '0');
        Z_out   : out NIBBLE := (others => '0');
        D_out   : out NIBBLE := (others => '0');
        c_out   : out std_logic := '0';
        p_out   : out std_logic := '0';
        q_out   : out std_logic := '0'
    );
end entity;
                                                           
architecture arch of sc_init_state is
    
    --*****COMPONENT DECLARATION*****
    component sc_sbox is
        port (
            addr1    : in std_logic_vector(4 downto 0);
            addr2    : in std_logic_vector(4 downto 0);
            addr3    : in std_logic_vector(4 downto 0);
            addr4    : in std_logic_vector(4 downto 0);
            addr5    : in std_logic_vector(4 downto 0);
            addr6    : in std_logic_vector(4 downto 0);
            addr7    : in std_logic_vector(4 downto 0);
            data1    : out std_logic_vector(1 downto 0);
            data2    : out std_logic_vector(1 downto 0);
            data3    : out std_logic_vector(1 downto 0);
            data4    : out std_logic_vector(1 downto 0);
            data5    : out std_logic_vector(1 downto 0);
            data6    : out std_logic_vector(1 downto 0);
            data7    : out std_logic_vector(1 downto 0)
        );
    end component;
    
    --*****SIGNAL DECLARATIONS*****
    signal X_next, Y_next, Z_next, F_next, E_next : NIBBLE;
    signal D_next, fsrA_next, fsrB_next, fsrB_tmp, Bout, IA, IB : NIBBLE;
    signal p_next, q_next, c_next : std_logic;
    signal addr1, addr2, addr3, addr4, addr5, addr6, addr7 : std_logic_vector(4 downto 0);
    signal data1, data2, data3, data4, data5, data6, data7 : std_logic_vector(1 downto 0);

begin
    
    --*****SBOX INSTANTIATION*****
    sc_scbox_inst : sc_sbox
        port map(
            addr1    => addr1,
            addr2    => addr2,
            addr3    => addr3,
            addr4    => addr4,
            addr5    => addr5,
            addr6    => addr6,
            addr7    => addr7,
            data1    => data1,
            data2    => data2,
            data3    => data3,
            data4    => data4,
            data5    => data5,
            data6    => data6,
            data7    => data7
        );
    
    --IA and IB instantiation
    -- NOTE: The SB0 (First Cipher Block), is used in a reversed order.
    IaIb_prc: process(SB)
    begin
        IA  <= SB((BYTE_ARRAY_WIDTH-1)-(INDEX/4))(BYTE_WIDTH-1 downto BYTE_WIDTH/2);
        IB  <= SB((BYTE_ARRAY_WIDTH-1)-(INDEX/4))((BYTE_WIDTH/2)-1 downto 0);
        if(INDEX mod 2 = 1) then
            IB  <= SB((BYTE_ARRAY_WIDTH-1)-(INDEX/4))(BYTE_WIDTH-1 downto BYTE_WIDTH/2);
            IA  <= SB((BYTE_ARRAY_WIDTH-1)-(INDEX/4))((BYTE_WIDTH/2)-1 downto 0);
        end if;
    end process;
    
    --SBOX INPUT
    sbox_addr : process(fsrA)
    begin
        addr1 <= fsrA(3)(0) & fsrA(0)(2) & fsrA(5)(1) & fsrA(6)(3) & fsrA(8)(0);
        addr2 <= fsrA(1)(1) & fsrA(2)(2) & fsrA(5)(3) & fsrA(6)(0) & fsrA(8)(1);
        addr3 <= fsrA(0)(3) & fsrA(1)(0) & fsrA(4)(1) & fsrA(4)(3) & fsrA(5)(2);
        addr4 <= fsrA(2)(3) & fsrA(0)(1) & fsrA(1)(3) & fsrA(3)(2) & fsrA(7)(0);
        addr5 <= fsrA(4)(2) & fsrA(3)(3) & fsrA(5)(0) & fsrA(7)(1) & fsrA(8)(2); --da_diet
        addr6 <= fsrA(2)(1) & fsrA(3)(1) & fsrA(4)(0) & fsrA(6)(2) & fsrA(8)(3);
        addr7 <= fsrA(1)(2) & fsrA(2)(0) & fsrA(6)(1) & fsrA(7)(2) & fsrA(7)(3);
    end process;
    
    -- D STATE
    D_prc : process(E, Z, Bout)
    begin
        D_next <= E xor Z xor Bout;
    end process;
    
    -- E,F,c STATE
    EFc_state : process(E, F, Z, c, q)
        variable sum : std_logic_vector(NIBBLE_WIDTH downto 0);
    begin
        sum := std_logic_vector(unsigned('0' & E) + unsigned('0' & Z) + unsigned(to_NIBBLE(c)));
        E_next <= F;
        F_next <= E;
        c_next <= c;
        if(q = '1') then
            F_next <= sum(NIBBLE_WIDTH-1 downto 0);
            c_next <= sum(NIBBLE_WIDTH);
        end if;
    end process;
    
    -- X, Y, Z, p, q STATE
    XYZpq_state : process(data1, data2, data3, data4, data5, data6, data7)
    begin
        X_next <= data4(0) & data3(0) & data2(1) & data1(1);
        Y_next <= data6(0) & data5(0) & data4(1) & data3(1);
        Z_next <= data2(0) & data1(0) & data6(1) & data5(1);
        p_next <= data7(1);
        q_next <= data7(0);
    end process;
    
    -- Bout STATE (Bout is not a Register, it is the used output of the B register)
    Bout_prc : process(fsrB)
    begin
        Bout(3) <= fsrB(2)(0) xor fsrB(5)(1) xor fsrB(6)(2) xor fsrB(8)(3);
        Bout(2) <= fsrB(5)(0) xor fsrB(7)(1) xor fsrB(2)(3) xor fsrB(3)(2);
        Bout(1) <= fsrB(4)(3) xor fsrB(7)(2) xor fsrB(3)(0) xor fsrB(4)(1);
        Bout(0) <= fsrB(8)(2) xor fsrB(5)(3) xor fsrB(2)(1) xor fsrB(7)(0);
    end process;
    
    -- FSRA STATE
    fsrA_next <= fsrA(9) xor X xor D xor IA;
    
    
    -- FSRB STATE
    fsrB_tmp <= fsrB(6) xor fsrB(9) xor Y xor IB;
    
    fsrB_next_prc : process(fsrB_tmp, p)
    begin
        fsrB_next <= fsrB_tmp;
        if(p = '1') then
            fsrB_next <= to_stdlogicvector(to_bitvector(fsrB_tmp) rol 1);
        end if;
    end process;
    
    -- Internal Register
    sync : process(clk)
    begin
        if(rising_edge(clk)) then
            --SHIFT REGISTERS
            fsrA_out(0) <= fsrA_next;
            fsrB_out(0) <= fsrB_next;
            for i in 1 to SC_FSR_LENGTH-1 loop
                fsrA_out(i) <= fsrA(i-1);
                fsrB_out(i) <= fsrB(i-1);
            end loop;
            --STATE REGISTERS
            E_out   <= E_next;
            F_out   <= F_next;
            X_out   <= X_next;
            Y_out   <= Y_next;
            Z_out   <= Z_next;
            D_out   <= D_next;
            c_out   <= c_next;
            p_out   <= p_next;
            q_out   <= q_next;
            --SB REGISTERS
            -- Only register what is needed for the rest stages.
            for i in ((BYTE_ARRAY_WIDTH-1)-(INDEX/4)) downto 0 loop
                SB_out(i) <= SB(i);
            end loop;
        end if;
    end process;
end architecture;
