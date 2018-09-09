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
import ch.ntb.usb.*;    //LibusbJava
import ztex.*;          //ZTEX API

import java.util.logging.Logger;
import java.util.logging.Level;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.Semaphore;
//EXCEPTIONS
import java.lang.InterruptedException;

public class BoardControlThread extends Thread{
    
    /*CONSTANT DEFINITIONS*/
    //Bit position of the Done Flag in the FPGA Input Data
    public static final int DONE_MASK = 0x80;
    //Bit position of the Found Flag in the FPGA Input Data
    public static final int FOUND_MASK = 0x40;
    //Bit position of the clk Stable Flag in the FPGA Input Data
    //This Flag signifies that the DCm has a stable clk and the FPGA is operating normally
    public static final int CLK_STABLE_MASK = 0x20;
    //Bit position of the Progdone Flag in the FPGA Input Data
    //This Flag signifies that the DCM was programmed correctly
    public static final int PROGDONE_MASK = 0x10;
    //Bit position of the Transport Error Flag in the FPGA Input Data
    //This Flag signifies that a transport error occured on writing to EP2
    public static final int TR_ERROR_MASK = 0x08;
    //Bit position of the Frequency Error Flag in the FPGA Input Data
    //This Flag signifies that a transport error occured on writing to EP4
    public static final int FR_ERROR_MASK = 0x04;
    
    /*CLASS VARIABLE DECLARATIONS*/
    //The ZTEX Device this Thread is monitoring/controling
    private Ztex1v1 ztex;
    //The File to be used for the configuration of the FPGAs
    private String FPGABitfile;
    //The File to be used for the configuration of the EZ-USB FX2 chip
    private String FirmwareFile;
    //The Samples to be used by the FPGAs for the bruteforce Attack
    private byte samples[][][];
    //The start CW of each FPGA
    private long start_CW[];
    //A Array containing the Read data of each FPGA
    private byte in_buf[][];
    //The found Common Word. Only set, if actually found
    private byte cw[];
    //The Logger to be used by this class
    private Logger log;
    //The CLKFX_MULTIPLY parameter of the DCM_CLKGEN of the FPGA
    private int m_par = 9;
    //The CLKFX_DIVIDE parameter of the DCM_CLKGEN of the FPGA
    private int d_par = 4;
    //Semaphore used to synchronize the Threads with main when restarting the Threads
    private Semaphore sem;
    //Enumeration containing the Board Type that this Thread is interfacing with
    private Constants.BoardEnum board;
    //Integer containing the numbers of FPGAs on the board (Number of FPGAs this thread controls)
    private int FPGA_PER_BOARD = 0;
    
    /**Thread Status Bits**/
    //Set when Thread should exit.
    private AtomicBoolean exit;
    //Set when Thread should restart
    private AtomicBoolean restart;
    //Set if FPGAs are done
    private boolean done;
    //Set if CW is found (Auto sets done)
    private boolean found;
    //Set when an error occured
    private boolean error;
    //Holds the suspend Status of all the FPGAs
    private boolean suspended[];
    //Holds the number of consecutive errors occured per FPGA.
    //Is used to prevent an endless error-retry loop;
    private int ErrorCount[];
    //Holds the OverTemperature status of all Boards
    private boolean ot[];
    
    
    public BoardControlThread(Ztex1v1 ztex, boolean force, String FPGABitfile, String FirmwareFile, 
    byte[][][] samples, long[] start_CW, Logger log, int m_par, int d_par, Semaphore sem, Constants.BoardEnum board) throws Exception{
        
        this.ztex = ztex;
        this.FPGABitfile = FPGABitfile;
        this.FirmwareFile = FirmwareFile;
        this.samples = samples;
        this.start_CW = start_CW;
        this.log = log;
        this.m_par = m_par;
        this.d_par = d_par;
        this.sem = sem;
        this.board = board;
        
        switch(board){
            case Z216:
                FPGA_PER_BOARD = 1;
                break;
            default:
                FPGA_PER_BOARD = 4;
        }
        
        
        
        suspended = new boolean[FPGA_PER_BOARD];
        ot = new boolean[FPGA_PER_BOARD];
        
        
        in_buf = new byte[FPGA_PER_BOARD][Constants.INPUT_SIZE];
        cw = new byte[Constants.SAMPLE_BLOCK_SIZE];
        done = false;
        found = false;
        exit = new AtomicBoolean(false);
        restart = new AtomicBoolean(false);
        error = false;
        ErrorCount = new int[FPGA_PER_BOARD];
        
        log.fine("Thread "+this.getId()+": Beginning upload procedure");
        upload(force);
        
        /*CLAIM INTERFACE 0*/
        log.fine("Thread "+this.getId()+": Claiming Interface 0");
        ztex.trySetConfiguration(1);
	    ztex.claimInterface(0);
	    
	    /*Set Frequency*/
	    setFreq(FPGA_PER_BOARD);
	    
	    /*SUSPEND FPGAS*/
        suspend(FPGA_PER_BOARD);
    }
    
