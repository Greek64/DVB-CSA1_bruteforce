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


-- This entity calculates the next internal state of the Stream Cipher during it's Generation
-- Mode and calculates two bits of the Stream Cipher Key. It takes the current State as Input 
-- and calculates, latches and outputs the next state including the Stream Cipher Key as Output.

-- The INDEX Generic identifies the stage of the Generation Mode (Inorder to produce a 64 bit 
-- Stream Cipher Key we need 32 Generation Stages) and is used to correctly order the newly generated
-- Stream Cipher Key bits and to latch only the bits of the key that are valid until this stage.

entity sc_gen_state is
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
        fsrA_out: out SC_FSR := (others => (others => '0'));
        fsrB_out: out SC_FSR := (others => (others => '0'));
        E_out   : out NIBBLE := (others => '0');
        F_out   : out NIBBLE := (others => '0');
        X_out   : out NIBBLE := (others => '0');
        Y_out   : out NIBBLE := (others => '0');
        Z_out   : out NIBBLE := (others => '0');
        c_out   : out std_logic := '0';
        p_out   : out std_logic := '0';
        q_out   : out std_logic := '0';
        --KEY OUT
        KEY_out : out WORD := (others => '0')
    );
end entity;
                                                           
architecture arch of sc_gen_state is
    
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
    signal D, fsrA_next, fsrB_next, fsrB_tmp, Bout : NIBBLE;
    signal p_next, q_next, c_next, op_0, op_1 : std_logic;
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
    
    --OP OUTPUT BITS
    op_prc : process(D)
    begin
        op_1 <= D(2) xor D(3);
        op_0 <= D(0) xor D(1);
    end process;
    
    -- D STATE (NOT A REGISTER)
    D_prc : process(E, Z, Bout)
    begin
        D <= E xor Z xor Bout;
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
    fsrA_next <= fsrA(9) xor X;
    
    -- FSRB STATE
    fsrB_tmp <= fsrB(6) xor fsrB(9) xor Y;
    
    fsrB_next_prc : process(p, fsrB_tmp)
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
            c_out   <= c_next;
            p_out   <= p_next;
            q_out   <= q_next;
            --KEY REGISTER
            KEY_out((WORD_WIDTH-1)-(INDEX*2))       <= op_1;
            KEY_out((WORD_WIDTH-2)-(INDEX*2))       <= op_0;
            for i in WORD_WIDTH-1 downto WORD_WIDTH-(INDEX*2) loop
                KEY_out(i) <= KEY(i);
            end loop;
        end if;
    end process;
end architecture;
