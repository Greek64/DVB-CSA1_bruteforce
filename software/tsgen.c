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
//Before glibc 2.10
#define _GNU_SOURCE
//Since glibc 2.16
//#define _POSIX_C_SOURCE >= 200809L || _XOPEN_SOURCE >= 700
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libdvbcsa/dvbcsa/dvbcsa.h"

int main(int argc, char *argv[]){
    int i, cnt;
    FILE* wr;
    FILE* rd;
    unsigned char cw[8];
    unsigned char buf[188];
    dvbcsa_key_t key;
    char* line = NULL;
    size_t size = 0;
    int even = 1; 
    
    /*ARGUMENT CHECK*/
    if (argc != 3){
        printf("usage:\n");
        printf("tsgen tsfile keyfile\n\n");
        printf("TSGEN will generate a transport stream (ts) file containing 4 encrypted packets for each key\n");
        printf("inside the keyfile. These packets decrypt to packets starting with MPEG PES header (0x00 0x00 0x01...),\n");
        printf("have an increasing continuity counter, use the transport scrambling control field (odd/even keys),");
        printf("and have slightly different payloads.\n\n");
        printf("tsfile      Output ts file name\n");
        printf("keyfile     Path to file containing the Common Words to encrypt the packets with.\n");
        printf("            Format:   665544332211 (48bits in downto order) and separated with a new line.\n");
        printf("\n");
        exit(0);
    }
    
    /*OPEN FILES*/
    wr = fopen(argv[1], "w");
    if(wr == NULL){
        printf("Error opening file %s for writing\n", argv[1]);
        exit(2);
    }
    rd = fopen(argv[2], "r");
    if(rd == NULL){
        printf("Error opening file %s for reading\n", argv[2]);
        exit(2);
    }
    
    /*READ LOOP*/
    cnt = 0;
    while(getline(&line, &size, rd) != -1){
        /*PARSE KEY*/
        if (6 != sscanf(line, "%02hhX%02hhX%02hhX%02hhX%02hhX%02hhX", &cw[6], &cw[5], &cw[4], &cw[2], &cw[1], &cw[0])){
            printf("CW format incorrect. 6 hex bytes expected.\n");
            fclose(wr);
            fclose(rd);
            exit(4);
        }
        //Free allocated Memory
        free(line);
        size = 0;
        //Calculate Checksum bytes. (Expand key from 48 to 64 bits)
        cw[3] = cw[0] + cw[1] + cw[2];
        cw[7] = cw[4] + cw[5] + cw[6];
        //Initialise libdvbcsa Key
        dvbcsa_key_set(cw, &key);
        
        /*GENERATE PACKET*/
        /* The first 32 bits of one TS packet:
        ####### byte 0
        8  Sync Byte  0x47 / 0b01000111

        ####### byte 1+2
        1  Transport Error Indicator    0b0
        1  Payload Unit Start Indicator 0b1
        1  Transport Priority           0b0
        13 Packet ID                    0b0000010111010
        0x40BA

        ####### byte 3
        2  Transport Scrambling Control 0b10/0b11
        2  Adaptation Field Control     0b01
        4  Continuity Counter           0x0-0xF*/
        /*PACKET GENERATION LOOP*/
        for (i = 0; i < 4; i++){
            memset(buf, 0, 188);
            buf[0] = 0x47;
            buf[1] = 0x40; 
            buf[2] = 0xBA;
            if(even){
                buf[3] |= (unsigned char) ((0x1 << 7) | (0x1 << 4) | (cnt & 0xF)) & 0xFF;
            }else{
                buf[3] |= (unsigned char) ((0x1 << 7) | (0x1 << 6) | (0x1 << 4) | (cnt & 0xF)) & 0xFF;
            }
            buf[6] = 1; //PES  Packet Start Code Prefix 0x000001
            buf[8] = cnt; // generate different payloads
            dvbcsa_encrypt(&key, &buf[4], 184);
            
            fwrite(buf, 1, 188, wr);
            //Increment Counter
            cnt++;
        }
        //Toggle Even/Odd Keys
        even ^= 1;
    }
    fclose(wr);
    fclose(rd);
    exit(0);
}