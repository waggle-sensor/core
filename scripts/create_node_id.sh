#!/bin/bash
# ANL:waggle-license
# This file is part of the Waggle Platform.  Please see the file
# LICENSE.waggle.txt for the legal details of the copyright and software
# license.  For more details on the Waggle project, visit:
#          http://www.wa8.gl
# ANL:waggle-license

set -x

if [ "x${NODE_ID_PREFIX}" != "x" ]; then
  node_id_prefix=${NODE_ID_PREFIX}
else
  node_id_prefix="0000"
fi

set -e

declare -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. ${script_dir}/detect_mac_address.sh
if [ "x${MAC_STRING}" != "x" ]; then
  node_id="${node_id_prefix}${mac_string}"
fi

# try memory card serial number
if [ "${node_id}x" == "x" ]; then
  declare -r cid_file="/sys/block/mmcblk0/device/cid"
  if [ -e ${cid_file} ]; then
    echo "try using serial number from SD-card"
    # some devices do not have a unique MAC address, they could use this code
   
    serial_id=$(python -c "cid = '$(cat ${cid_file})' ; len=len(cid) ; mid=cid[:2] ; psn=cid[-14:-6] ; print mid+psn")
    if [ ! ${#serial_id} -ge 11 ]; then
      echo "warning: could not create unique identifier from SD-card serial number"
    else
      if [ "$node_id_prefix" == "0000" ]; then
        node_id_prefix="0c1d"
      fi
      node_id="0c1d00${SERIAL_ID}" 
    fi
  else
    # random hex number
    if [ "$node_id_prefix" == "0000" ]; then
      node_id_prefix="0227"
    fi
    node_id=${node_id_prefix}$(openssl rand -hex 6)
  fi
fi

if [ "${node_id}x" = "x" ] ; then
  echo "error: could not generate node ID"
  exit 1
fi

export NODE_ID=$node_id
echo "NODE_ID=${NODE_ID}"

#save node ID
mkdir -p /etc/waggle/
echo ${NODE_ID} > /etc/waggle/node_id
