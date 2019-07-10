#!/bin/bash
# ANL:waggle-license
#  This file is part of the Waggle Platform.  Please see the file
#  LICENSE.waggle.txt for the legal details of the copyright and software
#  license.  For more details on the Waggle project, visit:
#           http://www.wa8.gl
# ANL:waggle-license
export MODEL_REPORTED=$(cat /proc/cpuinfo | grep Hardware | grep -o "[^ ]*$")
export ODROID_MODEL=""
export WAGGLE_SERIAL=""

# For Nvidia Jetson
if [ "${MODEL_REPORTED}x" == "x" ] ; then
  if [ -f /sys/module/tegra_fuse/parameters/tegra_chip_id ] ; then
    MODEL_REPORTED=$(cat /sys/module/tegra_fuse/parameters/tegra_chip_id)
  fi
fi

# For Coral EdgeTPU
if [ "${MODEL_REPORTED}x" == "x" ] ; then
  MODEL_REPORTED=$(lsb_release -r | cut -d ':' -f2 | tr -d '\t')
fi

if [ "${MODEL_REPORTED}x" == "x" ] ; then
  echo "no model detected"
  exit 1
fi

case ${MODEL_REPORTED} in
  ODROIDC)
    ODROID_MODEL="C"
    WAGGLE_SERIAL="0000000000000000" ;;
  ODROID-XU3)
    ODROID_MODEL="XU3"
    WAGGLE_SERIAL="0000000000000001" ;;
  ODROID-XU4)
    ODROID_MODEL="XU3"
    WAGGLE_SERIAL="0000000000000001" ;;
  24)
    ODROID_MODEL="TX2"
    WAGGLE_SERIAL="0000000000000002" ;;
  33)
    ODROID_MODEL="NANO"
    WAGGLE_SERIAL="0000000000000003" ;;
  25) ODROID_MODEL="XAVIER"
    WAGGLE_SERIAL="0000000000000004" ;;
  64) ODROID_MODEL="TX1"
    WAGGLE_SERIAL="0000000000000005" ;;
  mendel-chef)
    ODROID_MODEL="ETPU"
    WAGGLE_SERIAL="0000000000000005" ;;
  *)
    echo "Model ${MODEL_REPORTED} unknown."
    exit 1
    ;;
esac

echo "ODROID_MODEL=${ODROID_MODEL}"
echo "WAGGLE_SERIAL=${WAGGLE_SERIAL}"