    /*
    This method is used to update the samples variable
    */
    public void setSamples(byte[][][] samples){
        this.samples = samples;
    }
    
    /*
    This is the actual "main" running method of the Thread.
    It contains two loops. The outer loop is for keeping the thread alive. The bruteforce attacks 
    can be rerun by setting the restart class variable (via restart() method). The inner loop is the 
    polling loop responsible for reading from the FPGAs and acting according to the set Status 
    bits of the FPGA. This method can be terminated by setting the exit class variable 
    (via terminate() method)
    */
    public void run(){
        boolean tmp_done = false;
        
        /*RESUME FPGAs*/
        resume(FPGA_PER_BOARD);
        
        /*Write Initial Data to FPGAs*/
        write(FPGA_PER_BOARD);
        
        /*Reset*/
        reset(FPGA_PER_BOARD);
        
        while(!exit.get()){
            
            /*SHORT SLEEP*/
            try{
                Thread.sleep(500);
            }
            catch(InterruptedException e){
                log.warning("Thread " + this.getId() + " was Interrupted.");
                exit.set(true);
                break;
            }
            
            /*RESTART CHECK*/
            if(restart.get()){
                log.fine("Thread "+this.getId()+": Restarting.");
                done = false;
                found = false;
                tmp_done = false;
                
                /*RESUME FPGAs*/
                resume(FPGA_PER_BOARD);
                
                /*Write Initial Data to FPGAs*/
                write(FPGA_PER_BOARD);
                
                /*Reset*/
                reset(FPGA_PER_BOARD);
                
                /*Reset restart variable*/
                restart.set(false);
                
                /*Signal main to continue*/
                sem.release();
            }
            
            /*MAIN POLLING LOOP*/
            //Wait until done is set (All FPGAs DONE or one FOUND the key) or exit/restart set.
            while(!done && !exit.get() && !restart.get()){
                try{
                    if(this.interrupted()){
                        throw new InterruptedException();
                    }
                    //Sleep Thread for 500ms
                    Thread.sleep(500);
                    //Read from all FPGAs of Board
                    read(FPGA_PER_BOARD);
                    /*NOTE: The done variable is set here to allow an extra check after all FPGAs 
                    have pulled the done signal high. That is done, because the FPGA can pull the 
                    FOUND signal some cycles after the DONE signal high, depending on the number
                    of Signals. A second read out would eliminate a potential false read out*/
                    done = tmp_done;
                    tmp_done = true;
                    for(int i = 0; i < FPGA_PER_BOARD; i++){
                        //Check if maximum Error count is reached
                        if(ErrorCount[i] > Constants.RETRY_NUM){
                            log.severe("Thread "+this.getId()+" reached the maximum error-retry count. Terminating...");
                            exit.set(true);
                            break;
                        }
                        log.finest("Thread "+this.getId()+": FPGA "+i+" read Data: " + Constants.hexString(in_buf[i]));
                        //Parse done Bit
                        tmp_done &= (in_buf[i][0] & DONE_MASK) != 0;
                        /*CHECK STATUS BITS*/
                        if((in_buf[i][0] & FR_ERROR_MASK) != 0){
                            //According to Board Type, the FR_ERROR status Bit is used differently.
                            switch(board){
                                //The FR_ERROR Bit is used by the ZTEX 2.16 Board to state if the FPGA has
                                //gone over the specified temperature and has switched to the low clock frequency.
                                case Z216:
                                    if(!ot[i]){
                                        log.info("Thread "+this.getId()+": FPGA "+i+" has gone over 80 C and switched to low frequency.");
                                        ot[i] = true;
                                    }
                                    break;
                                default:
                                    log.info("Thread "+this.getId()+": FPGA "+i+" has a Frequency Set Error. Resetting Frequency...");
                                    //Output EP Debug Stats
                                    try{
                                        log.finer("Thread "+this.getId()+" Debug:\n" + debug());
                                        log.finer("Thread "+this.getId()+" FPGA "+i+" read Data: " + Constants.hexString(in_buf[i]));
                                    }
                                    catch(Exception e){
                                        log.log(Level.WARNING,"Thread "+this.getId()+": Could not run debug(). Ignoring and continuing...", e);
                                    }
                                    setFreq(i);
                                    tmp_done = false;
                                    (ErrorCount[i])++;
                                    continue;
                            }
                        }
                        else if((in_buf[i][0] & PROGDONE_MASK) == 0){
                            log.warning("Thread "+this.getId()+": FPGA "+i+" has not asserted PROGDONE Flag. Resetting DCM...");
                            log.finer("Thread "+this.getId()+" FPGA "+i+" read Data: " + Constants.hexString(in_buf[i]));
                            clk_reset(i);
                            setFreq(i);
                            reset(i);
                            tmp_done = false;
                            (ErrorCount[i])++;
                            continue;
                        }
                        else if((in_buf[i][0] & CLK_STABLE_MASK) == 0){
                            log.warning("Thread "+this.getId()+": FPGA "+i+" has not asserted CLK_STABLE Flag. Resetting DCM...");
                            log.finer("Thread "+this.getId()+" FPGA "+i+" read Data: " + Constants.hexString(in_buf[i]));
                            clk_reset(i);
                            setFreq(i);
                            reset(i);
                            tmp_done = false;
                            (ErrorCount[i])++;
                            continue;
                        }
                        else if((in_buf[i][0] & TR_ERROR_MASK) != 0){
                            log.info("Thread "+this.getId()+": FPGA "+i+" has a Transmission Error. Retransmitting...");
                            //Output EP Debug Stats
                            try{
                                log.finer("Thread "+this.getId()+" Debug:\n" + debug());
                                log.finer("Thread "+this.getId()+" FPGA "+i+" read Data: " + Constants.hexString(in_buf[i]));
                            }
                            catch(Exception e){
                                log.log(Level.WARNING,"Thread "+this.getId()+": Could not run debug(). Ignoring and continuing...", e);
                            }
                            write(i);
                            reset(i);
                            tmp_done = false;
                            (ErrorCount[i])++;
                            continue;
                        }
                        else if((in_buf[i][0] & FOUND_MASK) != 0){
                            for(int j = 0; j < Constants.SAMPLE_BLOCK_SIZE; j++){
                                cw[j] = in_buf[i][j+1];
                            }
                            found = true;
                            done = true;
                            log.info("Thread "+this.getId()+": FPGA "+i+" has found the CW");
                            break;
                        }
                        //Extra check for default state of FR_ERROR
                        if((in_buf[i][0] & FR_ERROR_MASK) == 0){
                            switch(board){
                                //The FR_ERROR Bit is used by the ZTEX 2.16 Board to state if the FPGA has
                                //gone over the specified temperature and has switched to the low clock frequency.
                                case Z216:
                                    if(ot[i]){
                                        log.info("Thread "+this.getId()+": FPGA "+i+" has gone under 70 C and switched to high frequency.");
                                        ot[i] = false;
                                    }
                                    break;
                                default:
                                    break;
                            }
                        }
                        //Reset ErrorCount
                        ErrorCount[i] = 0;
                    }
                }
                catch(InterruptedException e){
                    log.warning("Thread " + this.getId() + " was Interrupted.");
                    exit.set(true);
                    break;
                }
            }
        }
        log.finer("Thread "+this.getId()+": Exited Loop.");
        
        log.fine("Thread "+this.getId()+": Releasing Interface 0");
        ztex.releaseInterface(0);
        log.fine("Thread "+this.getId()+": Exiting.");
    }
    
