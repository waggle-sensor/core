#!/bin/bash

export CURRENT_DISK_DEVICE=$(mount | grep "on / " | cut -f 1 -d ' ' | grep -o "/dev/mmcblk[0-1]")
export OTHER_DISK_DEVICE=""

if [ "${CURRENT_DISK_DEVICE}x" == "x" ] ; then
  echo "memory card not recognized"
  rm -f ${pidfile}
  exit 1
fi


if [ "${CURRENT_DISK_DEVICE}x" == "/dev/mmcblk0x" ] ; then
  export CURRENT_DISK_DEVICE_NAME="mmcblk0"
  export OTHER_DISK_DEVICE="/dev/mmcblk1"
  export OTHER_DISK_DEVICE_NAME="mmcblk1"
fi

if [ "${CURRENT_DISK_DEVICE}x" == "/dev/mmcblk1x" ] ; then
  export CURRENT_DISK_DEVICE_NAME="mmcblk1"
  export OTHER_DISK_DEVICE="/dev/mmcblk0"
  export OTHER_DISK_DEVICE_NAME="mmcblk0"
fi

#
# SD-card or eMMC ? "SD" or "MMC"
#
export CURRENT_DISK_DEVICE_TYPE=$(cat /sys/block/${CURRENT_DISK_DEVICE_NAME}/device/type)
export OTHER_DISK_DEVICE_TYPE=""
if [ -e /sys/block/${OTHER_DISK_DEVICE_NAME}/device/type ] ; then
    export OTHER_DISK_DEVICE_TYPE=$(cat /sys/block/${OTHER_DISK_DEVICE_NAME}/device/type)
fi
