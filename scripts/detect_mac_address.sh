#!/bin/bash

# returns
export MAC_ADDRESS=""
export MAC_STRING="" 
export NODE_ID="" 

set +e
while [ "${MAC_ADDRESS}x" == "x" ] ; do
  export MAC_ADDRESS=$(ip link | grep '00:1e:06' | awk '{print $2}')
  export MAC_STRING=$(echo $MAC_ADDRESS | sed 's/://g')

  if [ "${MAC_ADDRESS}x" == "x" ] ; then
    echo "MAC_ADDRESS not found, retrying..."
    sleep 3
  fi
  
done
set -e


echo "MAC_ADDRESS=${MAC_ADDRESS}"
echo "MAC_STRING=${MAC_STRING}"

if [ ! ${#MAC_STRING} -ge 12 ]; then
  echo "error: could not extract MAC address"
  exit 1
else
  NODE_ID="0000${MAC_STRING}"
fi

echo "NODE_ID=${NODE_ID}"