    /*
    This method is called to put FPGAs on suspend. This is done by pulling the clk enable Signal of
    the FPGA low. The parameter signifies which FPGA to suspend. If the Parameter is equal to 
    FPGA_PER_BOARD (Normal range is 0 to FPGA_PER_BOARD-1) the function suspends all FPGAs.
    */
    public void suspend(int fpga){
        
        /*Check to which FPGA to write*/
        int start;
        int end;
        if(fpga == FPGA_PER_BOARD){
            start = 0;
            end = FPGA_PER_BOARD-1;
        }
        else{
            start = fpga;
            end = fpga;
        }
        
        /*SUSPEND*/
        for(int i = start; i <= end; i++){
            try{
                log.info("Thread "+this.getId()+": Suspending FPGA "+i);
                ztex.selectFpga(i);
                ztex.vendorCommand(0x80, "Suspend", 0, 0);
                suspended[i] = true;
            }
            catch(Exception e){
                log.log(Level.WARNING, "Thread "+this.getId()+": Failed to suspend FPGA "+i, e);
            }
        }
    }
    
    /*
    This method is called to resume FPGAs after a suspend. This is done by pulling the clk enable Signal 
    of the FPGA high. The parameter signifies which FPGA to resume. If the Parameter is equal to 
    FPGA_PER_BOARD (Normal range is 0 to FPGA_PER_BOARD-1) the function resumes all FPGAs.
    */
    public void resume(int fpga){
        
        /*Check to which FPGA to write*/
        int start;
        int end;
        if(fpga == FPGA_PER_BOARD){
            start = 0;
            end = FPGA_PER_BOARD-1;
        }
        else{
            start = fpga;
            end = fpga;
        }
        
        /*RESUME*/
        for(int i = start; i <= end; i++){
            try{
                //NOTE: At the moment only the software can put the FPGA into suspend mode, so we can
                //check the suspend Array.
                if(!suspended[i]){
                    continue;
                }
                log.info("Thread "+this.getId()+": Resuming FPGA "+i);
                ztex.selectFpga(i);
                ztex.vendorCommand(0x81, "Resume", 0, 0);
                suspended[i] = true;
            }
            catch(Exception e){
                log.log(Level.WARNING, "Thread "+this.getId()+": Failed to resume FPGA "+i, e);
            }
        }
    }
    
