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
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "libdvbcsa/dvbcsa/dvbcsa.h"


#define FSR_LENGTH  10
#define FSR_WIDTH   4

/*Function */
uint64_t block_cipher(uint64_t CB0, uint64_t key);
uint64_t stream_cipher(uint64_t CB0, uint64_t key);
uint8_t round_permutation(uint8_t data);
uint64_t bc_key_expand_permutation(uint64_t data);
uint64_t copy_array(unsigned char* a);
uint64_t format_fsr(uint8_t a[10][4]);

/*Stream Cipher SBoxes*/
const uint8_t sbox1[32] = {
    0b10, 0b00, 0b01, 0b01, 0b10, 0b11, 0b11, 0b00, 0b11, 0b10, 0b10, 0b00, 0b01, 0b01, 0b00, 0b11, 
    0b00, 0b11, 0b11, 0b00, 0b10, 0b10, 0b01, 0b01, 0b10, 0b10, 0b00, 0b11, 0b01, 0b01, 0b11, 0b00
};
const uint8_t sbox2[32] = {
    0b11, 0b01, 0b00, 0b10, 0b10, 0b11, 0b11, 0b00, 0b01, 0b11, 0b10, 0b01, 0b00, 0b00, 0b01, 0b10, 
    0b11, 0b01, 0b00, 0b11, 0b11, 0b10, 0b00, 0b10, 0b00, 0b00, 0b01, 0b10, 0b10, 0b01, 0b11, 0b01
};
const uint8_t sbox3[32] = {
    0b10, 0b00, 0b01, 0b10, 0b10, 0b11, 0b11, 0b01, 0b01, 0b01, 0b00, 0b11, 0b11, 0b00, 0b10, 0b00, 
    0b01, 0b11, 0b00, 0b01, 0b11, 0b00, 0b10, 0b10, 0b10, 0b00, 0b01, 0b10, 0b00, 0b11, 0b11, 0b01
};
const uint8_t sbox4[32] = {
    0b11, 0b01, 0b10, 0b11, 0b00, 0b10, 0b01, 0b10, 0b01, 0b10, 0b00, 0b01, 0b11, 0b00, 0b00, 0b11, 
    0b01, 0b00, 0b11, 0b01, 0b10, 0b11, 0b00, 0b11, 0b00, 0b11, 0b10, 0b00, 0b01, 0b10, 0b10, 0b01
};
const uint8_t sbox5[32] = {
    0b10, 0b00, 0b00, 0b01, 0b11, 0b10, 0b11, 0b10, 0b00, 0b01, 0b11, 0b11, 0b01, 0b00, 0b10, 0b01, 
    0b10, 0b11, 0b10, 0b00, 0b00, 0b11, 0b01, 0b01, 0b01, 0b00, 0b11, 0b10, 0b11, 0b01, 0b00, 0b10
};
const uint8_t sbox6[32] = {
    0b00, 0b01, 0b10, 0b11, 0b01, 0b10, 0b10, 0b00, 0b00, 0b01, 0b11, 0b00, 0b10, 0b11, 0b01, 0b11, 
    0b10, 0b11, 0b00, 0b10, 0b11, 0b00, 0b01, 0b01, 0b10, 0b01, 0b01, 0b10, 0b00, 0b11, 0b11, 0b00
};
const uint8_t sbox7[32] = {
    0b00, 0b11, 0b10, 0b10, 0b11, 0b00, 0b00, 0b01, 0b11, 0b00, 0b01, 0b11, 0b01, 0b10, 0b10, 0b01, 
    0b01, 0b00, 0b11, 0b11, 0b00, 0b01, 0b01, 0b10, 0b10, 0b11, 0b01, 0b00, 0b10, 0b11, 0b00, 0b10
};
/*Block Cipher SBox*/
const uint8_t sbox[256] = {
       0x3a, 0xea, 0x68, 0xfe, 0x33, 0xe9, 0x88, 0x1a, 0x83, 0xcf, 0xe1, 0x7f, 0xba, 0xe2, 0x38, 0x12,
       0xe8, 0x27, 0x61, 0x95, 0x0c, 0x36, 0xe5, 0x70, 0xa2, 0x06, 0x82, 0x7c, 0x17, 0xa3, 0x26, 0x49,
       0xbe, 0x7a, 0x6d, 0x47, 0xc1, 0x51, 0x8f, 0xf3, 0xcc, 0x5b, 0x67, 0xbd, 0xcd, 0x18, 0x08, 0xc9,
       0xff, 0x69, 0xef, 0x03, 0x4e, 0x48, 0x4a, 0x84, 0x3f, 0xb4, 0x10, 0x04, 0xdc, 0xf5, 0x5c, 0xc6,
       0x16, 0xab, 0xac, 0x4c, 0xf1, 0x6a, 0x2f, 0x3c, 0x3b, 0xd4, 0xd5, 0x94, 0xd0, 0xc4, 0x63, 0x62,
       0x71, 0xa1, 0xf9, 0x4f, 0x2e, 0xaa, 0xc5, 0x56, 0xe3, 0x39, 0x93, 0xce, 0x65, 0x64, 0xe4, 0x58,
       0x6c, 0x19, 0x42, 0x79, 0xdd, 0xee, 0x96, 0xf6, 0x8a, 0xec, 0x1e, 0x85, 0x53, 0x45, 0xde, 0xbb,
       0x7e, 0x0a, 0x9a, 0x13, 0x2a, 0x9d, 0xc2, 0x5e, 0x5a, 0x1f, 0x32, 0x35, 0x9c, 0xa8, 0x73, 0x30,
       0x29, 0x3d, 0xe7, 0x92, 0x87, 0x1b, 0x2b, 0x4b, 0xa5, 0x57, 0x97, 0x40, 0x15, 0xe6, 0xbc, 0x0e,
       0xeb, 0xc3, 0x34, 0x2d, 0xb8, 0x44, 0x25, 0xa4, 0x1c, 0xc7, 0x23, 0xed, 0x90, 0x6e, 0x50, 0x00,
       0x99, 0x9e, 0x4d, 0xd9, 0xda, 0x8d, 0x6f, 0x5f, 0x3e, 0xd7, 0x21, 0x74, 0x86, 0xdf, 0x6b, 0x05,
       0x8e, 0x5d, 0x37, 0x11, 0xd2, 0x28, 0x75, 0xd6, 0xa7, 0x77, 0x24, 0xbf, 0xf0, 0xb0, 0x02, 0xb7,
       0xf8, 0xfc, 0x81, 0x09, 0xb1, 0x01, 0x76, 0x91, 0x7d, 0x0f, 0xc8, 0xa0, 0xf2, 0xcb, 0x78, 0x60,
       0xd1, 0xf7, 0xe0, 0xb5, 0x98, 0x22, 0xb3, 0x20, 0x1d, 0xa6, 0xdb, 0x7b, 0x59, 0x9f, 0xae, 0x31,
       0xfb, 0xd3, 0xb6, 0xca, 0x43, 0x72, 0x07, 0xf4, 0xd8, 0x41, 0x14, 0x55, 0x0d, 0x54, 0x8b, 0xb9,
       0xad, 0x46, 0x0b, 0xaf, 0x80, 0x52, 0x2c, 0xfa, 0x8c, 0x89, 0x66, 0xfd, 0xb2, 0xa9, 0x9b, 0xc0
       };
