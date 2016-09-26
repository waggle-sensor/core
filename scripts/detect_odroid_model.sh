#!/bin/bash



export MODEL_REPORTED=$(cat /proc/cpuinfo | grep Hardware | grep -o "[^ ]*$")
export ODROID_MODEL=""

if [ "${MODEL_REPORTED}x" == "x" ] ; then
  echo "no model detected"
  exit 1
fi


if [ "${MODEL_REPORTED}x" == "ODROIDCx" ] ; then
  ODROID_MODEL="C"
elif [ "${MODEL_REPORTED}x" == "ODROID-XU3x" ] ; then
  ODROID_MODEL="XU3"
else
  echo "Model ${MODEL_REPORTED} unknown."
  exit 1
fi

echo "ODROID_MODEL=${ODROID_MODEL}"



####################################
# below is the old code that was used to detect the hardware model. We keep it here just in case we may have to use it again.

#HEADER=`head -n 1 /media/boot/boot.ini`


#ODROID_MODEL=""

#if [ ${HEADER}x == "ODROIDXU-UBOOT-CONFIGx" ] ; then
#  if [ -e /media/boot/exynos5422-odroidxu3.dtb ] ; then
#    # XU3 and XU4 are identical
#    ODROID_MODEL ="XU3"
#  fi
#elif [ ${HEADER}x == "ODROIDC-UBOOT-CONFIGx" ] ; then
#  ODROID_MODEL ="C"
#fi

#if [ ${ODROID_MODEL}x == "x" ] ; then
#  echo "Device not recognized"
#  exit 1
#fi 

#echo "ODROID_MODEL=${ODROID_MODEL}"