    /*
    This method is called to reset the FPGAs. This is done by pulling the reset Signal high for 
    20 ms. The parameter signifies which FPGA to reset. If the Parameter is equal to 
    FPGA_PER_BOARD (Normal range is 0 to FPGA_PER_BOARD-1) the function resets all FPGAs.
    NOTE: The data writen on a FPGA is preserved after a reset. Only the bruteforce cores are reset
    */
    public void reset(int fpga){
        
        /*Check to which FPGA to write*/
        int start;
        int end;
        if(fpga == FPGA_PER_BOARD){
            start = 0;
            end = FPGA_PER_BOARD-1;
        }
        else{
            start = fpga;
            end = fpga;
        }
        
        /*RESET*/
        for(int i = start; i <= end; i++){
            try{
                log.info("Thread "+this.getId()+": Reseting FPGA "+i);
                ztex.selectFpga(i);
                ztex.vendorCommand(0x82, "Reset", 0, 0);
            }
            catch(Exception e){
                log.log(Level.WARNING, "Thread "+this.getId()+": Failed to reset FPGA "+i, e);
            }
        }
    }
    
    /*
    This method is called to reset the clks of FPGAs. This is done by pulling the clk reset Signal 
    high for 20 ms. The parameter signifies which FPGA to reset. If the Parameter is equal to 
    FPGA_PER_BOARD (Normal range is 0 to FPGA_PER_BOARD-1) the function resets the clks of all FPGAs.
    */
    public void clk_reset(int fpga){
        
        /*Check to which FPGA to write*/
        int start;
        int end;
        if(fpga == FPGA_PER_BOARD){
            start = 0;
            end = FPGA_PER_BOARD-1;
        }
        else{
            start = fpga;
            end = fpga;
        }
        
        /*RESET*/
        for(int i = start; i <= end; i++){
            try{
                log.info("Thread "+this.getId()+": Reseting clk of FPGA "+i);
                ztex.selectFpga(i);
                ztex.vendorCommand(0x83, "CLK Reset", 0, 0);
                Thread.sleep(500);
            }
            catch(Exception e){
                log.log(Level.WARNING, "Thread "+this.getId()+": Failed to reset clk of FPGA "+i, e);
            }
        }
    }
    