/*Block Cipher Key Expansion Constant*/
const uint64_t bc_key_expand_magic[7] = { 0x0000000000000000, 0x0101010101010101, 0x0202020202020202, 
                                        0x0303030303030303, 0x0404040404040404, 0x0505050505050505, 
                                        0x0606060606060606 };

int main(int argc, char** argv){
    
    
    uint8_t tmp[8];
    if (argc != 2){
        printf("usage:\n");
        printf("csa cw\n\n");
        printf("CSA will encrypt a plaintext with the given common word using libdvbcsa and then try to decrypt it with\n");
        printf("a proof-of-concept software implementation of DVB-CSA1.\n");
        printf("cw          48bit common word (In hex downto order: 665544332211)(12 Numbers)\n");
        printf("\n");
        return 1;
    }
    
    /*CW Parsing and expansion from 48 to 64 bits*/
    if (6 != sscanf(argv[1], "%02hhX%02hhX%02hhX%02hhX%02hhX%02hhX", &tmp[6], &tmp[5], &tmp[4], &tmp[2], &tmp[1], &tmp[0])){
      printf("cw format incorrect. 6 hex bytes expected.\n");
      return 4;
    }
    tmp[3] = tmp[0] + tmp[1] + tmp[2];
    tmp[7] = tmp[4] + tmp[5] + tmp[6];
    
    /*CW in uint64_t Format*/
    uint64_t cw = 0;
    for(int i = 0; i < 8; i++) {
        cw |= ((uint64_t)(tmp[i] & 0xFF)) << (i*8);
    }
    
    /*The 184 Bytes to be encrypted/decrypted. (PLAINTEXT)*/
    unsigned char data[184] = {0x00, 0x00, 0x01, 0x03};
    
    dvbcsa_key_t   key;
    uint64_t CB0, CB1;
    
    
    printf("Read expanded CW is:   0x%016lx\n", cw);
    dvbcsa_key_set(tmp, &key);
    
    /*Print first two Plaintext Blocks*/
    printf("Read PB0 is:           0x%02x%02x%02x%02x%02x%02x%02x%02x\n", 
        data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]);
    printf("Read PB1 is:           0x%02x%02x%02x%02x%02x%02x%02x%02x\n", 
        data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15]);
    
    /*Encrypt via libdvbcsa*/
    dvbcsa_encrypt(&key, data, 184);
    
    /*Print the first two Cipher/Scrambled Blocks*/
    printf("CB0 is :               0x%02x%02x%02x%02x%02x%02x%02x%02x\n", 
        data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]);
    printf("CB1 is :               0x%02x%02x%02x%02x%02x%02x%02x%02x\n", 
        data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15]);
    
    /*Copy the blocks for SW decryption*/
    CB0 = copy_array(data);
    CB1 = copy_array(data + 8);
    
    /*Test decrypt with libdvbcsa again*/
    dvbcsa_decrypt(&key, data, 16);
    
    /**SW DECRYPTION**/
    /*NOTE: For some reason the Stream Cipher needs the Nibble Swapped Key.*/
    uint64_t stream_out = stream_cipher(CB0, 
        ((cw & 0xf0f0f0f0f0f0f0f0ULL) >> 4) | ((cw & 0x0f0f0f0f0f0f0f0fULL) << 4));
    printf("SW Stream Cipher       0x%016lx\n", stream_out);
    
    uint64_t IB1 = CB1 ^ stream_out;
    printf("SW IB1                 0x%016lx\n", IB1);
    
    uint64_t block_out = block_cipher(CB0, cw);
    printf("SW Block Cipher        0x%016lx\n", block_out);
    
    printf("SW decrypted to        0x%016lx\n", IB1 ^ block_out);
    printf("LIBDVBCSA decrypted to 0x%02x%02x%02x%02x%02x%02x%02x%02x\n", 
        data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]);
    
    return 0;
}

