#!/bin/bash

# returns
export MAC_ADDRESS=""
export MAC_STRING=""
export NODE_ID=""

set +e

ifaces=$(ls -d /sys/class/net/enx* /sys/class/net/eth*)
for iface in $ifaces; do
  export $(udevadm info --path=$iface | grep IFINDEX | awk '{print $2}')
  if [ $IFINDEX == 2 ]; then
    export $(udevadm info -p $iface | grep "E: ID_NET_NAME_MAC" | awk '{print $2}')
    export $(udevadm info -p $iface | grep "E: INTERFACE" | awk '{print $2}')
    export MAC_STRING=$(echo "$ID_NET_NAME_MAC" | sed 's/enx//')
    export MAC_ADDRESS=$(ip link show $INTERFACE| grep -A 1 '^2:' | grep 'link/ether' | awk '{print $2}')
    export NODE_ID="0000${MAC_STRING}"
  fi
done

set -e


echo "MAC_ADDRESS=${MAC_ADDRESS}"
echo "MAC_STRING=${MAC_STRING}"
echo "NODE_ID=${NODE_ID}"