    /*
    This method is called internally to read (predefined) Data from the FPGA. The parameter signifies 
    from which fpga to read. If the Parameter is equal to FPGA_PER_BOARD (Normal range is 0 to 
    FPGA_PER_BOARD-1) the function reads from all FPGAs and udates the in_buf array with the data.
    */
    private void read(int fpga){
        
        /*Check from which FPGAs to read*/
        int start;
        int end;
        if(fpga == FPGA_PER_BOARD){
            start = 0;
            end = FPGA_PER_BOARD-1;
        }
        else{
            start = fpga;
            end = fpga;
        }
        
        /*READ DATA*/
        for(int i = start; i <= end; i++){
            try{
                ztex.selectFpga(i);
                int n;
                do{
                    /*NOTE: Because of the nature of the Chip Select Signal and the implementation 
                    choise that every selected FPGA writes into the endpoint until it's full, 
                    the first read out packet of the EP is cluttered garbage of the previous 
                    selected FPGA. We make a second read out with the target FPGA selected and 
                    can guarranty that the read out data is valid and from the FPGA that we want.
                    */
                    n = LibusbJava.usb_bulk_read(ztex.handle(), 0x86, in_buf[i], Constants.INPUT_SIZE, 1000);
                    //log.finest("FPGA "+i+" garbage Data "+n+" Bytes: " + Constants.hexString(in_buf[i]));
                    n = LibusbJava.usb_bulk_read(ztex.handle(), 0x86, in_buf[i], Constants.INPUT_SIZE, 1000);
                    //log.finest("FPGA "+i+" read Data "+n+" Bytes: " + Constants.hexString(in_buf[i]));
                    //log.finest("Debug:\n" + debug());
                }while(n != Constants.INPUT_SIZE);
            }
            catch(Exception e){
                log.log(Level.SEVERE, "Thread "+this.getId()+": Failed to read from FPGA "+i, e);
                error = true;
                exit.set(true);
            }           
            in_buf[i] = reverse(in_buf[i]);
        }
    }
    
    /*
    This method is called internally to write (predefined) Data from the FPGA. The parameter signifies 
    to which fpga to write. If the Parameter is equal to FPGA_PER_BOARD (Normal range is 0 to 
    FPGA_PER_BOARD-1) the function generates the output Buffer and writes to all FPGAs.
    */
    private void write(int fpga){
        byte buf[] = new byte[Constants.OUTPUT_SIZE];
        
        /*Check to which FPGA to write*/
        int start;
        int end;
        if(fpga == FPGA_PER_BOARD){
            start = 0;
            end = FPGA_PER_BOARD-1;
        }
        else{
            start = fpga;
            end = fpga;
        }
        
        for(int i = start; i <= end; i++){
            /*BUFFER PREPERATION*/
            log.finer("Thread "+this.getId()+": Preparing Buffer to send to FPGA "+ i);
            //Put start_CW into Buffer
            for(int j = 0; j < Constants.START_CW_SIZE; j++){
                buf[j] = (byte)((start_CW[i] >> (((Constants.START_CW_SIZE-1)-j)*8)) & 0xFF);
            }
            //Put Samples into Buffer
            for(int j = 0; j < Constants.SAMPLE_NUM; j++){
                for(int k = 0; k < Constants.NUM_BLOCK_PER_SAMPLE; k++){
                    for(int l = 0; l < Constants.SAMPLE_BLOCK_SIZE; l++){
                        int n = Constants.START_CW_SIZE+(j*(Constants.SAMPLE_BLOCK_SIZE*Constants.NUM_BLOCK_PER_SAMPLE))+
                            (k*Constants.SAMPLE_BLOCK_SIZE)+l;
                        buf[n] = samples[j][k][l];
                    }
                }
            }
            log.finest("Buffer: " + Constants.hexString(buf));
            buf = reverse(buf);
            
            /*WRITE DATA*/
            try{
                //log.fine("Thread "+this.getId()+": Attempting to write Data to FPGA "+i);
                ztex.selectFpga(i);
                int n;
                do{
                    n = LibusbJava.usb_bulk_write(ztex.handle(), 0x02, buf, buf.length, 1000);
                    log.finer("Thread "+this.getId()+": FPGA "+i+" wrote "+n+" Bytes");
                    Thread.sleep(100);
                }while(n != buf.length);
            }
            catch(InterruptedException e){
                log.warning("Thread "+this.getId()+" was interrupted");
                exit.set(true);
            }
            catch(Exception e){
                log.log(Level.SEVERE, "Thread "+this.getId()+": Failed to write Data to FPGA "+i, e);
                error = true;
                exit.set(true);
            }
        }
    }
    
