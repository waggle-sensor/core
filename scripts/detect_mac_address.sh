#!/bin/bash

# returns
export MAC_ADDRESS=""
export MAC_STRING=""


set +e
while [ "${MAC_ADDRESS}x" == "x" ] ; do

  for dev in /sys/class/net/eth? ; do
    MODALIAS=""
    if [ -e ${dev}/device/modalias ] ; then
      MODALIAS=$(cat ${dev}/device/modalias)
    fi
    
    PRODUCT_MATCH=0
    if [ -e ${dev}/device/uevent ] ; then
        PRODUCT_MATCH=$(cat ${dev}/device/uevent | grep "PRODUCT=bda/8153/3000" | wc -l)
    fi
    
    # how to detect correct network device:
    # C1+: platform:meson-ethx
    # XU4: PRODUCT=bda/8153/3000
    
    if [ "${MODALIAS}x" ==  "platform:meson-ethx" ] || [ ${PRODUCT_MATCH} -eq 1 ] ; then
        MAC_ADDRESS=$(cat ${dev}/address)
        echo "MAC_ADDRESS: ${MAC_ADDRESS}"
        MAC_STRING=$(echo ${MAC_ADDRESS} | tr -d ":")
    fi
    
  done
  
  if [ "${MAC_ADDRESS}x" == "x" ] ; then
    echo "MAC_ADDRESS not found, retrying..."
    sleep 3
  fi
  
done
set -e


echo "MAC_ADDRESS=${MAC_ADDRESS}"
