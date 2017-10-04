#!/bin/bash

# returns
mac_address=""
mac_string=""

set +e
# All Odroid MAC addresses (so far) have the organizational prefix 00:1e:06
mac_address=$(ip link | grep -e '00:1e:06' | awk '{print $2}')
if [ "x$mac_address" == "x" ]; then
  # Locally Administered Mac Addresses
  # TODO: look for any addresses in the following form:
  # x2-xx-xx-xx-xx-xx
  # x6-xx-xx-xx-xx-xx
  # xA-xx-xx-xx-xx-xx
  # xE-xx-xx-xx-xx-xx
  mac_address=$(ip link | grep -e '02:' | awk '{print $2}')
fi
mac_string=$(echo $mac_address | sed 's/://g')

if [ "${mac_address}x" == "x" ] ; then
  echo "error: MAC address not found."
  exit 1
fi
set -e

if [ ${#mac_string} -ne 12 ]; then
  echo "error: bad MAC address '${mac_address}'"
  exit 2
fi

export MAC_ADDRESS=$mac_address
export MAC_STRING=$mac_string

echo "MAC_ADDRESS=${MAC_ADDRESS}"
echo "MAC_STRING=${MAC_STRING}"

# temporary patch until we know where any other instances of NODE_ID may exist
export NODE_ID=$MAC_STRING
