# *.vhd.Mx

## Description

I have implemented 4 slightly different versions of the top entities, that connect the bruteforce cores differently.

NOTE: I have put the different implementations in different files instead of implementing different VHDL architectures, because the entities are also slightly different.

## VERSIONS

* M1  
  This version takes a 48bit std_logic_vector as the starting CW. In the top entity of the
  fpga this number is added MAX_CORE_NUM times with the DIF (CW count that every core will
  iterate for himself) and gives every start and stop CW (48 bits) to every core via ports.
  A counter is used to detect when the pre-calculation of all the start and stop CWs is
  completed. During this precalculation all cores are kept in a reset state (Reset pulled 
  high). After the counter reaches the defined value the reset is pulled low and all cores
  start iterate through their given CWs.

* M2  
  This version takes a 48bit std_logic_vector as the starting CW. In the top entity of the
  fpga this number is added MAX_CORE_NUM times with the DIF (CW count that every core will
  iterate for himself) via a pipeline with MAX_CORE_NUM adders and gives every start and 
  stop CW (48 bits) to every core via ports. A shift register is used to detect when the 
  precalculation of all the start and stop CWs is completed. During this precalculation 
  all cores are kept in a reset state (Reset pulled high). After the highest bit of the 
  shift register is set the reset is pulled low and all cores start iterate through their 
  given CWs.
        
* M3  
  This version takes a 48bit std_logic_vector as the starting CW. In this version the 
  precalculation of the start and stop CWs is done by each core for himself. The top entity 
  merely connects the initial starting CW to the first core, and then connects each stop
  CW of every core to the start CW port of the next core. Inside the core, the calculation
  takes 1 clk cycle and there is no special handling or stalling during this cycle. That is
  because the core calculates his stop CW, which is first used 67 cycles after the core exits
  the reset state. So - with others words - as long as there is less than 67 core instantiated,
  all cores will have a valid stop CW during their first CW comparison.
        
* M4  
  This version takes an entirely different route. This version focuses on limiting the interconnect.
  This version bases on the fact that when using a number of FPGAs that is a power of two,
  we can basically divide the CW space to iterate (2^48) by this number, which would just 
  split the 48 bits into smaller chunks. 
  E.g. when using 32 FPGAs, each FPGA just needs to iterate a 48-log2(32)=43 bits. 
  Because of this perfect split up there is no need to implement an adder that is calculating
  48-bit sums in runtime in order to find the start and stop CWs. That is all done during
  Compilation/Synthesis via generics. Each core merely needs to prepend these splitted up
  bits in the final CW.
  In our example (32 FPGAs) each core will have a 5bit Input that identifies the FPGA and
  prepends this 5 bits to the calculated 43 bits and gets the wanted 48-bit CW. 