uint64_t block_cipher(uint64_t CB0, uint64_t key){
    static uint8_t ex_key[56];
    
    /*Key Expansion*/
    uint64_t tmp = key;
    //printf("SW key 0x%016lx\n", tmp);
    for(int i = 6; i >= 0; i--){ //Reversed according to da_diet & dvbcsa_lib
        uint64_t k = tmp ^ bc_key_expand_magic[i];
        //printf("SW k[%d] 0x%016lx\n", i, k);
        for(int j = 0; j < 8; j++){
            ex_key[(i*8)+j] = (k >> (j*8)) & 0xFF;
        }
        tmp = bc_key_expand_permutation(tmp);
    }
    
    uint8_t W[8];
    
    for(int i = 0; i < 8; i++){
        W[i] = (CB0 >> ((7-i)*8)) & 0xFF;
    }
    //printf("SW CB0=0x%016lx\n", CB0);
    //printf("SW W=0x%02x%02x%02x%02x%02x%02x%02x%02x\n", W[0], W[1], W[2], W[3], W[4], W[5], W[6], W[7]);
    
    /*Round Function*/
    for(int i = 55; i >= 0; i--){ //56 times
        
        //printf("SW Round %d Key 0x%02x\n", i, ex_key[i]);
        
        //printf("SW W=0x%02x%02x%02x%02x%02x%02x%02x%02x\n", W[7], W[6], W[5], W[4], W[3], W[2], W[1], W[0]);
        
        uint8_t S = sbox[ex_key[i] ^ W[6]];
        uint8_t L = W[7] ^ S;

        W[7] = W[6];
        W[6] = W[5] ^ round_permutation(S);
        W[5] = W[4];
        W[4] = W[3] ^ L;
        W[3] = W[2] ^ L;
        W[2] = W[1] ^ L;
        W[1] = W[0];
        W[0] = L;
        
    }
    
    //printf("SW W after 0x%02x%02x%02x%02x%02x%02x%02x%02x\n", W[7], W[6], W[5], W[4], W[3], W[2], W[1], W[0]);
    
    uint64_t res = 0;
    for(int i = 0; i < 8; i++){
        res |= ((uint64_t)(W[i] & 0xFF)) << ((7-i)*8); 
    }
    return res;
}

