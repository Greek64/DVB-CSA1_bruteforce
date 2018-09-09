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
import java.io.InputStream;

import java.util.logging.Logger;
import java.util.logging.Level;
import java.util.Arrays;
//EXCEPTIONS
import java.io.EOFException;

public class TransportStreamParser{
    
    //Enumeration used to describe the scrambling control Field of the
    //Transport Stream
    private enum SCEnum{
        NOT_SET, EVEN, ODD
    }
    
    /*CONSTANT DCLARATIONS*/
    //Buffer size is 188 Bytes (size of a TS Packet) + 1 Byte of the next TS Packet
    private final int BUF_SIZE = 189;
    //The Sync Byte (First Byte) of a TS Packet Header
    private final int SYNC_BYTE = 0x47;
    //The Bit Position of the TransportErrorIndicator Bit in the TS Packet Header
    private final int TEI_MASK = 0x80;
    //The Bit Position of the PayloadunitStartIndicator Bit in the TS Packet Header
    private final int PUSI_MASK = 0x40;
    //The Bit Position of the High Bit of the ScramblingControl Field of the TS Packet Header
    private final int SC_HMASK = 0x80;
    //The Bit Position of the Low Bit of the ScramblingControl Field of the TS Packet Header
    private final int SC_LMASK = 0x40;
    //The Bit Position of the High Bit of the AdaptionFieldControl Field in the TS Packet Header
    private final int AFC_HMASK = 0x20;
    //The Bit Position of the Low Bit of the AdaptionFieldControl Field in the TS Packet Header
    private final int AFC_LMASK = 0x10;
    //Sizeof the TS Packet Header
    private final int HEADER_SIZE = 4;
    
    /*CLASS VARIABLE DECLARATIONS*/
    //The InputStream of the Transport Stream
    private InputStream ts;
    //Number of Samples to parse
    private int sampleNum;
    //Buffer used to read and parse the Stream
    private byte[] buf;
    //The Smaples parsed by this Class
    private byte[][][] samples;
    //The Logger to be used by this Class
    private Logger log;
    //This Variable contains the type of the currently used key when searching 
    //for samples (EVEN/ODD).
    private SCEnum scramble_control;
    
    
    public TransportStreamParser(InputStream ts, int sampleNum, Logger log){
        this.ts = ts;
        this.sampleNum = sampleNum;
        this.log = log;
        buf = new byte[BUF_SIZE];
        scramble_control = SCEnum.NOT_SET;
        
        samples = new byte[sampleNum][Constants.NUM_BLOCK_PER_SAMPLE][Constants.SAMPLE_BLOCK_SIZE];
    }
    
    /*
    This public method parses the InputStream until it finds all the suitable Samples and returns.
    Subsequent calls continue to parse the Stream and ovewrite the previous samples
    */
    public byte[][][] getSamples() throws Exception{
    
        log.fine("Beginning parsing TransportStream for samples.");
        for(int i = 0; i < sampleNum; i++){
            //The first iteration searches for the first sample encrypted with the next key.
            if(i == 0){
                findNextValidTS(true);
            }
            //The rest iterations have to be sampled encrypted with the same key.
            else{
                findNextValidTS(false);
            }
            for(int j = 0; j < Constants.SAMPLE_BLOCK_SIZE; j++){
                samples[i][0][j] = buf[j+HEADER_SIZE];
                samples[i][1][j] = buf[j+HEADER_SIZE+Constants.SAMPLE_BLOCK_SIZE];
            }
        }
        return samples;
    }
    
