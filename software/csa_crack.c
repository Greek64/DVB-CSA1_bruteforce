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

uint64_t crack(uint64_t a, unsigned char cb[]);

int main(int argc, char** argv){
    
    
    uint8_t tmp[8];
    if (argc != 5){
        printf("usage:\n");
        printf("csa_crack cw_start cw_cnt cw_final id\n\n");
        printf("CSA_CRACK will bruteforce all CW from cw_start to cw_start+cw_cnt.\n");
        printf("CSA_CRACK will output a percentage to know how much has already been brute forced\n");
        printf("CSA_CRACK will output all possible key candidates (Common words that decrypt to 0x000001).\n");
        printf("NOTE: CSA_CRACK uses libdvbcsa for encryption and decryption\n");
        printf("    cw_start    Start of the brute force Range of CW\n");
        printf("                Format:   665544332211 (48bits in downto order)\n");
        printf("    cw_cnt      Hex number of CW to iterate through. Max 6 hex bytes\n");
        printf("    cw_final    The CW to be found and used to encrypt the initial data\n");
        printf("                Format:   665544332211 (48bits in downto order)\n");
        printf("    id          The ID of this process printed in the output of this process.\n");
        printf("\n");
        return 1;
    }
    
    uint64_t cw, cw_cnt, cw_final;
    unsigned char ref[8] = {};
    uint8_t id;
    
    if (1 != sscanf(argv[1], "%12lX", &cw)){
      printf("cw_start format incorrect. 6 hex bytes expected.\n");
      return 4;
    }
    
    if (1 != sscanf(argv[2], "%12lX", &cw_cnt)){
      printf("cw_cnt format incorrect. 6 hex bytes expected.\n");
      return 4;
    }
    
    if (1 != sscanf(argv[3], "%12lX", &cw_final)){
      printf("cw_final format incorrect. 6 hex bytes expected.\n");
      return 4;
    }
    
    if (1 != sscanf(argv[4], "%1hX", &id)){
      printf("id format incorrect. 1 hex bytes expected.\n");
      return 4;
    }
    
    /*Key Initialisation*/
    ref[0] = (cw_final >> (0*4)) & 0xFF;
    ref[1] = (cw_final >> (1*4)) & 0xFF;
    ref[2] = (cw_final >> (2*4)) & 0xFF;
    ref[4] = (cw_final >> (4*4)) & 0xFF;
    ref[5] = (cw_final >> (5*4)) & 0xFF;
    ref[6] = (cw_final >> (6*4)) & 0xFF;
    ref[3] = ref[0] + ref[1] + ref[2];
    ref[7] = ref[4] + ref[5] + ref[6];
    dvbcsa_key_t   key;
    dvbcsa_key_set(ref, &key);
    
    /*The 184 Bytes to be encrypted/decrypted.*/
    unsigned char data[184] = {0x00, 0x00, 0x01};
    
    /*Encrypt via libdvbcsa*/
    dvbcsa_encrypt(&key, data, 184);
    
    uint64_t res;
    uint64_t x, w;
    uint8_t perc = 0;
    w = cw_cnt / 100;
    x = w;
    uint64_t match = 0;
    
    for(uint64_t cnt = 0; cnt < cw_cnt; cnt++){
        
        if(crack(cw, data) == 0x000001){
            //printf("ID:%d MATCH: %012lx\n", id, cw);
            match++;
        }
        if(cnt == x){
            perc++;
            x += w;
            printf("ID:%d %d%\n", id, perc);
        }
        cw++;
    }
    printf("ID:%d MATCHES: %lu\n", id, match);
    
    return 0;
}

uint64_t crack(uint64_t a, unsigned char cb[]){
    
    unsigned char data[16];
    memcpy(data, cb, 16*sizeof(unsigned char));
    unsigned char cw[8] = {};
    uint64_t res = 0;
    
    /*Key Initialisation*/
    cw[0] = (a >> (0*4)) & 0xFF;
    cw[1] = (a >> (1*4)) & 0xFF;
    cw[2] = (a >> (2*4)) & 0xFF;
    cw[4] = (a >> (4*4)) & 0xFF;
    cw[5] = (a >> (5*4)) & 0xFF;
    cw[6] = (a >> (6*4)) & 0xFF;
    cw[3] = cw[0] + cw[1] + cw[2];
    cw[7] = cw[4] + cw[5] + cw[6];
    dvbcsa_key_t   key;
    dvbcsa_key_set(cw, &key);
    
    /*Decrypt*/
    dvbcsa_decrypt(&key, data, 16);
    
    res = (((data[0] << 8) & 0xFF0000) | ((data[1] << 4) & 0xFF00) | ((data[2] << 0) & 0xFF)) & 0xFFFFFF;
    return res;
}
