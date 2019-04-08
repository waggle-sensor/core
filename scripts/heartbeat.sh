#!/bin/bash -e
# ANL:waggle-license
# This file is part of the Waggle Platform.  Please see the file
# LICENSE.waggle.txt for the legal details of the copyright and software
# license.  For more details on the Waggle project, visit:
#          http://www.wa8.gl
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

TIME_LOW=1.0
TIME_HIGH=1.0

pidfile='/var/run/waggle/heartbeat.pid'
OWN_PID=$$

if [ -e ${pidfile} ] ; then
  oldpid=`cat ${pidfile}`

  # delete process only if PID is different from ours (happens easily)
  if [ "${oldpid}_" != "${OWN_PID}_"  ] ; then
    echo "Kill other heartbeat process"
    set +e
    kill -9 ${oldpid}
    set -e
    sleep 2
    rm -f ${pidfile}
  fi
fi

mkdir -p /var/run/waggle/

echo "${OWN_PID}" > /var/run/waggle/heartbeat.pid


MODE='wellness'   # 'wellness' or 'always'
modefile='/etc/waggle/hbmode'
if [ -e ${modefile} ] ; then
  modefile_text=$(cat ${modefile})
  if [ $modefile_text == 'always' ]; then
    MODE='always'
  fi
fi

########

echo ""
echo ""
echo "Starting heartbeat script...  "
echo "TIME: "$(date +"%Y-%m-%d %H:%M" -u)

echo ""
echo "TIME_LOW  : ${TIME_LOW}"
echo "TIME_HIGH : ${TIME_HIGH}"

ALIVE_FILE=/tmp/alive
touch ${ALIVE_FILE}

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

echo "Starting heartbeat (mode '${MODE}')..."

should_heartbeat() {
  if [[ ${ODROID_MODEL}x == "Cx" && ${MODE} == "wellness"  && -e /etc/waggle/init_finished ]] ; then
    CURRENT_TIME=`date +%s`
    ALIVE_TIME=`stat -c %Y ${ALIVE_FILE}`
    ALIVE_DURATION=`python -c "print(${CURRENT_TIME} - ${ALIVE_TIME})"`

    if [ ${ALIVE_DURATION} -gt 86400 ]; then
      echo "$ALIVE_FILE older than 1 day."
      return 1
    fi
  fi

  return 0
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
    echo "heartbeat"

    case "$1" in
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

while true; do
    echo "refresh config"
    wagman_version=$(cat /wagglerw/waggle/wagman_version || true)

    for _ in $(seq 60); do
        if should_heartbeat; then
            do_heartbeat "$wagman_version"
        else
            echo "skipping heartbeat"
        fi

        sleep 1
    done
done
