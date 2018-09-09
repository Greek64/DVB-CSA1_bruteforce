# HOST Software

The host software is written in Java, since the ZTEX SDK for configuring and communicating with the ZTEX
boards has only full support for Java.

The software is programmed to read from a transport stream file of any size and brute-force all the keys with
which the transport stream has been encrypted. The found keys are written out on a file in the order in which
they are used in the transport stream. If a key is not found, the software automatically reduces the operating
frequency of the brute-force cores and retries the brute-force procedure. If the key is not found even when in the
lowest frequency setting, an error is logged and the software terminates.

The communication between software and FPGA has no direct impact on the performance and speed of the
brute-force procedure, as the brute-force cores do not require any communication during their operation. The
required data is given to the brute-force cores before they start their operation. Nevertheless, the communication
has an indirect impact on the whole brute-force procedure, as the key is considered found the moment the
software knows that the key has been found, and not the moment a brute-force core finds it. For this reason, the
software polls every ZTEX board at an interval of 500 ms. 

The classes of the software are:

## Main
The Main class is responsible for the parsing of the arguments, scanning of the USB communication bus
for ZTEX devices, and starting and monitoring of the BoardControlThreads. It also registers a shutdown
hook to allow a clean exit of the program even when an interrupt is sent.

## BoardControlThread
Each BoardControlThread is responsible for the communication with a single board and all of its contained
FPGAs. It is reading and writing directly to the USB endpoints. The read status bits of each FPGA
are monitored and handled accordingly. The class provides a restart variable, allowing the threads to be
restarted without the necessity to recreate the threads.

## TranportStreamParser
The TranportStreamParser class is responsible for the parsing of the given transport stream file. The used
keys inside the stream are differentiated with the help of the Scrambling Control Field of the transport 
stream Header.

## Constants
The Constants class is (mis-)used as a kind of header file containing definitions and 
constants needed by all other classes.

## SKException
Special Exception class thrown by TransportStreamParser class.
This exception signals that not enough samples encrypted with the same key were found before
the first packet encrypted with the next (different) key was encountered.
SKException stands for Scrambling Key Exception.