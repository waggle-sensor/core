#!/bin/bash -e
# ANL:waggle-license
#  This file is part of the Waggle Platform.  Please see the file
#  LICENSE.waggle.txt for the legal details of the copyright and software
#  license.  For more details on the Waggle project, visit:
#           http://www.wa8.gl
# ANL:waggle-license

# Documentation
#
# ODROID-XU3/XU4
# Pin 4 = Export No 173
# (GND = PIN2 or PIN30)
# Source: http://odroid.com/dokuwiki/doku.php?id=en:xu4_hardware
# Source: http://dn.odroid.com/5422/ODROID-XU3/Schematics/XU4_HIGHTOPSILK.png

# ODROID-C1/C1+/C0/C2
# Pin: 3 GPIO: 74
# GND: 9 and 39
#
# Source: http://odroid.com/dokuwiki/doku.php?id=en:c1_gpio_default#

# Coral EDGE-TPU
# Pin: 16 GPIO: 73
# GND: 14 and 20
#
# Source: https://coral.withgoogle.com/docs/dev-board/gpio/

# Jetson TX2 with Connect Orbitty Carrier
# Pin: 7 GPIO: 388
# GND: 19
#
# Source: http://www.connecttech.com/pdf/CTIM-ASG003_Manual.pdf

get_wagman_version() {
  if grep -q -i v1 /wagglerw/waggle/wagman_version; then
    echo v1
  elif grep -q -i v2 /wagglerw/waggle/wagman_version; then
    echo v2
  fi
}

get_hbmode() {
  if grep -q -i wellness /etc/waggle/hbmode; then
    echo wellness
  else
    echo always
  fi
}

do_heartbeat_v1() {
    echo "heartbeat - toggle pins"
    echo 1 > /sys/class/gpio/gpio${GPIO_EXPORT}/value
    sleep 1
    echo 0  > /sys/class/gpio/gpio${GPIO_EXPORT}/value
    sleep 1
}

do_heartbeat_v2() {
    echo "heartbeat - ping serial"
    echo hello > $SERIAL
}

do_heartbeat() {
  case "$WAGMAN_VERSION" in
    v1)
      do_heartbeat_v1
      ;;
    v2)
      do_heartbeat_v2
      ;;
    *)
      do_heartbeat_v1
      do_heartbeat_v2
      ;;
  esac
}

run_always_mode() {
  echo "running in always mode"

  while true; do
    do_heartbeat
    sleep 1
  done
}

clear_deadman_trigger() {
  rm /run/waggle_deadman_trigger 2> /dev/null
}

# allow for ~4h without deadman trigger reset
HBCOUNTER_INIT=14400

run_wellness_mode() {
  echo "running in wellness mode"

  hbcounter=$HBCOUNTER_INIT

  while true; do  
    if clear_deadman_trigger; then
      echo "cleared deadman trigger"
      hbcounter=$HBCOUNTER_INIT
    fi

    echo "${hbcounter} heartbeats left"

    if [ $hbcounter -gt 0 ]; then
      let hbcounter-=1
      do_heartbeat
    fi
    
    sleep 1
  done
}

WAGMAN_VERSION=$(get_wagman_version)
echo wagman version $WAGMAN_VERSION

# Detect Odroid model
. /usr/lib/waggle/core/scripts/detect_odroid_model.sh

if [ ${ODROID_MODEL}x == "x" ] ; then
  echo "Device not recognized"
  exit 1
fi

# TODO detect which model wagman we have
if [ ${ODROID_MODEL}x == "XU3x" ] ; then
  GPIO_EXPORT=173
  PIN=4
  SERIAL=/dev/ttySAC0
  stty -F $SERIAL 115200
elif [ ${ODROID_MODEL}x == "ETPUx" ] ; then
  GPIO_EXPORT=73
  PIN=16
  SERIAL=/dev/ttymxc0
  stty -F $SERIAL 115200
elif [ ${ODROID_MODEL}x == "TX2x" ] ; then
  GPIO_EXPORT=388
  PIN=7
  SERIAL=/dev/ttyTHS2
  stty -F $SERIAL 115200
elif [ ${ODROID_MODEL}x == "Cx" ] ; then
  GPIO_EXPORT=74
  PIN=3
  SERIAL=/dev/ttyS2
  stty -F $SERIAL 115200
else
  echo "Device ${ODROID_MODEL} not recognized"
  exit 1
fi

echo "Activating GPIO pin ${PIN} with export number ${GPIO_EXPORT}."

if [ ! -d /sys/class/gpio/gpio${GPIO_EXPORT} ] ; then
  set -x
  echo ${GPIO_EXPORT} > /sys/class/gpio/export
  set +x
fi

set -x
echo "out" > /sys/class/gpio/gpio${GPIO_EXPORT}/direction
set +x

case $(get_hbmode) in
  always)
    run_always_mode
    ;;
  wellness)
    run_wellness_mode
    ;;
  *)
    echo invalid run mode
    exit 1
    ;;
esac
