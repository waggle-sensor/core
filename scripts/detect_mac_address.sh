#!/bin/bash

if [ "x${NODE_ID_PREFIX}" != "x" ]; then
  declare -r node_id_prefix=${NODE_ID_PREFIX}
else
  declare -r node_id_prefix="0000"
fi

# returns
mac_address=""
mac_string=""
node_id=""

set +e
mac_address=$(ip link | grep -e '00:1e:06' -e '02:' | awk '{print $2}')
mac_string=$(echo $mac_address | sed 's/://g')

if [ "${mac_address}x" == "x" ] ; then
  echo "error: MAC address not found."
  exit 1
fi
set -e


if [ ! ${#mac_string} -eq 17 ]; then
  node_id="${node_id_prefix}${mac_string}"
else
  echo "error: bad MAC address '${mac_address}'"
  exit 2
fi

export MAC_ADDRESS=$mac_address
export MAC_STRING=$mac_string
export NODE_ID=$node_id

echo "MAC_ADDRESS=${MAC_ADDRESS}"
echo "MAC_STRING=${MAC_STRING}"
echo "NODE_ID=${NODE_ID}"
