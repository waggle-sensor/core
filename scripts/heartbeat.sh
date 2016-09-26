#!/bin/bash
set -e


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

########

echo ""
echo ""
echo "Starting heartbeat script...  "
echo "TIME: "$(date +"%Y-%m-%d %H:%M" -u)

echo ""
echo "TIME_LOW  : ${TIME_LOW}"
echo "TIME_HIGH : ${TIME_HIGH}"

ALIVE_FILE=/usr/lib/waggle/waggle_image/alive
touch ${ALIVE_FILE}

# Check if the current device is a C1+ or XU4. 

HEADER=`head -n 1 /media/boot/boot.ini`

DEVICE=""

if [ ${HEADER}x == "ODROIDXU-UBOOT-CONFIGx" ] ; then
  if [ -e /media/boot/exynos5422-odroidxu3.dtb ] ; then
    # XU3 and XU4 are identical
    DEVICE="XU3"
  fi
elif [ ${HEADER}x == "ODROIDC-UBOOT-CONFIGx" ] ; then

  DEVICE="C"


fi


if [ ${DEVICE}x == "x" ] ; then
  echo "Device not recognized"
  exit 1
fi 


if [ ${DEVICE}x == "XU3x" ] ; then
  GPIO_EXPORT=173
  PIN=4
elif [ ${DEVICE}x == "Cx" ] ; then
  GPIO_EXPORT=74
  PIN=3
else
  echo "Device ${DEVICE} not recognized"
  exit 1
fi

echo "Detected device: ${DEVICE}"


echo "Activating GPIO pin ${PIN} with export number ${GPIO_EXPORT}."

if [ ! -d /sys/class/gpio/gpio${GPIO_EXPORT} ] ; then
  set -x
  echo ${GPIO_EXPORT} > /sys/class/gpio/export
  set +x
fi

set -x
echo "out" > /sys/class/gpio/gpio${GPIO_EXPORT}/direction
set +x

echo "Starting heartbeat..."


while [ 1 ] ; do 
  PIN_HIGH=1
  if [ ${DEVICE}x == "Cx" ] ; then
    CURRENT_TIME=`date +%s`
    ALIVE_TIME=`stat -c %Y ${ALIVE_FILE}`
    ALIVE_DURATION=`python -c "print(${CURRENT_TIME} - ${ALIVE_TIME})"`
    if [ ${ALIVE_DURATION} -gt 60 ]; then
      # Skip this heartbeat
      PIN_HIGH=0
    fi
  fi
  echo ${PIN_HIGH} > /sys/class/gpio/gpio${GPIO_EXPORT}/value
  sleep ${TIME_HIGH}
  echo 0  > /sys/class/gpio/gpio${GPIO_EXPORT}/value
  sleep ${TIME_LOW}
done


