#!/bin/bash

#download the file 
rm /tmp/wagman_fw.ino.bin
wget http://www.mcs.anl.gov/research/projects/waggle/downloads/wagman/firmware.ino.bin -O /tmp/wagman_fw.ino.bin

#then call coresense flash
./wagmanflash /tmp/wagman_fw.ino.bin
