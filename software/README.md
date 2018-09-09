
This folder contains software implementations of CSA used as proof of concept or 
generation of encrypted transport streams.

It also contains a example keyfile used to generate transport streams.


## Program Description
|Program |Description|
|--------|-----------|
|csa        |CSA will encrypt a plaintext with the common word using lidvbcsa and then try to decrypt it with a proof of concept implementation of DVB-CSA1.|
|csa-crack  |CSA_CRACK will bruteforce all common words from a configured range and output all possible key candidates. CSA_CRACK uses lidvbcsa for encryption and decryption and uses the bruteforce algorithm stated in the accompanied Thesis|
|tsgen      |TSGEN will generate a transport stream (ts) file containing 4 encrypted packets for each given key. These packets decrypt to packets starting with MPEG PES header (0x00 0x00 0x01...), have an increasing continuity counter, use the transport scrambling control field (odd/even keys), and have slightly different payloads.|
 