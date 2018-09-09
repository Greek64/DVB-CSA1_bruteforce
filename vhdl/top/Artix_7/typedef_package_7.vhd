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

package typedef_package is
    --*****CONSTANT DECLARATIONS*****
    --***CONFIG***
    constant MAX_FPGA_NUM : integer := 1;
    constant MAX_CORE_NUM : integer := 17;
    constant KEY_GEN_CONST : integer := 5; --TODO log2(32)
    constant SAMPLE_NUM : integer := 3;
    --************
    constant CW_WIDTH : integer := 48;
    constant NIBBLE_WIDTH : integer := 4;
    constant BYTE_ARRAY_WIDTH : integer := 8;
    constant BYTE_WIDTH : integer := 8;
    constant WORD_WIDTH : integer := (BYTE_WIDTH*BYTE_ARRAY_WIDTH);
    constant WORD_BYTES : integer := WORD_WIDTH/BYTE_WIDTH;
    --BLOCK CIPHER
    constant ROUND_NUM : integer := 56;
    constant BC_STAGE_NUM : integer := ROUND_NUM+1;
    constant BC_KEY_EXP_STAGES : integer := 7;
    constant BC_KEY_EXP_WIDTH : integer := (WORD_WIDTH*BC_KEY_EXP_STAGES);
    --STREAM CIPHER
    constant SC_FSR_WIDTH : integer := 4;
    constant SC_FSR_LENGTH : integer := 10;
    constant SC_INIT_STAGES : integer := 32;
    constant SC_GEN_STAGES : integer := 32;
    constant SC_STAGE_NUM : integer := SC_GEN_STAGES+SC_INIT_STAGES;
    --DECODE CORE UNIT
    constant DCU_STAGE_NUM : integer := 68;
    --TOP
    constant INPUT_DATA_BYTES : integer := 54;
    constant OUTPUT_DATA_BYTES : integer := 9;
    constant INPUT_DATA_WIDTH : integer := INPUT_DATA_BYTES*BYTE_WIDTH;
    constant OUTPUT_DATA_WIDTH : integer := OUTPUT_DATA_BYTES*BYTE_WIDTH;
    
    
    --*****SUBTYPE DECLARATIONS*****
    subtype NIBBLE is std_logic_vector(NIBBLE_WIDTH-1 downto 0);
    subtype BYTE is std_logic_vector(BYTE_WIDTH-1 downto 0);
    subtype WORD is std_logic_vector(WORD_WIDTH-1 downto 0);
    --CCU
    subtype KEY_GEN_TYPE is unsigned(CW_WIDTH-KEY_GEN_CONST-1 downto 0);
    subtype FPGA_NUM_TYPE is std_logic_vector(KEY_GEN_CONST-1 downto 0);
    subtype CW_TYPE is unsigned(CW_WIDTH-1 downto 0);
    subtype CW_TYPE_SLV is std_logic_vector(CW_WIDTH-1 downto 0);
    --BLOCK CIPHER
    subtype BC_KEY is std_logic_vector(BC_KEY_EXP_WIDTH-1 downto 0);
    --STREAM CIPHER
    subtype SC_FSR_NIBBLE is std_logic_vector(SC_FSR_WIDTH-1 downto 0);
    --TOP
    subtype INPUT_DATA_TYPE is std_logic_vector(INPUT_DATA_WIDTH-1 downto 0);
    
    
    --*****ARRAY DECLARATIONS*****
    type BYTE_ARRAY is array (BYTE_ARRAY_WIDTH-1 downto 0) of BYTE;
    --STREAM CIPHER
    type SC_FSR is array (SC_FSR_LENGTH-1 downto 0) of SC_FSR_NIBBLE;
    --CCU
    type CIPHER_ARRAY_INNER is array (1 downto 0) of WORD;
    type CIPHER_ARRAY is array (SAMPLE_NUM-1 downto 0) of CIPHER_ARRAY_INNER;
    
    
    --*****FUNCTION DECLARATIONS*****
    function MUL_CONST(constant A,B : unsigned; constant LEN : integer) return unsigned;
    function from_BYTE_ARRAY(a : BYTE_ARRAY) return std_logic_vector;
    function to_BYTE_ARRAY(a : WORD) return BYTE_ARRAY;
    function from_BYTE_ARRAY_inv(a : BYTE_ARRAY) return std_logic_vector;
    function to_BYTE_ARRAY_inv(a : WORD) return BYTE_ARRAY;
    --BLOCK CIPHER
    function to_NIBBLE(a : std_logic) return NIBBLE;
    --STREAM CIPHER
    function nibble_swap(a : std_logic_vector) return std_logic_vector;
    