uint64_t stream_cipher(uint64_t CB0, uint64_t key){
    //Feedback Shift Registers (Two Dimensional BIT Array)
    static uint8_t fsrA[10][4];
    static uint8_t fsrB[10][4];
    //NIBBLE Registers (D is actually not a Register)
    static uint8_t E, F, X, Y, Z, D;
    //BIT Registers
    static uint8_t c, p, q;
    //Stream Cipher Key
    static uint64_t sc_key;
    
    uint8_t a0, b0, a9, b9, b6, bout, tmp, s1, s2, s3, s4, s5 ,s6, s7, addr;
    
    /*Initial FSR Loadup*/
    for(int i = 0; i < FSR_LENGTH-2; i++){
        for(int j = 0; j < FSR_WIDTH; j++){
            fsrA[i][j] = (key >> ((4*i)+j)) & 0x1;
            fsrB[i][j] = (key >> (32+(4*i)+j)) & 0x1;
        }
    }
    
    //printf("SW initial fsrA 0x%016lx\n", format_fsr(fsrA));
    //printf("SW initial fsrB 0x%016lx\n", format_fsr(fsrB));
    
    uint8_t byte_num, IA, IB;
    for(int clk = 0; clk < 64; clk++){
        if(clk < 32 && clk % 4 == 0){
            byte_num = clk / 4;
            IB = (CB0 >> (8 * (7-byte_num))) & 0xF;
            IA = ((CB0 >> (8 * (7-byte_num))) >> 4) & 0xF;
        }
        a9 = (((fsrA[9][3] << 3) & 0x8) | ((fsrA[9][2] << 2) & 0x4) | ((fsrA[9][1] << 1) & 0x2) | ((fsrA[9][0] << 0) & 0x1)) & 0xF;
        b9 = (((fsrB[9][3] << 3) & 0x8) | ((fsrB[9][2] << 2) & 0x4) | ((fsrB[9][1] << 1) & 0x2) | ((fsrB[9][0] << 0) & 0x1)) & 0xF;
        b6 = (((fsrB[6][3] << 3) & 0x8) | ((fsrB[6][2] << 2) & 0x4) | ((fsrB[6][1] << 1) & 0x2) | ((fsrB[6][0] << 0) & 0x1)) & 0xF;
        bout = ((((fsrB[2][0] ^ fsrB[5][1] ^ fsrB[6][2] ^ fsrB[8][3]) << 3) & 0x8) |
                (((fsrB[5][0] ^ fsrB[7][1] ^ fsrB[2][3] ^ fsrB[3][2]) << 2) & 0x4) |
                (((fsrB[4][3] ^ fsrB[7][2] ^ fsrB[3][0] ^ fsrB[4][1]) << 1) & 0x2) |
                (((fsrB[8][2] ^ fsrB[5][3] ^ fsrB[2][1] ^ fsrB[7][0]) << 0) & 0x1)) & 0xF;
        
        /*Main State and Output Generation*/
        /*INITIALIZATION MODE*/
        if(clk < 32){
            a0 = a9 ^ X ^ D ^ IA;
            //printf("SW a9=0x%x X=0x%x D=0x%x, IA=0x%x\n", a9, X, D, IA);
            b0 = b6 ^ b9 ^ Y ^ IB;
            //printf("SW b6=0x%x b9=0x%x\n", b6, b9);
            /*Swapp Nibbles*/
            //printf("SW IA=0x%x IB=0x%x\n", IA, IB);
            tmp = IA;
            IA = IB;
            IB = tmp;
            /*Calculate next D*/
            D = E ^ Z ^ bout;
        }
        /*GENERATION MODE*/
        else{
            a0 = a9 ^ X;
            b0 = b6 ^ b9 ^ Y;
            /*Calculate next D*/
            D = E ^ Z ^ bout;
            uint8_t k1 = (((D >> 3) & 0x1) ^ ((D >> 2) & 0x1)) & 0x1;
            uint8_t k0 = (((D >> 1) & 0x1) ^ ((D >> 0) & 0x1)) & 0x1;
            sc_key = (sc_key << 2) | (k1 << 1) | k0;
        }
        if(p == 1){
            b0 = ((b0 << 1) | ((b0 & 0x8) >> 3)) & 0xF; //rol 1
        }
        
        /*E,F,c State*/
        if(q == 0){
            tmp = E;
            E = F;
            F = tmp;
        }
        else{
            tmp = E + Z + c;
            E = F;
            F = tmp & 0xF;
            c = (tmp >> 4 ) & 0x1;
        }
        
        /*SBOX magic*/
        addr = (((fsrA[3][0] << 4) & 0x10) | ((fsrA[0][2] << 3) & 0x8) | ((fsrA[5][1] << 2) & 0x4) | 
                ((fsrA[6][3] << 1) & 0x2) | ((fsrA[8][0] << 0) & 0x1)) & 0x1F;
        s1 = sbox1[addr];
        //printf("SW SBOX addr1=%02x ", addr);
        addr = (((fsrA[1][1] << 4) & 0x10) | ((fsrA[2][2] << 3) & 0x8) | ((fsrA[5][3] << 2) & 0x4) | 
                ((fsrA[6][0] << 1) & 0x2) | ((fsrA[8][1] << 0) & 0x1)) & 0x1F;
        s2 = sbox2[addr];
        //printf("addr2=%02x ", addr);
        addr = (((fsrA[0][3] << 4) & 0x10) | ((fsrA[1][0] << 3) & 0x8) | ((fsrA[4][1] << 2) & 0x4) | 
                ((fsrA[4][3] << 1) & 0x2) | ((fsrA[5][2] << 0) & 0x1)) & 0x1F;
        s3 = sbox3[addr];
        //printf("addr3=%02x ", addr);
        addr = (((fsrA[2][3] << 4) & 0x10) | ((fsrA[0][1] << 3) & 0x8) | ((fsrA[1][3] << 2) & 0x4) | 
                ((fsrA[3][2] << 1) & 0x2) | ((fsrA[7][0] << 0) & 0x1)) & 0x1F;
        s4 = sbox4[addr];
        //printf("addr4=%02x ", addr);
        addr = (((fsrA[4][2] << 4) & 0x10) | ((fsrA[3][3] << 3) & 0x8) | ((fsrA[5][0] << 2) & 0x4) | 
                ((fsrA[7][1] << 1) & 0x2) | ((fsrA[8][2] << 0) & 0x1)) & 0x1F;
        s5 = sbox5[addr];
        //printf("addr5=%02x ", addr);
        addr = (((fsrA[2][1] << 4) & 0x10) | ((fsrA[3][1] << 3) & 0x8) | ((fsrA[4][0] << 2) & 0x4) | 
                ((fsrA[6][2] << 1) & 0x2) | ((fsrA[8][3] << 0) & 0x1)) & 0x1F;
        s6 = sbox6[addr];
        //printf("addr6=%02x ", addr);
        addr = (((fsrA[1][2] << 4) & 0x10) | ((fsrA[2][0] << 3) & 0x8) | ((fsrA[6][1] << 2) & 0x4) | 
                ((fsrA[7][2] << 1) & 0x2) | ((fsrA[7][3] << 0) & 0x1)) & 0x1F;
        s7 = sbox7[addr];
        //printf("addr7=%02x\n", addr);
        
        /*X,Y,Z,p,q State*/
        X = (((s4 << 3) & 0x8) | ((s3 << 2) & 0x4) | (s2 & 0x2) | ((s1 >> 1) & 0x1)) & 0xF; //s40, s30, s21, s11
        Y = (((s6 << 3) & 0x8) | ((s5 << 2) & 0x4) | (s4 & 0x2) | ((s3 >> 1) & 0x1)) & 0xF; //s60, s50, s41, s31
        Z = (((s2 << 3) & 0x8) | ((s1 << 2) & 0x4) | (s6 & 0x2) | ((s5 >> 1) & 0x1)) & 0xF; //s20, s10, s61, s51
        p = (s7 >> 1) & 0x1; // s71
        q = s7 & 0x1; //s70
        
        /*Shift Registers*/
        for(int i = FSR_LENGTH-1; i > 0; i--){
            fsrA[i][3] = fsrA[i-1][3];
            fsrA[i][2] = fsrA[i-1][2];
            fsrA[i][1] = fsrA[i-1][1];
            fsrA[i][0] = fsrA[i-1][0];
            fsrB[i][3] = fsrB[i-1][3];
            fsrB[i][2] = fsrB[i-1][2];
            fsrB[i][1] = fsrB[i-1][1];
            fsrB[i][0] = fsrB[i-1][0];
        }
        fsrA[0][3] = (a0 >> 3) & 0x1;
        fsrA[0][2] = (a0 >> 2) & 0x1;
        fsrA[0][1] = (a0 >> 1) & 0x1;
        fsrA[0][0] = (a0 >> 0) & 0x1;
        fsrB[0][3] = (b0 >> 3) & 0x1;
        fsrB[0][2] = (b0 >> 2) & 0x1;
        fsrB[0][1] = (b0 >> 1) & 0x1;
        fsrB[0][0] = (b0 >> 0) & 0x1;
        
        //------------------------------
        /*
        if(clk > 31){
            printf("SW c=0x%x, F=0x%x, E=0x%x, D=0x%x\n", c, F, E, D);
            printf("SW p=0x%x, q=0x%x, Z=0x%x, Y=0x%x, X=0x%x\n", p, q, Z, Y, X);
            printf("SW fsrA 0x%016lx\n", format_fsr(fsrA));
            printf("SW fsrB 0x%016lx\n", format_fsr(fsrB));
        }
        
        if(clk == 31) {
            printf("SW after initialization: c=0x%x, F=0x%x, E=0x%x, D=0x%x\n", c, F, E, D);
            printf("SW after initialization: p=0x%x, q=0x%x, Z=0x%x, Y=0x%x, X=0x%x\n", p, q, Z, Y, X);
            printf("SW fsrA 0x%016lx\n", format_fsr(fsrA));
            printf("SW fsrB 0x%016lx\n", format_fsr(fsrB));
        }
        */
    }
    return sc_key;
}

