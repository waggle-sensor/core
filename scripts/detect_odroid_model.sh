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
elif [ "${MODEL_REPORTED}x" == "ODROID-XU4x" ] ; then
  ODROID_MODEL="XU3"
else
  echo "Model ${MODEL_REPORTED} unknown."
  exit 1
fi

echo "ODROID_MODEL=${ODROID_MODEL}"
