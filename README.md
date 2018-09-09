# DVB-CSA1 Brute-force FPGA Implementation

This project contains the design files used during my Bachelor Thesis work, implementing a Brute-force attack against DVB-CSA1 on various FPGA clusters.  
Even if the project initially focused on two specific hardware platforms, the Hardware Description Language files were written modularly,
to allow any FPGA with enough resources to use them.

## Description

### Directories
* **Thesis**  
The *Thesis* directory contains the Thesis to which this project belongs to.
* **host**  
The *host* directory contains java software responsible for the communication and
management of FPGA clusters through USB connections.
* **run**  
The *run* directory contains all compiled and generated files needed to execute the 
program.
* **software**  
The *software* directory contains helper C programs.
* **vhdl**  
The *vhdl* directory contains the actual HDL code describing the Brute-force 
implementation.
* **xilinx**  
The *xilinx* directory contains the projects for the Spartan 6 and Artix 7 Xilinx 
boards.
* **ztex**  
The *ztex* directory contains the firmware source files for the ztex 1.15y and 2.16
boards.

### Brute-force Attack

The Brute-force attack uses the fact that inside the DVB transport stream the start of a new PES packet is signaled
by a constant 3 byte prefix (0x000001). This effectively gives us a known plaintext segment that can be consistently
found on a live DVB stream.  
In DVB-CSA1, the first 8 Bytes of the decrypted plaintext are only dependent on the first 16 Bytes
of ciphertext, and can be decrypted with reduced hardware requirements (compared to the full DVB-CSA1 
implementation).  
Also, the 3rd and 7th Byte of the 64-bit common word (the key of DVB-CSA1) are usually checksums of the other Bytes
(to make the transmission of the key more reliable), which reduces the effective key length to only 48-bits.  

The Brute-force procedure is to decrypt the first 16 bytes of the ciphertext with all the common words in the 2^48 
key space, and mark all keys that decrypt the first 3 bytes to 0x000001 as possible key candidates. Then, repeat the 
Brute-force procedure with different ciphertext (encrypted with the same common word) using the possible key 
candidates until only one key remains.

For more information read the accompanied Thesis.

### Implementation

Although both hardware targets of this project were Xilinx boards with similar capabilities, the VHDL files
contain no vendor specific code.

#### Core Control Unit

The core_control_unit Entity found in the vhdl directory is the biggest entity that is not project specific and can
be used on other FPGAs.  
It implements a single Bruteforce core, that will iterate through a predetermined number of common words 
(configurable through generics) starting from the given start_cw. It will toggle the found signal and stop operation
when the key is found.  

For more information read section 4.3.4 of the Thesis.

#### ROM/RAM

The CSA implementation needs Substitution-Boxes for both the stream cipher and block cipher. These SBoxes are 
implemented as asynchronous ROMs.  
The Vivado and Xilinx ISE tools mapped these SBoxes to LUTs (due to their asynchronous design).  
A re-implementation to synchronous RAMs would allow to use targeted hardware on specific boards 
(like the BRAM on the Xilinx boards). But it is unsure if there will be any speedup, due to the re-design needed
to make them synchronous.

Special Thanks
--------------
This Project was done in cooperation with
* [Secure Systems Lab Vienna](www.seclab.tuwien.ac.at)
* [Trustworks KG](www.trustworks.at)