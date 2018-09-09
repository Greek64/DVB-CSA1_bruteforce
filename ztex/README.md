# FX2 Microcontroller Firmware

The FX2 Microcontroller is responsible for the communication with multiple FPGAs.
This is done by having all FPGAs connected to the same bus, and only allowing the FPGA selected by the
Microcontroller to drive the bus signals. This effectively means that the FPGAs cannot communicate with each
other, and that only one FPGA per board can communicate with the software at any time. The latter is not a
problem, because a communication between software and FPGA is only needed during the initialization of the
brute-force procedure and later during the periodic polling of the brute-force results.

Even though the Cypress FX2 Microcontroller provides a vast amount of options, it was decided to remove
the Microcontroller CPU from the communication path between software and FPGA. To accomplish that,
the FX2 Microcontroller is put into "Slave FIFO" mode. In this mode, the USB endpoint FIFOs of the FX2
Microcontroller are directly interfaced by an external master (the FPGAs in our case).

Three USB endpoints are used for the communication between software and FPGA. endpoint 2 is used for
sending the initialization data required by the brute-force cores. endpoint 4 is used for sending the frequency
parameters required for the dynamic frequency reconfiguration. endpoint 6 is used by the FPGA for sending the
status bits and the key to the software.

Vendor Commands and Requests were configured to reset, suspend and resume the FPGA, as well as reset the
frequency generators (DCM/MMCM). An extra Vendor Request was added for providing Debug information of
the endpoints and FIFOs.

The Cypress FX2 Microcontroller is also used to configure the FPGAs, by uploading the compiled Bitstreamfiles
onto them. 

## Output files
The *.ihx files are the compiled firmware files.