    /*
    This Method calls fillBuffer in a loop, until a valid TS Packet is found.
    (DE)synchronization is handled by the fillBuffer method.
    If the parameter is true, the method skips all packages until the first 
    package encrypted with the next key is found.
    If the method encounters a packet encrypted with the next key (and the next_key 
    parameter is false), the method throws a EOSKException.
    NOTE: It COULD happen that, if the next_key parameter is true, a sequence of the stream 
    encrypted with a specific key is skipped entirely. That would happen if no packet
    encrypted with that key has a payload with the PUSI Bit set, but that SHOULD never be the case.
    */
    private void findNextValidTS(boolean next_key) throws Exception{
        //Loop until we find a valid TS Packet
        while(true){
            fillBuffer(1);
            
            /*Skip packets until we find a packet encrypted with the next key*/
            if(next_key == true){
                if(scramble_control == SCEnum.EVEN){
                    //If encrypted with ODD Key, we found the first TS packet encrypted 
                    //with the next key
                    if((buf[3] & SC_HMASK) != 0 && (buf[3] & SC_LMASK) != 0){
                        //Set Scrambling Control to the new key
                        scramble_control = SCEnum.ODD;
                    }
                    //Else skip packet
                    else{
                        log.finest("TS Packet skipped: Same key");
                        continue;
                    }
                }
                else if(scramble_control == SCEnum.ODD){
                    //If encrypted with EVEN Key, we found the first TS packet encrypted 
                    //with the next key
                    if((buf[3] & SC_HMASK) != 0 && (buf[3] & SC_LMASK) == 0){
                        //Set Scrambling Control to the new key
                        scramble_control = SCEnum.EVEN;
                    }
                    //Else skip packet
                    else{
                        log.finest("TS Packet skipped: Same key");
                        continue;
                    }
                }
            }
            
            /*TS HEADER CHECK*/
            //If encrypted with EVEN Key
            if((buf[3] & SC_HMASK) != 0 && (buf[3] & SC_LMASK) == 0){
                switch(scramble_control){
                    //If not set, set the scramble_control variable
                    default:
                        scramble_control = SCEnum.EVEN;
                    //If we are looking for EVEN encrypted TS packets, do nothing
                    case EVEN:
                        break;
                    //If we are looking for ODD encrypted TS packets throw Exception
                    case ODD:
                        log.finer("Found TS packet encrypted with next key");
                        throw new SKException();
                }
            }
            //If encrypted with ODD Key
            else if((buf[3] & SC_HMASK) != 0 && (buf[3] & SC_LMASK) != 0){
                switch(scramble_control){
                    //If not set, set the scramble_control variable
                    default:
                        scramble_control = SCEnum.ODD;
                    //If we are looking for ODD encrypted TS packets do nothing
                    case ODD:
                        break;
                    //If we are looking for EVEN encrypted TS packets, throw Exception
                    case EVEN:
                        log.finer("Found TS packet encrypted with next key");
                        throw new SKException();
                }
            }
            //Else Invalid or unencrypted, skip packet
            else{
                log.finer("TS Packet skipped: Invalid Scrambling Control Field or Unencrypted Payload");
                continue;
            }
            
            //If the TEI bit is unset and the PUSI bit is set, we found a TS Packet with the wanted Payload
            if(((buf[1] & TEI_MASK) == 0) && ((buf[1] & PUSI_MASK) != 0)){   
                /*Adaption Field Control Check*/
                //Payload only allowed
                if((buf[3] & AFC_HMASK) == 0 && (buf[3] & AFC_LMASK) != 0){  //TODO: Allow also Payload and Adaption?
                    log.finer("Found valid TS Packet.");
                    return;
                }
            }
            log.finest("TS Packet skipped: PUSI Bit not set");
        }
    }
    
    /* 
    This method assumes an aligned Buffer. If the first and last Byte is not a Sync Byte , it calls 
    the synchronize() method. The off parameter states from which position of the buffer to begin
    to fill the buffer.
    NOTE: Note that the synchronization Procedure may produce recursive calls to fillBuffer() and
    synchronize() methods.
    */
    private void fillBuffer(int off) throws Exception{
        //If first Byte is not a Sync Byte, we need to resynchronize
        if(buf[0] != SYNC_BYTE){
            log.fine("Out of Sync with Transport Stream.(First Byte) Attempting resynchronization.");
            synchronize();
            log.fine("Synchronized");
        }
        else{
            for(int i = off; i < BUF_SIZE; i++){
                int tmp = ts.read();
                if(tmp == -1){
                    throw new EOFException();
                }
                buf[i] = (byte)tmp;
            }
            //If the last Position of the Buffer is not the next Sync Byte, resynchronize
            if(buf[BUF_SIZE-1] != SYNC_BYTE){
                log.fine("Out of Sync with Transport Stream.(Last Byte) Attempting resynchronization.");
                log.finest("TS Buffer: " + Constants.hexString(buf));
                synchronize();
                log.fine("Synchronized");
            }
        }
    }
    
    /*
    This method is used to synchronize/align the Buffer with the TS Packets.
    This method calls fillBuffer, which in turn can recursevily call synchronize() again, until
    alignment of the Buffer is achieved
    NOTE: Initial Synchronization of the Buffer is done implicitly during the first call to fillBuffer
    method.
    */
    private void synchronize() throws Exception{
        
        int offset = 0;
        
        //Begin iterating from the second Byte (as we already know the first is a wrong sync Byte)
        for(int i = 1 ; i < BUF_SIZE; i++){
            if(buf[i] == SYNC_BYTE){
                offset = i;
                break;
            }
        }
        
        /*Sync Byte is not in the Buffer*/
        if(offset == 0){
            log.finer("SYNC Byte not in Buffer");
            //Find Next Sync Byte in Stream
            int tmp;
            do{
                tmp = ts.read();
                if(tmp == -1){
                    throw new EOFException();
                }
            }while(tmp != SYNC_BYTE);
            //Fill the Buffer
            log.finer("Found SYNC Byte in Trasport Stream. Atempting to fill Buffer");
            buf[0] = SYNC_BYTE;
            fillBuffer(1);
        }
        /*Sync Byte is in the Buffer*/
        else{
            //Shift The Buffer, so that the found Sync Byte is in the First Position
            for(int i = offset; i < BUF_SIZE; i++){
                buf[i-offset] = buf[i];
            }
            //Fill the rest of the Buffer
            fillBuffer(BUF_SIZE-offset);
        }
    }
}
