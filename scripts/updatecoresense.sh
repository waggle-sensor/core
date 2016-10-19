#!/bin/bash

#download the file 
rm /tmp/coresense_fw.ino.bin
wget http://www.mcs.anl.gov/research/projects/waggle/downloads/coresense/firmware.ino.bin -O /tmp/coresense_fw.ino.bin

# Ask wagman to powerdown the coresense board
wagman-client stop 2 0
sleep 2
#Ask wagman to powerup the coresense board
wagman-client start 2

#then call coresense flash
./coresenseflash /tmp/coresense_fw.ino.bin
