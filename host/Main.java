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
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.Vector;
import java.util.Arrays;
import java.io.FileWriter;
import java.util.EnumMap;
import java.util.concurrent.Semaphore;
//LOGGING
import java.util.logging.Logger;
import java.util.logging.Level;
import java.util.logging.Handler;
import java.util.logging.ConsoleHandler;
import java.util.logging.FileHandler;
import java.util.Properties;
import java.util.logging.SimpleFormatter;
import java.util.logging.StreamHandler;
//Exceptions
import java.io.IOException;
import java.io.EOFException;

import gnu.getopt.*;    //Getopt
import ch.ntb.usb.*;    //LibusbJava
import ztex.*;          //ZTEX API

//NOTE: Common Word and Key are used in the comments interchangeably

final public class Main{
    
    /*ENUM DECLARATIONS*/
    //This Enumeration contains all the valid frequencies
    private enum FreqEnum{
        F48, F72, F96, F108, F115, F120, F125, F130, F135, F140, F145, F150;
        
        //This method is used to return the next smaller valid frequency
        public FreqEnum prev() {
            //Cap at slowest frequency
            if (ordinal() == 0){
                return FreqEnum.F48;
            }
            else{
                return values()[ordinal() - 1];
            }
        }
        
        //This method returns the Enum represented by the String
        public static FreqEnum get(String s){
            FreqEnum[] vals = values();
            for(int i = 0; i < vals.length; i++){
                if(s.equals(vals[i].name())){
                    return vals[i];
                }
            }
            //Default
            return FreqEnum.F108;
        }
    }
    
    /*CONSTANT DEFINITIONS*/
    public static final String NAME = new String("csa");
    public static final String USAGE = new String(
        "USAGE:\n"+
        NAME + " [OPTIONS]\n"+
        NAME + " will read from the provided Transport Stream and parse required samples used for the\n" +
        "bruteforce procedure. The samples are uploaded to the selected Boards/FPGAs and the bruteforce\n" +
        "attack is initiated. Uppon failure the selected Frequency is reduced and the Bruteforce attack\n"+
        "is restarted. Uppon finding the Common Word, the key is written in the keyfile and the Transport\n"+
        "Stream is parsed for further samples encrypted with a different key. Keys are bruteforced and\n"+
        "written into the keyfile until either the EOF of the Transport Stream is reached, or the Key\n"+
        "could not be bruteforced even in the lowest frequency setting. The latter would signify a major\n"+
        "error in the FPGAs (e.g. Overheating)\n\n"+
        "OPTIONS:\n" +
        "-z [<board>]       The number representing the ZTEX board type. Supported numbers/types are\n"+
        "                   1 (Board 1.15y)\n"+
        "                   2 (Board 2.16)\n"+
        "                   Default is 1. On unrecognised input, 1 will the default will be selected.\n"+
        "-d [<number>]      Bruteforce will be executed on a single Board. The number signifies\n"+
        "                   the Device Number. This option is ignored when -c Option is given. Default is 0.\n" +
        "-c <number>        Cluster Mode. The Bruteforce attack will be performed on the number of Devices\n" +
        "                   stated by <number>.\n" +
        "-b <fpga_bitfile>  Path to the FPGA Bitfile. REQUIRED\n" +
        "-e <ihx_file>      Path to EZ-USB IHX Firmware file. REQUIRED\n" +
        "-s <sample_file>   Path to file containing the Transport Stream to be parsed. All keys\n"+
        "                   used for the encryption of the packets of this Stream will be bruteforced\n" +
        "                   and written in the keyfile. REQUIRED\n" +
        "-k <keyfile>       Path to key file. All found keys wil be written into this file.\n" +
        "                   Existing files will be overwritten. Default is \"keys\"\n" +
        "-f <num>           Operation Frequency of FPGAs. Default is F108 (108 MHz).\n" +
        "                   Possible values (F48, F72, F96, F108, F115, F120, F125, F130, F135, F140,\n"+
        "                   F145, F150). Beware of overheating!\n"+
        "-w                 Enable USB workarounds. Use this option to deal with bad driver/OS \n" +
        "                   implementations\n" +
        "-l <logfile>       Path to Logging filename. Output will be logged to this File as well.\n" +
        "                   The logfile is limited to a size of 1Mb.\n" +
        "-v <num>           Verbose level of the Output/logging. Default is 3.\n" +
        "                   1   SEVERE\n"+
        "                   2   WARNING\n"+
        "                   3   INFO\n"+
        "                   4   FINE\n"+
        "                   5   FINER\n"+
        "                   6   FINEST (WARNING: Do not log into logfile with this level)\n"+
        "-u                 Force FPGA Bitstreamfile Uploads.\n" +
        "                   Default Behavior is to Upload only when missing/incorrect version.\n" +
        "-h                 Print the help message\n"
        );
    /*CLASS VARIABLES*/
    //This Variable contains the InputStream of the sample file
    private static InputStream ts;
    //This Variable contains all the started background threads
    private static Vector<BoardControlThread> threads = new Vector<BoardControlThread>();
    //This variable holds the Logger used throughout the implementation
    private static Logger log;
    //This map contains the Frequency Parameters, initialised and used by main
    private static EnumMap<FreqEnum, int[]> map;
    //This variable holds the Semaphore responsible for thread synchronization
    private static Semaphore sem;
    //BufferedWriter for keyfile
    private static FileWriter wr;
    //The board type ineterfaced by this program
    private static Constants.BoardEnum board;
    //The number of FPGA on the specified board type
    private static int FPGA_PER_BOARD;
    