end package;

package body typedef_package is
    
    
    --*****FUNCTION DEFINITIONS*****
    function MUL_CONST(constant A,B : unsigned; constant LEN : integer) return unsigned is
        variable tmp : unsigned((A'Length + B'Length)-1 downto 0);
        variable ret : unsigned(LEN-1 downto 0);
    begin
        tmp := A * B;
        ret := tmp(LEN-1 downto 0);
        return ret;
    end function;
    
    
    
    function nibble_swap(a : std_logic_vector) return std_logic_vector is
        variable ret : WORD;
        variable tmp, tmp2 : BYTE;
        variable x : integer range 0 to WORD_WIDTH-1;
    begin
        for i in 0 to (WORD_WIDTH/BYTE_WIDTH)-1 loop
            x   := i*BYTE_WIDTH;
            tmp := a(x+(BYTE_WIDTH-1) downto x);
            tmp2(7 downto 4)    := tmp(3 downto 0);
            tmp2(3 downto 0)    := tmp(7 downto 4);
            ret(x+(BYTE_WIDTH-1) downto x) := tmp2;
        end loop;
        return ret;
    end function;
    
    
    
    function to_NIBBLE(a : std_logic) return NIBBLE is
        variable ret : NIBBLE;
    begin
        ret := (others => '0');
        ret(0) := a;
        return ret;
    end function;
    
    
    
    function from_BYTE_ARRAY(a : BYTE_ARRAY) return std_logic_vector is
        variable ret : WORD;
        variable x : integer range 0 to WORD_WIDTH-1;
    begin
        for i in 0 to BYTE_ARRAY_WIDTH-1 loop
            x := (i*BYTE_WIDTH); 
            ret(x+(BYTE_WIDTH-1) downto x) := a(i);
        end loop;
        return ret;  
    end function;
    
    
    
    function from_BYTE_ARRAY_inv(a : BYTE_ARRAY) return std_logic_vector is
        variable ret : WORD;
        variable x : integer range 0 to WORD_WIDTH-1;
    begin
        for i in 0 to BYTE_ARRAY_WIDTH-1 loop
            x := ((BYTE_ARRAY_WIDTH-1-i)*BYTE_WIDTH); 
            ret(x+(BYTE_WIDTH-1) downto x) := a(i);
        end loop;
        return ret;  
    end function;
    
    
    
    function to_BYTE_ARRAY(a : WORD) return BYTE_ARRAY is
        variable ret : BYTE_ARRAY;
        variable x : integer range 0 to WORD_WIDTH-1;
    begin
        for i in 0 to BYTE_ARRAY_WIDTH-1 loop
            x := (i*BYTE_WIDTH);
            ret(i) := a(x+(BYTE_WIDTH-1) downto x);
        end loop;
        return ret;        
    end function;
    
    
    
    function to_BYTE_ARRAY_inv(a : WORD) return BYTE_ARRAY is
        variable ret : BYTE_ARRAY;
        variable x : integer range 0 to WORD_WIDTH-1;
    begin
        for i in 0 to BYTE_ARRAY_WIDTH-1 loop
            x := ((BYTE_ARRAY_WIDTH-1-i)*BYTE_WIDTH);
            ret(i) := a(x+(BYTE_WIDTH-1) downto x);
        end loop;
        return ret;        
    end function;
end package body;
