#!/bin/bash

if [ -e /run/stress.log ] ; then
	echo "/run/stress.log already exists."
	rm /run/stress.log
fi

RUN_DURATION=14m

if [ "${MODEL_REPORTED}x" == "ODROIDCx" ] ; then
	ODROID_MODEL="C"
	CPU_COUNT=4
elif [ "${MODEL_REPORTED}x" == "ODROID-XU3x" ] ; then
	ODROID_MODEL="XU3"
	RUN_DURATION=23m
	CPU_COUNT=8
else
	echo "Model ${MODEL_REPORTED} unknown."
	echo "405" > /run/stress.log
	exit 1
fi

echo "ODROID_MODEL=${ODROID_MODEL}"

set -x

stress-ng --cpu ${CPU_COUNT} --io 2 --vm 1 --vm-bytes 500M --timeout ${RUN_DURATION} --metrics-brief
STRESS_RESULT=$?

if [ ${STRESS_RESULT} -ne 0 ] ; then
	echo "Error: Error code: ${STRESS_RESULT}"
	echo "failed" > /run/stress.log
else
	echo "success" > /run/stress.log
fi