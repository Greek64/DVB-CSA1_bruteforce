
This folder contains all the necessary files needed for running the 
program. It also contains a symlink to the software directory, 
host directory and xilinx directory to automatically include the 
latest created ts samplefile, csa.jar and Bitstreamfile.

Run:
sudo java -jar csa.jar -h to see the usage.

## File Description
|Filename|Description|
|--------|-----------|
|fx2_firmware.ihx       |The firmware File of the Cypress Chip on the ZTEX Boards.|
|csa.jar                |The java program run on the host that is responsible for the upload and control of the ZTEX Boards.|
|top_28FPGA.bit         |Compiled Bitstreamfile for a cluster with 28 FPGAs (7 ZTEX 1.15y Boards)|
|top_36FPGA.bit         |Compiled Bitstreamfile for a cluster with 36 FPGAs (9 ZTEX 1.15y Boards)|
|ts_1sec                |A sample Transport Stream encrypted with a key that should be found almost immediately.|
|ts_1min                |A sample Transport Stream encrypted with a key that should be found in 1 min (@108 MHz)|
|ts_30min               |A sample Transport Stream encrypted with a key that should be found in 30 min (@108 MHz)|
|ts_28FPGA_full         |A sample Transport Stream encrypted with a key that needs to iterate the whole keyspace to be found. This sample represents the worst execution time. (For 28 FPGA version)|
|ts_36FPGA_full         |A sample Transport Stream encrypted with a key that needs to iterate the whole keyspace to be found. This sample represents the worst execution time. (For 36 FPGA version)|
|ts_edge-test           |A sample Transport Stream encrypted with keys that are in the borders of the iteration space of each Board with additional random keys.|