    /*
    This method reads debug data from the Cypress FX2 firmware via a vendor Command.
    Use this function to debug the USB Endpoints.
    */
    private String debug() throws Exception{
        byte t[] = new byte[18];
        ztex.vendorRequest2(0x84, "Debug Request", t, 18);
        //log.finest("Debug EP6 BC: "+ Constants.hexString(t));
        //Alignment Error
        if(t[0] != -86){ //0xAA
            return "Debug read error";
        }
        String msg = "";
        msg += "EP2CS=";
        msg += debug_cs(t[1]);
        msg += "\nEP4CS=";
        msg += debug_cs(t[2]);
        msg += "\nEP6CS=";
        msg += debug_cs(t[3]);
        msg += "\nFIFO2=";
        msg += debug_fifoflgs((byte)(t[4] & 0x0F));
        msg += " FIFO4=";
        msg += debug_fifoflgs((byte)((t[4]>>4) & 0x0F));
        msg += " FIFO6=";
        msg += debug_fifoflgs((byte)(t[5] & 0x0F));
        msg += "\nEP2BC=" + (int) (((t[6] << 8) & 0xFF00) | (t[7] & 0xFF));
        msg += "\nEP4BC=" + (int) (((t[8] << 8) & 0xFF00) | (t[9] & 0xFF) );
        msg += "\nEP6BC=" + (int) (((t[10] << 8) & 0xFF00) | (t[11] & 0xFF) );
        msg += "\nEP2FIFOBC=" + (int) (((t[12] << 8) & 0xFF00) | (t[13] & 0xFF) );
        msg += "\nEP4FIFOBC=" + (int) (((t[14] << 8) & 0xFF00) | (t[15] & 0xFF) );
        msg += "\nEP6FIFOBC=" + (int) (((t[16] << 8) & 0xFF00) | (t[17] & 0xFF) );
        return msg;
    }
    
    /*
    This is a submethod of the debug method.
    */
    private String debug_fifoflgs(byte data){
        String msg = "";
        if((data & 0x01) != 0){
            msg += "FF,";
        }
        if((data & 0x02) != 0){
            msg += "EF,";
        }
        if((data & 0x04) != 0){
            msg += "PF,";
        }
        return msg;
    }
    
    /*
    This is a submethod of the debug method.
    */
    private String debug_cs(byte data){
        String msg = "";
        if((data & 0x01) != 0){
            msg += "STALL,";
        }
        if((data & 0x04) != 0){
            msg += "EMPTY,";
        }
        if((data & 0x08) != 0){
            msg += "FULL,";
        }
        msg += " PACKETS:";
        msg += (int) (data >> 4);
        return msg;
    }
    
    /*
    This method is used internally to reverse an Array Byte Order.
    This is necessary, because the FPGA needs the read/written Shift Data in reverse Order.
    */
    private byte[] reverse (byte[] data)  {
		byte[] buf = new byte[data.length];
		for ( int i=0; i<data.length; i++){
		    buf[data.length-i-1] = data[i];
		}
		return buf;
    }
    
    /*
    This method is used to set a new Frequency to a fpga.
    The first Parameter signifies which fpga to update.  If the Parameter is equal to FPGA_PER_BOARD 
    (Normal range is 0 to FPGA_PER_BOARD-1) the function sets the Frequency of all FPGAs.
    The m and d Parameter are the CLKFX_MULTIPLY and CLKFX_DIVIDE parameters of the DCM_CLKGEN 
    respectively.
    NOTE: This method is just a wrapper, that sets the "m_par" and "d_par" variables and then calls 
    the private setFreq(int) method.
    */
    public void setFreq (int fpga, int m, int d){
        /*Check Parameter Range*/
        if(m < 2 || m >= 256){
            log.warning("Thread "+this.getId()+": M parameter of setFreq out of Range");
            return;
        }
        //NOTE: Because the reference clock of the DCM is smaller than 52 MHz, we have to guaranty
        //that the D parameter is smaller equal than 2*Ref_clk (2*48=96).
        else if(d < 1 || d > 96){
            log.warning("Thread "+this.getId()+": D parameter of setFreq out of Range");
            return;
        }
        
        d_par = d;
        m_par = m;
        
        setFreq(fpga);
	}
    
