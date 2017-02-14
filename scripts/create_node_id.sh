#!/bin/bash

set -e

. /usr/lib/waggle/core/scripts/detect_mac_address.sh

# try memory card serial number
export CID_FILE="/sys/block/mmcblk0/device/cid"
if [ "${NODE_ID}x" == "x" ] && [ -e ${CID_FILE} ]; then
  echo "try using serial number from SD-card"
  # some devices do not have a unique MAC address, they could use this code
 
  export SERIAL_ID=`python -c "cid = '$(cat ${CID_FILE})' ; len=len(cid) ; mid=cid[:2] ; psn=cid[-14:-6] ; print mid+psn"`
  if [ ! ${#SERIAL_ID} -ge 11 ]; then
    echo "warning: could not create unique identifier from SD-card serial number"
  else
    NODE_ID="000000${SERIAL_ID}" 
  fi
fi

# try random number
if [ "${NODE_ID}x" = "x" ] ; then
  NODE_ID=`openssl rand -hex 8`
fi

if [ "${NODE_ID}x" = "x" ] ; then
  echo "could not generate NODE_ID"
  exit 1
fi

echo "NODE_ID: ${NODE_ID}"

#save node ID
mkdir -p /etc/waggle/
echo ${NODE_ID} > /etc/waggle/node_id

