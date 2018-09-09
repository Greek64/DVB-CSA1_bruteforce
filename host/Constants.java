/*
DVB-CSA1 Brute-force FPGA Implementation
Copyright (C) 2018  Ioannis Daktylidis

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
final public class Constants{

    //Enumeration containing all the supported ZTEX Board types
    public enum BoardEnum{
        Z115Y, Z216;
    }

    //The Number of FPGAs per Board
    public static final int FPGA_NUM_1_15y = 4;
    public static final int FPGA_NUM_2_16 = 1;
    //Number of Samples
    public static final int SAMPLE_NUM = 3;
    public static final int RETRY_NUM = 3;
    //The Size of a Plaintext/Ciphertext Block.
    public static final int SAMPLE_BLOCK_SIZE = 8;
    //The Number of Blocks per Sample
    public static final int NUM_BLOCK_PER_SAMPLE = 2;
    //The Size of the startCW (48 bits)
    public static final int START_CW_SIZE = 6;
    //INPUT (From perspective of the Host)
    //8bit  DONE, FOUND, FILL   (1 Byte)
    //64bit FOUND KEY           (8 Bytes)
    //TOTAL 72bit (9 Bytes)
    public static final int INPUT_SIZE = 9;
    //OUTPUT: (From perspective of the Host)
    //48bit START CW        (6 Bytes)
    //64bit CB0 SAMPLE 1    (8 Bytes)
    //64bit CB1 SAMPLE 1    (8 Bytes)
    //64bit CB0 SAMPLE 2    (8 Bytes)
    //64bit CB1 SAMPLE 2    (8 Bytes)
    //64bit CB0 SAMPLE 3    (8 Bytes)
    //64bit CB1 SAMPLE 3    (8 Bytes)
    //TOTAL: 432bit (54 bytes)
    public static final int OUTPUT_SIZE = START_CW_SIZE + (SAMPLE_NUM*NUM_BLOCK_PER_SAMPLE*SAMPLE_BLOCK_SIZE);
    
    /*This method is used to generate a HEX String representation of the Common Word/Key*/
    public static String hexString(byte[] data){
        String tmp = "";
        for (int i = 0; i < data.length; i++){
            int n = (data[i] & 0xF0) >> 4;
            tmp = tmp + Integer.toHexString(n).toUpperCase();
            n = data[i] & 0x0F;
            tmp = tmp + Integer.toHexString(n).toUpperCase();
        }
        return tmp;
    }
}
