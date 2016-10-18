#!/bin/sh

/usr/lib/waggle/core/scripts/detect_mac_address.sh
sed -i -e "s/%MAC_STRING%/$MAC_STRING/" /etc/network/interfaces