    public static void main(String[] args){
        
        /*SET SYSTEM PROPERTIES*/
        //Set System Properties for desired Logging Output.
        Properties props = System.getProperties();
        props.setProperty("java.util.logging.SimpleFormatter.format", 
        "[%1$td/%1$tm/%1$tY %1$tH:%1$tM:%1$tS](%2$s) %4$s: %5$s%n%6$s%n");
        
        /*SET ENUMMAP*/
        //Set Frequency Parameteres
        //First Value of the int array is the Multiplier and second the Divisor
        map = new EnumMap<FreqEnum, int[]>(FreqEnum.class);
        map.put(FreqEnum.F48, new int[]{2, 2});
        map.put(FreqEnum.F72, new int[]{3, 2});
        map.put(FreqEnum.F96, new int[]{4, 2});
        map.put(FreqEnum.F108, new int[]{9, 4});
        map.put(FreqEnum.F115, new int[]{115, 48});
        map.put(FreqEnum.F120, new int[]{5, 2});
        map.put(FreqEnum.F125, new int[]{13, 5});
        map.put(FreqEnum.F130, new int[]{65, 24});
        map.put(FreqEnum.F135, new int[]{45, 16});
        map.put(FreqEnum.F140, new int[]{35, 12});
        map.put(FreqEnum.F145, new int[]{145, 48});
        map.put(FreqEnum.F150, new int[]{25, 8});
        
        /*VARIABLE DECLARATIONS*/
        //Option Variables
        boolean clustermode = false;
        boolean USBworkaround = false;
        int devNum = 0;
        int clusterDevNum = 0;
        String FPGABitfile = null;
        String FirmwareFile = null;
        String Samplefile = null;
        String logfile = null;
        String keyfile = "key";
        int verbose = 3;
        FreqEnum freq = FreqEnum.F108;
        boolean force = false;
        int z = 0;
        //Variable containing all the found ZTEX Devices
        ZtexScanBus1 bus;
        //Number of devices in the bus
        int BusDevNum = 0;
        //TS Parser Instance
        TransportStreamParser parser = null;
        //The Sample Array parsed by the TS Parser
        byte[][][] samples = null;
        //The numbers of Boards(ZTEX DEVICES)to use.
	    long boardNum = 0;
	    //The Array containing all the Start CommonWords for each FPGA
	    long start_CW[][] = null;
	    //This variable is a counter, used to dispaly an output on stdout in a defined time period
	    int cnt = 0;
        
        /*ARGUMENT PARSING*/
        Getopt g = new Getopt("CSA", args, "z:d:c:b:e:s:k:f:wl:v:uh");
        int c;
        String arg;
        while((c = g.getopt()) != -1){
            switch(c){
                case 'z':
                    z = Integer.parseInt(g.getOptarg());
                    break;
                case 'd':
                    devNum = Integer.parseInt(g.getOptarg());
                    break;
                case 'c':
                    clustermode = true;
                    clusterDevNum = Integer.parseInt(g.getOptarg());
                    break;
                case 'b':
                    FPGABitfile = g.getOptarg();
                    break;
                case 'e':
                    FirmwareFile = g.getOptarg();
                    break;
                case 's':
                    Samplefile = g.getOptarg();
                    break;
                case 'w':
                    USBworkaround = true;
                    break;
                case 'l':
                    logfile = g.getOptarg();
                    break;
                case 'k':
                    keyfile = g.getOptarg();
                case 'f':
                    freq = FreqEnum.get(g.getOptarg());
                    break;
                case 'v':
                    verbose = Integer.parseInt(g.getOptarg());
                    break;
                case 'u':
                    force = true;
                    break;
                case 'h':
                    System.out.print(USAGE);
                    System.exit(0);
                default:
                    System.out.print(USAGE);
                    System.exit(1);
            }
        }
        
        if(FPGABitfile == null || Samplefile == null || FirmwareFile == null){
            System.out.print(USAGE);
            System.exit(1);
        }
        
        /*INITIALISE LOGGING*/
        /*Because the LogManager registers a seperate ShutdownHook for his Loggers, and we want to 
        keep Logging during the ShutdownHook, we create an Anonymous Logger, which has no 
        interference from the LogManager & CO*/
        //log = Logger.getLogger(Main.class.getName());
        log = Logger.getAnonymousLogger();
        Level l = Level.INFO;
        switch(verbose){
            case 1:
                l = Level.SEVERE;
                break;
            case 2:
                l = Level.WARNING;
                break;
            case 3:
                l = Level.INFO;
                break;
            case 4:
                l = Level.FINE;
                break;
            case 5:
                l = Level.FINER;
                break;
            case 6:
                l = Level.FINEST;
                break;
        }
        log.setLevel(l);
        log.setUseParentHandlers(false);
        //Close and remove all default Handlers
        for(Handler h : log.getHandlers()){
            h.close();
            log.removeHandler(h);
        }
        {
            ConsoleHandler ch = new ConsoleHandler();
            ch.setLevel(l);
            log.addHandler(ch);
        }
        //If set, enable File Logging
        if(logfile != null){
            try{
                FileHandler f = new FileHandler(logfile, 5*1024*1024, 1, false);
                f.setFormatter(new SimpleFormatter());
                f.setLevel(l);
                log.addHandler(f);
            }
            catch(Exception e){
                log.log(Level.WARNING,"Cannot create FileHadler for File logging.", e);
            }
        }
        log.fine("Logging initiated.");
        
        /*SET SHUTDOWN HOOK*/
        Runtime.getRuntime().addShutdownHook(new ShutdownHook(log));
        
        /*SET BOARD TYPE*/
        switch(z){
            case 2:
                log.info("Using Board Type: ZTEX 2.16");
                log.info("Frequency setting will be ignored.");
                board = Constants.BoardEnum.Z216;
                FPGA_PER_BOARD = Constants.FPGA_NUM_2_16;
                break;
            case 1:
            default:
                log.info("Using Default Board Type: ZTEX 1.15y");
                board = Constants.BoardEnum.Z115Y;
                FPGA_PER_BOARD = Constants.FPGA_NUM_1_15y;
        }
        
        /*OPEN KEYFILE*/
        try{
            wr = new FileWriter(keyfile, false);
        }
        catch(IOException e){
            log.log(Level.SEVERE, "Could not open/create keyfile "+ keyfile, e);
            cleanup();
            System.exit(1);
        }
        
        /*INITIALISE USB*/
        try{
            LibusbJava.usb_init();
        }
        catch(Exception e){
            log.log(Level.SEVERE, "Could not initialise USB. Terminating...", e);
            cleanup();
            System.exit(1);
        }
        log.fine("USB initiated");
        switch(board){
            case Z216:
                //Scan bus for ZTEX 2.16 Devices with Descriptor 1 and Interface 1
                bus = new ZtexScanBus1(ZtexDevice1.ztexVendorId, ZtexDevice1.ztexProductId, false, false, 1, null, 10, 16, -1 , -1);
                break;
            default:
                //Scan bus for ZTEX 1.15y Devices with Descriptor 1 and Interface 1
                bus = new ZtexScanBus1(ZtexDevice1.ztexVendorId, ZtexDevice1.ztexProductId, false, false, 1, null, 10, 15, -1 , -1);
        }
        BusDevNum = bus.numberOfDevices();
	    if (BusDevNum  <= 0) {
	        log.warning("No specified ZTEX USB-FPGA-Module devices found.");
	        log.info("Nothing to do here. Terminating");
	    	cleanup();
	        System.exit(0);
	    }
	    log.info("Found " + BusDevNum + " ZTEX USB-FPGA-Module device(s).");
	    if(clustermode){
	        //Check if Bus has enough Devices for given clustermode
	        if(BusDevNum < clusterDevNum){
	            log.warning("Number of devices given with -c Option is higher than the number of devices on the Bus.");
	            log.info("Terminating...");
	        	cleanup();
	            System.exit(0);
	        }
	    }
	    else{
	        //Check if Single Device Number exists
	        if(devNum >= BusDevNum){
                log.warning("Device Number given with the -d Option does not exist. Terminating...");
                cleanup();
                System.exit(1);
	        }
	    }
	    //log.finer(bus.printBus(System.out));
	    
	    /*PARSE TS*/
	    try{
	        ts = new FileInputStream(Samplefile);
	    }
	    catch(Exception e){
	        log.log(Level.SEVERE, "Could not open the SampleFile. Terminating...", e);
	        cleanup();
            System.exit(1);
	    }
	    try{
	        parser = new TransportStreamParser(ts, Constants.SAMPLE_NUM, log);
	        samples = parser.getSamples();
	    }
	    catch(EOFException e){
            log.warning("Reached end of samplefile without finding a valid transport stream packet.");
            log.fine("Exiting Main");
        	cleanup();
        	System.exit(0);
        }
	    catch(Exception e){
	        log.log(Level.SEVERE, "Error while parsing the Transoprt Stream. Terminating...", e);
	        cleanup();
	        System.exit(1);
	    }
	    log.fine("Initial Samples successfully parsed from Transport Stream");
	    
	    
	    /*CALCULATE START CWs*/
	    boardNum = (clustermode) ? clusterDevNum : 1;
	    start_CW = calculateStartCW(boardNum);
	    log.fine("Start CWs successfully calculated");
	   
        /*SETUP SEMAPHORE*/
        sem = new Semaphore((clustermode) ? clusterDevNum : 1);
	   
        /*INITIALISE THREADS*/
        for(int i = 0; i < BusDevNum; i++){
	        if(clustermode){
	            //Break upon reaching the required number of devices (-c Argument)
                if(i >= clusterDevNum){
                    break;
                }
	        }
	        else{
	            //This check is used for the Single Device Mode (-d Argument)
	            if(i != devNum){
	                continue;
	            }
	        }
	        ZtexDevice1 dev = bus.device(i);
	        Ztex1v1 ztex = null;
	        try{
	            ztex = new Ztex1v1(dev);
	            ztex.checkValid();
	        }
	        catch(InvalidFirmwareException e){
	            log.log(Level.SEVERE,"Device "+i+" has not a valid ZTEX descriptor 1.", e);
	            log.fine("Bus contains Devices without ZTEX 1 Descriptor. That should not be the case.");
	            log.warning("Device "+i+" info:"+ ztex.toString());
	            log.info("Terminating...");
	            cleanup();
	            System.exit(1);
	        }
	        catch(UsbException e){
	            log.log(Level.SEVERE,"USB Error Communication with Device. Terminating...", e);
	            cleanup();
                System.exit(1);
	        }
            log.finer("Device " + i + " info: " + ztex.toString());
            //Configure USB workaround
            ztex.certainWorkarounds = USBworkaround;
            
            try{
                int[] tmp = map.get(freq);
                assert(tmp != null);
                BoardControlThread t = new BoardControlThread(ztex, force, FPGABitfile, FirmwareFile,
                samples,((clustermode) ? start_CW[i] : start_CW[0]), log, tmp[0], tmp[1], sem, board);
                threads.add(t);
                log.fine("Created Thread "+t.getId()+" to control Device "+i+" in USB Bus.");
            }
            catch(Exception e){
                log.log(Level.SEVERE, "Could not create BoardControlThread. Terminating...", e);
                cleanup();
                System.exit(1);
            }
	    }
	    log.fine("All threads created. Starting threads...");
	    assert(threads.size() == sem.availablePermits());
	    
	    /*STARTING THREADS*/
	    for (BoardControlThread t : threads) {
	    	t.start();
    	}
    	
    	/*MAIN LOOP*/
    	//This loop can only be exited via a thrown Exception.
    	//Error free termination would occur when EOFException is thrown.
    	log.fine("Now entering Main polling Loop");
    	while(true){
    	    
        	boolean done = false;
        	boolean found = false;
        	
        	/*SYNCHRONIZE*/
        	try{
        	    sem.acquire(threads.size());
        	}
        	catch(InterruptedException e){
        	    log.log(Level.WARNING,"Main Thread Interrupted. Calling cleanup Procedures...", e);
                cleanup();
                System.exit(1);
        	}
        	
        	/*BRUTEFORCE POLLING LOOP*/
        	log.fine("Bruteforce procedure initiated");
        	while(!found && !done){
        	    try{
        	        Thread.sleep(1000);
                }
                catch(InterruptedException e){
                    log.log(Level.WARNING,"Main Thread Interrupted. Calling cleanup Procedures...", e);
                    cleanup();
                    System.exit(1);
                }
        	    boolean done_tmp = true;
        	    for(BoardControlThread t : threads){
        	        done_tmp &= t.getDone();
        	        if(t.getError()){
        	            log.severe("Thread "+t.getId()+" encountered an error and exited.");
        	            log.info("Terminating...");
        	            cleanup();
        	            System.exit(1);
        	        }
        	        else if(t.getFound()){
        	            System.out.print("\n");
        	            log.info("Thread "+t.getId()+" has found the Common Word.");
        	            String cw = Constants.hexString(t.getCW());
        	            log.info("CW: " + cw);
        	            found = true;
        	            //Write Key to Keyfile
        	            try{
        	                cw = cw + "\n";
        	                wr.write(cw, 0, cw.length());
        	                wr.flush();
        	            }
        	            catch(IOException e){
        	                log.log(Level.WARNING, "Could not write to keyfile. Ingnoring and continuing...", e);
        	            }
        	            break;
        	        }
        	    }
        	    done = done_tmp;
        	    
        	    /*ALIVE OUTPUT*/
        	    //Write something on the output every 30 polling iterations, to inform the user
        	    //that we are still alive and kicking. Do that only when the loglevel is less than 
        	    //6.
        	    if(verbose != 6){
        	        if(cnt == 30){
        	            System.out.print(".");
        	            cnt = 0;
        	        }
        	        cnt++;
        	    }
        	}
        	
        	/*RETRY IF NECESSARY*/
        	if(!found){
            	log.warning("Common Word was not found. Reducing frequency and retrying...\n");
            	//If already on lowest frequency, log and exit
            	if(freq.ordinal() == 0){
            	    log.severe("Already on lowest frequency.");
            	    try{
	                    String tmp = "WARNING: Encountered error. See log for more information\n";
	                    wr.write(tmp, 0, tmp.length());
	                    wr.flush();
	                }
	                catch(IOException e){
	                    log.log(Level.WARNING, "Could not write to keyfile. Ingnoring and continuing...", e);
	                }
	                log.info("Terminating...");
	                cleanup();
	                System.exit(1);
            	}
            	//Set next lowest frequency and restart threads
            	freq = freq.prev();
            	log.fine("Restarting threads");
            	for(BoardControlThread t : threads){
	                t.setFreq(FPGA_PER_BOARD, map.get(freq)[0], map.get(freq)[1]);
	                t.restart();
                }
            	continue;
        	}
        	
        	/*PARSE NEXT SAMPLES*/
        	try{
	            samples = parser.getSamples();
	        }
	        catch(EOFException e){
	            log.info("Reached end of samplefile");
	            log.fine("Exiting Main");
            	cleanup();
            	System.exit(0);
	        }
	        catch(SKException e){
            	log.warning("Not enough samples were found to bruteforce this key. Skipping to next key...");
            	//Wite warning in keyfile
            	try{
	                String tmp = "WARNING: Not enough samples found to bruteforce this key.\n";
	                wr.write(tmp, 0, tmp.length());
	                wr.flush();
	            }
	            catch(IOException e2){
	                log.log(Level.WARNING, "Could not write to keyfile. Ingnoring and continuing...", e2);
	            }
	        }
	        catch(Exception e){
	            log.log(Level.SEVERE, "Error while parsing the Transoprt Stream. Terminating...", e);
	            cleanup();
	            System.exit(1);
	        }
	        log.fine("Samples successfully parsed from Transport Stream");
	        
	        /*SET SAMPLES AND RESTART*/
	        log.fine("Restarting threads");
	        for(BoardControlThread t : threads){
	            t.setSamples(samples);
	            t.restart();
            }
    	}
    }
    
