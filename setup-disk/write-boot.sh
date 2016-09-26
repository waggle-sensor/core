#!/bin/bash

set -e


if [ $# -ne 1 ] ; then
  echo "Usage: $0 disk"
  exit 1
fi



# Check if the current device is a C1+ or XU4. 

HEADER=`head -n 1 /media/boot/boot.ini`

DEVICE=""

if [ ${HEADER}x == "ODROIDXU-UBOOT-CONFIGx" ] ; then
  if [ -e /media/boot/exynos5422-odroidxu3.dtb ] ; then
    # XU3 and XU4 are identical
    DEVICE="XU3"
  fi
elif [ ${HEADER}x == "ODROIDC-UBOOT-CONFIGx" ] ; then

  DEVICE="C"


fi


if [ ${DEVICE}x == "x" ] ; then
  echo "Device not recognized"
  exit 1
fi 

echo "Detected device: ${DEVICE}"

if [ ${DEVICE}x == "XU3x" ] ; then
  export DIR="" 
elif [ ${DEVICE}x == "Cx" ] ; then
  export DIR="c1"
else
  echo "Device ${DEVICE} not recognized"
  exit 1
fi


set -x



# write stage 1 section of bootloader (without modifying the MBR)
dd if=./${DIR}/bl1.bin of=$1 bs=1 count=442

# write stage 2 section of bootloader
dd if=./${DIR}/bl1.bin of=$1 bs=512 skip=1 seek=1

# write u-boot
dd if=./${DIR}/u-boot.bin of=$1 bs=512 seek=64

sync
