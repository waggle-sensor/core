#!/bin/bash

# returns
export MAC_ADDRESS=""
export MAC_STRING="" 

set +e
while [ "${MAC_ADDRESS}x" == "x" ] ; do
  export MAC_ADDRESS=$(ip link | grep -A 1 '^2:' | grep 'link/ether' | awk '{print $2}')
  export MAC_STRING=$(echo $MAC_ADDRESS | sed 's/://g')

  if [ "${MAC_ADDRESS}x" == "x" ] ; then
    echo "MAC_ADDRESS not found, retrying..."
    sleep 3
  fi
  
done
set -e


echo "MAC_ADDRESS=${MAC_ADDRESS}"
echo "MAC_STRING=${MAC_STRING}"