    private static long[][] calculateStartCW(long boardNum){
        //The highest Common Word
        long maxCW = Long.parseLong("FFFFFFFFFFFF", 16);
        //The number of FPGAs to be used
        long fpgaNum = boardNum * FPGA_PER_BOARD;
        //The CW Count/Space that each FPGA has to iterate through
	    long CWdif = (maxCW / fpgaNum) + 1;
	    
	    long start_CW[][] = new long[(int)boardNum][FPGA_PER_BOARD];
	    long tmp = 0;
	    for(int i = 0; i < boardNum; i++){
	        for(int j = 0; j < FPGA_PER_BOARD; j++){
	            start_CW[i][j] = tmp;
	            tmp = tmp + CWdif;
	        }
	    }
	    return start_CW;
    }
    
    
    //NOTE: cleanup() is also called by the ShutdownHook, but isn't implemnted atomically, 
    //because the ShutdownHook will never return, and therefore the previous call of cleanup()
    //will never resume when interrupted. As long as we can guarranty that Operations inside cleanup 
    //can be called more than once without side effects, we are in the green.
    public static void cleanup(){
        log.fine("Cleanup Procedure called.");
        try{
            if(threads != null){
                terminateThreads();
                threads.clear();
            }
            log.finer("Closing Trasport Stream");
            if(ts != null){
                ts.close();
            }
            log.finer("Closing keyfile");
            if(wr != null){
                wr.close();
            }
            log.finer("Closing Logging Facilities.");
            if(log != null){
                //Close and remove all default Handlers
                for(Handler h : log.getHandlers()){
                    //Close() automatically calls flush()
                    h.close();
                    log.removeHandler(h);
                }
            }
        }
        catch(Exception e){
            System.err.println("Error in cleanup function.");
            System.err.println("Well, nevermind.");
        }
    }
    
    public static void terminateThreads(){
        log.info("Suspending FPGAs and Terminating Threads");
        for(BoardControlThread t : threads){
            //Suspend all FPGAs of every Thread
            t.suspend(FPGA_PER_BOARD);
            //Set flag in Threads to exit
            t.terminate();
        }
        //Wait for Threads to exit.
        for(BoardControlThread t : threads){
            log.finer("Waiting for Thread "+t.getId()+" to finish.");
            try{
                t.interrupt();
                t.join(500);
            }
            catch(Exception e){
                log.log(Level.WARNING,"Error waiting for Thread" + t.getId() + "to terminate.", e);
                log.info("Ignoring and continuing...");
            }
        }
    }
}

class ShutdownHook extends Thread{
    private Logger log;
    
    public ShutdownHook(Logger log){
        this.log = log;
    }
    
    public void run(){
        log.warning("Running Shutdown Hook");
        log.warning("Attempting to cleanup...");
        Main.cleanup();
    }
}