uint64_t copy_array(unsigned char* a){
    
    uint64_t res = 0;
    
    for(int i = 0; i < 8; i++) {
        res |= ((uint64_t)(a[i] & 0xFF)) << ((7-i)*8);
    }
    return res;
}

uint64_t format_fsr(uint8_t a[10][4]){
    
    uint64_t res = 0;
    uint8_t tmp;

    for(int i = 0; i < FSR_LENGTH; i++){
        tmp = 0;
        for(int j = 0; j < FSR_WIDTH; j++){
             tmp |= a[i][j] << j;
        }
        res |= ((uint64_t) tmp) << (i*4);
    }
    return res;
}

uint8_t round_permutation(uint8_t data){
    uint8_t res = 0;
    res |= ((data >> 0) & 0x1) << 1;
    res |= ((data >> 1) & 0x1) << 7;
    res |= ((data >> 2) & 0x1) << 5;
    res |= ((data >> 3) & 0x1) << 4;
    res |= ((data >> 4) & 0x1) << 2;
    res |= ((data >> 5) & 0x1) << 6;
    res |= ((data >> 6) & 0x1) << 0;
    res |= ((data >> 7) & 0x1) << 3;
    return res;
}

uint64_t bc_key_expand_permutation(uint64_t data){
    
    uint64_t res = 0;
    
    res |= ((data >> 0 ) & 0x1) << 19;
    res |= ((data >> 1 ) & 0x1) << 27;
    res |= ((data >> 2 ) & 0x1) << 55;
    res |= ((data >> 3 ) & 0x1) << 46;
    res |= ((data >> 4 ) & 0x1) <<  1;
    res |= ((data >> 5 ) & 0x1) << 15;
    res |= ((data >> 6 ) & 0x1) << 36;
    res |= ((data >> 7 ) & 0x1) << 22;
    res |= ((data >> 8 ) & 0x1) << 56;
    res |= ((data >> 9 ) & 0x1) << 61;
    res |= ((data >> 10) & 0x1) << 39;
    res |= ((data >> 11) & 0x1) << 21;
    res |= ((data >> 12) & 0x1) << 54;
    res |= ((data >> 13) & 0x1) << 58;
    res |= ((data >> 14) & 0x1) << 50;
    res |= ((data >> 15) & 0x1) << 28;
    res |= ((data >> 16) & 0x1) <<  7;
    res |= ((data >> 17) & 0x1) << 29;
    res |= ((data >> 18) & 0x1) << 51;
    res |= ((data >> 19) & 0x1) <<  6;
    res |= ((data >> 20) & 0x1) << 33;
    res |= ((data >> 21) & 0x1) << 35;
    res |= ((data >> 22) & 0x1) << 20;
    res |= ((data >> 23) & 0x1) << 16;
    res |= ((data >> 24) & 0x1) << 47;
    res |= ((data >> 25) & 0x1) << 30;
    res |= ((data >> 26) & 0x1) << 32;
    res |= ((data >> 27) & 0x1) << 63;
    res |= ((data >> 28) & 0x1) << 10;
    res |= ((data >> 29) & 0x1) << 11;
    res |= ((data >> 30) & 0x1) <<  4;
    res |= ((data >> 31) & 0x1) << 38;
    res |= ((data >> 32) & 0x1) << 62;
    res |= ((data >> 33) & 0x1) << 26;
    res |= ((data >> 34) & 0x1) << 40;
    res |= ((data >> 35) & 0x1) << 18;
    res |= ((data >> 36) & 0x1) << 12;
    res |= ((data >> 37) & 0x1) << 52;
    res |= ((data >> 38) & 0x1) << 37;
    res |= ((data >> 39) & 0x1) << 53;
    res |= ((data >> 40) & 0x1) << 23;
    res |= ((data >> 41) & 0x1) << 59;
    res |= ((data >> 42) & 0x1) << 41;
    res |= ((data >> 43) & 0x1) << 17;
    res |= ((data >> 44) & 0x1) << 31;
    res |= ((data >> 45) & 0x1) <<  0;
    res |= ((data >> 46) & 0x1) << 25;
    res |= ((data >> 47) & 0x1) << 43;
    res |= ((data >> 48) & 0x1) << 44;
    res |= ((data >> 49) & 0x1) << 14;
    res |= ((data >> 50) & 0x1) <<  2;
    res |= ((data >> 51) & 0x1) << 13;
    res |= ((data >> 52) & 0x1) << 45;
    res |= ((data >> 53) & 0x1) << 48;
    res |= ((data >> 54) & 0x1) <<  3;
    res |= ((data >> 55) & 0x1) << 60;
    res |= ((data >> 56) & 0x1) << 49;
    res |= ((data >> 57) & 0x1) <<  8;
    res |= ((data >> 58) & 0x1) << 34;
    res |= ((data >> 59) & 0x1) << 05;
    res |= ((data >> 60) & 0x1) <<  9;
    res |= ((data >> 61) & 0x1) << 42;
    res |= ((data >> 62) & 0x1) << 57;
    res |= ((data >> 63) & 0x1) << 24;
    return res;
}