    /*
    This method is used to set the Frequency stored in the Class variables to a FPGA.
    If the Parameter is equal to FPGA_PER_BOARD (Normal range is 0 to FPGA_PER_BOARD-1) the 
    function sets the Frequency of all FPGAs.
    */
    private void setFreq (int fpga){
        /*Check to which FPGA to write*/
        int start;
        int end;
        if(fpga == FPGA_PER_BOARD){
            start = 0;
            end = FPGA_PER_BOARD-1;
        }
        else{
            start = fpga;
            end = fpga;
        }
        
        //SetFrequency not implemented for ZTEX 2.16
        if(board == Constants.BoardEnum.Z216){
            return;
        }
        
        byte buf[] = new byte[2];
        buf[0] = (byte) (d_par-1);
        buf[1] = (byte) (m_par-1);
        
        for(int i = start; i <= end; i++){
            /*WRITE DATA*/
            try{
                log.info("Thread "+this.getId()+": Trying to set a Frequency of "+48*((float)m_par/(float)d_par)+"MHz to FPGA "+i);
                ztex.selectFpga(i);
                int n;
                do{
                    n = LibusbJava.usb_bulk_write(ztex.handle(), 0x04, buf, buf.length, 1000);
                    log.finer("Thread "+this.getId()+": FPGA "+i+" wrote "+n+" Bytes");
                    Thread.sleep(1000);
                }while(n != buf.length);
            }
            catch(InterruptedException e){
                log.warning("Thread "+this.getId()+" was interrupted");
                exit.set(true);
            }
            catch(Exception e){
                log.log(Level.WARNING, "Thread "+this.getId()+": Failed to set Frequency on FPGA "+i, e);
            }
        }
	}
    
    /*
    This method is used to upload the EZ-USB Firmware and FPGA Bitstreamfile. The "force" Parameter
    signifies if this upload should be forced. (Only FPGA upload will be forced)
    Since this method is called internally by the constructor, it does not catch any thrown Exceptions
    */
    public void upload(boolean force) throws Exception{
        /*Upload EZ-USB Firmware if necessary*/
        //NOTE: Force is disabled on the Firmware upload, because it hangs the second time and a
        //hard power reset is needed.
        log.fine("Thread "+this.getId()+": Uploading ZTEX firmware");
        log.finer("Thread "+this.getId()+": Current FX Firmware:" +ztex.dev().productString());
        switch(board){
            case Z216:
                if(force || !(ztex.dev().productString().equals("FX2 ZTEX 2.16 Firmware for CSA"))){
                    ztex.uploadFirmware(FirmwareFile, force);
                }
                break;
            default:
                if(!(ztex.dev().productString().equals("FX2 ZTEX 1.15y Firmware for CSA"))){
                    ztex.uploadFirmware(FirmwareFile, force);
                }
        }
        
        
        /*Program FPGAs if necessary*/
        assert(ztex.numberOfFpgas() <= FPGA_PER_BOARD);
        for(int i = 0; i < FPGA_PER_BOARD; i++){
            ztex.selectFpga(i);
            log.fine("Thread "+this.getId()+": Uploading Bitstreamfile to FPGA "+i);
            if(force || !(ztex.getFpgaConfiguration())){
                ztex.configureFpga(FPGABitfile, force);
            }   
        }
    }
    
    /*
    Getter method for the done variable
    */
    public boolean getDone(){
        return done;
    }
    
    /*
    Getter method for the found variable
    */
    public boolean getFound(){
        return found;
    }
    
    /*
    Getter method for the error variable
    */
    public boolean getError(){
        return error;
    }
    
    /*
    Getter method for the cw variable
    */
    public byte[] getCW(){
        return cw;
    }
    
    public void restart(){
        log.finer("Thread "+this.getId()+": Restart variable set.");
        restart.set(true);
    }
    
    /*
    This method is called inorder to terminate the Thread externally.
    It sets a variable that allows the thread to exit it's main loop.
    Note that the exit variable is set Atomically
    */
    public void terminate(){
        log.finer("Thread "+this.getId()+": Exit variable set.");
        exit.set(true);
    }
}
