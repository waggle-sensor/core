#!/bin/bash

#
# Run this script manually with argument "recover" to actually start recovering partitions after all tests.
# The upstart-invoked version will not automatically do the recovery.
#

# argument "force" will kill other waggle_init process
# argument "recover" will write waggle image to other memory device (SD-card or eMMC), only if needed, e.g. filesystem broken
# argument "wipe" will force writing to other memory device (wipe forces recover)



# Testing
# make sure to delete recovery files when you do changes
# delete /etc/udev/rules.d/70-persistent-net.rules if you plan to change the device/network
DEBUG=0
DEBUG_HOST=""


if [ ${DEBUG} -eq 1 ] ; then
  curl --retry 10 "${DEBUG_HOST}/failovertest?status=starting" || true
fi


echo "starting waggle_init.sh"


RECOVERY_NEEDED=0

RECOVER_IF_NEEDED=0
WANT_WIPE=0
WANT_FORCE=0


for i in ${1} ${2} ${3} ; do
    if [ "${i}x" == "recoverx" ] ; then
        RECOVER_IF_NEEDED=1
        RECOVERY_NEEDED=1
    fi
    
    if [ "${i}x" == "wipex" ] ; then
        WANT_WIPE=1
        RECOVERY_NEEDED=1
    fi
    
    if [ "${i}x" == "forcex" ] ; then
        WANT_FORCE=1
    fi
    
done

if [ ${DEBUG} -eq 1 ] ; then
    WANT_WIPE=1
    RECOVERY_NEEDED=1
fi


if [ -e /root/do_recovery ] ; then
    RECOVERY_NEEDED=1
    RECOVER_IF_NEEDED=1
fi

# This file can be used by other services to avoid reboots
# until the waggle-init service has finished performing
# critical activities.
INIT_FINISHED_FILE="/root/init_finished"
INIT_FINISHED_FILE_WAGGLE="/home/waggle/init_finished"
rm ${INIT_FINISHED_FILE}
rm ${INIT_FINISHED_FILE_WAGGLE}


if [ ! -e /media/boot/boot.ini ] ; then
  echo "error: could not find /media/boot/boot.ini"
  exit 1
fi

set -x
set -e

pidfile='/var/run/waggle/waggle_init.pid'

#
# delete pidfile if process does not exist
#
oldpid=""
if [ -e ${pidfile} ] ; then
  oldpid=`cat ${pidfile}`

  if ! ps -p ${oldpid} > /dev/null 2>&1 ; then
     rm ${pidfile}
     oldpid=""
  fi
fi

#
# if old process is still running
#
if [ "${oldpid}x" != "x" ] ; then
 
  # either stop current process
  if [ ${WANT_FORCE} -eq 0 ] ; then
     echo "Script is already running. (pid: ${oldpid})"
     exit 1  
     
  fi

  # or delete old process (only if PID is different from ours (happens easily))
  if [ "${oldpid}_" != "$$_"  ] ; then
    echo "Kill other waggle_init process"
    set +e
    kill -9 ${oldpid}
    set -e
    sleep 2
    rm -f ${pidfile}
  fi
fi

mkdir -p /var/run/waggle/

echo "$$" > ${pidfile}


#
# mkdosfs needed to create vfat partition
#
if ! hash mkdosfs > /dev/null 2>&1 ; then  
  echo "mkdosfs not found (apt-get install -y dosfstools)"
  rm -f ${pidfile}
  exit 1
fi

#
# Detect Odroid model
#
. /usr/lib/waggle/core/scripts/detect_odroid_model.sh
# returns ${ODROID_MODEL}


#
# detect MAC address
#
. /usr/lib/waggle/core/scripts/detect_mac_address.sh 
# returns MAC_ADDRESS and MAC_STRING

#
# detect disk device and type
. /usr/lib/waggle/core/scripts/detect_disk_devices.sh 
# returns CURRENT_DISK_DEVICE, CURRENT_DISK_DEVICE_NAME, CURRENT_DISK_DEVICE_TYPE,
#         OTHER_DISK_DEVICE, OTHER_DISK_DEVICE_NAME, OTHER_DISK_DEVICE_TYPE


if [ "${CURRENT_DISK_DEVICE_TYPE}x" == "SDx" ] || [ "${CURRENT_DISK_DEVICE_TYPE}x" == "MMCx" ] ; then

  echo -e "#e.g. 'SD' or 'MMC'\n${CURRENT_DISK_DEVICE_TYPE}" > /etc/waggle/current_memory_device
else
  echo "error: memory device not recognized: ${CURRENT_DISK_DEVICE_TYPE}"
  exit 1
fi


if [ ${DEBUG} -eq 1 ] ; then
  curl --retry 10 "${DEBUG_HOST}/failovertest?CURRENT_DISK_DEVICE_TYPE=${CURRENT_DISK_DEVICE_TYPE}" || true
fi

#
# set hostname and /etc/hosts
#
if [ "${MAC_ADDRESS}x" !=  "x" ] ; then
    NEW_HOSTNAME="${MAC_STRING}${CURRENT_DISK_DEVICE_TYPE}"
    
    OLD_HOSTNAME=$(cat /etc/hostname | tr -d '\n')
    
    if [ "${NEW_HOSTNAME}x" != "${OLD_HOSTNAME}x" ] ; then
      echo ${NEW_HOSTNAME} > /etc/hostname
      echo "NEW_HOSTNAME: ${NEW_HOSTNAME}"
      hostname -F /etc/hostname
    fi
    
    # add hostname to /etc/hosts
    if [ $(grep "127.0.0.1.*${NEW_HOSTNAME}" /etc/hosts | wc -l) -eq 0 ] ; then
      echo  "127.0.0.1       ${NEW_HOSTNAME}" >> /etc/hosts
    fi 
     
  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?MAC_ADDRESS=${MAC_ADDRESS}" || true
  fi

fi


#
# create Node ID
#
/usr/lib/waggle/core/scripts/create_node_id.sh

#
# create recovery files for partitions
#
if [ ! -e /recovery_p2.tar.gz ] ; then
  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=create_recovery_p2" || true
  fi
  cd /
  rm -f  /recovery_p2.tar.gz_part
  set +e 
  GZIP=-1 tar -cvpzf /recovery_p2.tar.gz_part --warning=no-file-changed --exclude=/recovery_p1.tar.gz --exclude=/recovery_p1.tar.gz_part --exclude=/recovery_p2.tar.gz_part --exclude=/recovery_p2.tar.gz --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* --exclude=/tmp/* --exclude=/run/* --exclude=/mnt/* --exclude=/media/* --exclude=/lost+found --exclude=/var/log/upstart/waggle-* --exclude=/var/cache/apt/* --one-file-system /
  exitcode=$?
  if [ "$exitcode" != "1" ] && [ "$exitcode" != "0" ]; then
    # exit code 1 means: Some files differ
    exit $exitcode
  fi
  set -e
  # takes 10 minutes to create file
  mv /recovery_p2.tar.gz_part /recovery_p2.tar.gz
fi


if [ ! -e /recovery_p1.tar.gz ] ; then
  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=create_recovery_p1" || true
  fi
  rm -f  /recovery_p1.tar.gz_part
  set +e 
  tar -cvpzf /recovery_p1.tar.gz_part --exclude=./.Spotlight-V100 --exclude=./.fseventsd --exclude=./.Trashes --one-file-system --directory=/media/boot .
  exitcode=$?
  if [ "$exitcode" != "1" ] && [ "$exitcode" != "0" ]; then
    exit $exitcode
  fi
  set -e
  mv /recovery_p1.tar.gz_part /recovery_p1.tar.gz
fi

#
# make sure /media/test is available 
#
mkdir -p /media/test
set +e
while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
  umount /media/test
  sleep 5
done
set -e



#
# Test if other memory card actually exists
#
if [ ! -e ${OTHER_DISK_DEVICE} ] ; then
  echo "Other memory card not found."
 
  if [ "${CURRENT_DISK_DEVICE_TYPE}x" == "MMCx" ] && [ ${DEBUG} -eq 0 ]; then
  
    echo "Detected MMC, will go to sleep to prevent nodecontroller software from starting"
    sleep infinity
    exit 1
  
  fi
  
  echo "Exit."
  rm -f ${pidfile}
  exit 0
fi

# umount, just in case
for device in $(mount | grep "^${OTHER_DISK_DEVICE}" | cut -f1 -d ' ') ; do 
  echo "Warning, device ${device} is currently mounted"
  umount ${device}
  sleep 5
done

for device in $(mount | grep "^${OTHER_DISK_DEVICE}" | cut -f1 -d ' ') ; do 
  echo "Error, device ${device} is still mounted"
  rm -f ${pidfile}
  exit 1
done



#
# Check other boot partition
#
BOOT_PARTITION_EXISTS=0
if [ $(parted -s -m ${OTHER_DISK_DEVICE} print | grep "^1:.*fat16::;" | wc -l ) -eq 1 ] ; then
  echo "boot partition found"
  BOOT_PARTITION_EXISTS=1
else
  echo "!!! boot partition not found"
  RECOVERY_NEEDED=1  
fi

BOOT_PARTITION_FS_OK=0
if [ ${RECOVERY_NEEDED} -eq 0 ] && [ ${BOOT_PARTITION_EXISTS} -eq 1 ] ; then
  set +e
  fsck.fat -n /dev/mmcblk1p1
  if [ $? -eq 0 ]  ; then
    BOOT_PARTITION_FS_OK=1
  else
    echo "!!! fsch.fat returned error"
    RECOVERY_NEEDED=1
  fi
  set -e
fi


BOOT_PARTITION_MOUNTABLE=0
if [ ${RECOVERY_NEEDED} -eq 0 ] && [ ${BOOT_PARTITION_FS_OK} -eq 1 ] ; then
  mkdir -p /media/test

  set +e
  mount ${OTHER_DISK_DEVICE}p1 /media/test
  if [ $? -ne 0 ]  ; then
    echo "!!! Could not mount boot partition"
    RECOVERY_NEEDED=1
  else
    BOOT_PARTITION_MOUNTABLE=1
  fi
fi

BOOT_PARTITION_BOOT_INI=0
if [ ${RECOVERY_NEEDED} -eq 0 ] && [ ${BOOT_PARTITION_MOUNTABLE} -eq 1 ] ; then

    echo "Boot partition mounted"

    if [ -e /media/test/boot.ini ] ; then
      echo "boot partition looks legit"
      BOOT_PARTITION_BOOT_INI=1
    else
      echo "!!! boot partition has no boot.ini"
      RECOVERY_NEEDED=1
    fi
fi

set +e
while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
  umount /media/test
  sleep 5
done
set -e

#
# Check other data partition
#

DATA_PARTITION_EXISTS=0
if [ $(parted -s -m ${OTHER_DISK_DEVICE} print | grep "^2:.*ext4::;" | wc -l ) -eq 1 ] ; then
  echo "data partition found"
  DATA_PARTITION_EXISTS=1
else
  echo "!!! data partition not found"
  RECOVERY_NEEDED=1
fi

DATA_PARTITION_FS_OK=0
if [ ${RECOVERY_NEEDED} -eq 0 ] && [ ${DATA_PARTITION_EXISTS} -eq 1 ] ; then
  set +e
  fsck.ext4 -n ${OTHER_DISK_DEVICE}p2
  if [ $? -eq 0 ]  ; then
    DATA_PARTITION_FS_OK=1
  else
    echo "!!! fsck.ext4 returned an error"
    RECOVERY_NEEDED=1
  fi
  set -e
fi



DATA_PARTITION_MOUNTABLE=0
if [ ${RECOVERY_NEEDED} -eq 0 ] && [ ${DATA_PARTITION_FS_OK} -eq 1 ] ; then
  mkdir -p /media/test

  set +e
  mount ${OTHER_DISK_DEVICE}p2 /media/test
  if [ $? -ne 0 ]  ; then
    echo "!!! Could not mount data partition"
    RECOVERY_NEEDED=1
  else
    DATA_PARTITION_MOUNTABLE=1
  fi
fi

DATA_PARTITION_WAGGLE=0
if [ ${RECOVERY_NEEDED} -eq 0 ] && [ ${DATA_PARTITION_MOUNTABLE} -eq 1 ] ; then

    echo "Data partition mounted"

    if [ -d /media/test/usr/lib/waggle ] ; then
      echo "data partition looks legit"
      DATA_PARTITION_WAGGLE=1
    else
      echo "!!! data partition has no waggle directory"
      RECOVERY_NEEDED=1
    fi
fi

set +e
while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
  umount /media/test
  sleep 5
done
set -e


# Since we cant't recover eMMC, the test will skip this.
if [ ${DEBUG} -eq 1 ] && [ "${ODROID_MODEL}x" == "XU3x" ] && [ "${CURRENT_DISK_DEVICE_TYPE}x" == "SDx" ] ; then
  RECOVERY_NEEDED=0
  WANT_WIPE=0
  curl --retry 10 "${DEBUG_HOST}/failovertest?status=skip_recovery" || true
  sleep 30
fi


if [ ${RECOVERY_NEEDED} -eq 1 ] ; then
  echo "Warning: Recovery needed !"

  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=recovery_needed" || true
  fi

  if [ ${RECOVER_IF_NEEDED} -eq 1 ] || [ ${WANT_WIPE} -eq 1 ]; then
    echo "recovering..."
    
    if [ ${DEBUG} -eq 1 ] ; then
      curl --retry 10 "${DEBUG_HOST}/failovertest?status=recovery_init" || true
    fi
    
    set -e
    set -x
    
    #wipe first 500MB (do not wipe eMMC on XU4)
    if [ "${ODROID_MODEL}x" == "Cx" ] || [ "${OTHER_DISK_DEVICE_TYPE}x" == "SDx" ] ; then
      dd if=/dev/zero of=${OTHER_DISK_DEVICE} bs=1M count=500
      sync
      sleep 2
    fi
    
    # write boot loader and u-boot files (this is an odroid script)
    
    
    cd /usr/lib/waggle/core/setup-disk/
    #./write-boot.sh ${OTHER_DISK_DEVICE}
    ./make-partitions.sh  ${OTHER_DISK_DEVICE}
    sleep 3
    
    if [ "${ODROID_MODEL}x" == "Cx" ] ; then
      cd /usr/share/c1_uboot
      ./sd_fusing.sh ${OTHER_DISK_DEVICE}
    fi
    
    if [ "${ODROID_MODEL}x" == "XU3x" ] ; then
        cd /usr/lib/waggle/core/setup-disk/xu3
        ./sd_fusing.sh ${OTHER_DISK_DEVICE}
    fi
  
    mount ${OTHER_DISK_DEVICE}p1 /media/test/
    cd /media/test
    tar xvzf /recovery_p1.tar.gz
    
    touch /media/test/recovered.txt
    
    cd /media
    sleep 1
    
    set +e
    while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
      umount /media/test
      sleep 5
    done
    set -e
    
    mount ${OTHER_DISK_DEVICE}p2 /media/test/
    cd /media/test
    tar xvzf /recovery_p2.tar.gz
    
    cp /recovery_p1.tar.gz /recovery_p2.tar.gz /media/test
    mkdir -p sys tmp run mnt media dev proc
    
    #
    # copy certificate files if available
    #
    mkdir -p /media/test/usr/lib/waggle/SSL/node
    if [ -d /usr/lib/waggle/SSL/node ] ; then
        for file in $(ls -1 /usr/lib/waggle/SSL/node/) ; do
          cp /usr/lib/waggle/SSL/node/${file} /media/test/usr/lib/waggle/SSL/node
        done
    fi
    
    #
    # indicate recovery process completed
    #
    touch /media/test/recovered.txt
    
    cd /media
    sleep 1
    
    set +e
    while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
      umount /media/test
      sleep 5
    done
    set -e
    
    
    OTHER_DISK_DEVICE_BOOT_UUID=$(blkid -o export ${OTHER_DISK_DEVICE}p1 | grep "^UUID" |  cut -f2 -d '=')
    echo "OTHER_DISK_DEVICE_BOOT_UUID: ${OTHER_DISK_DEVICE_BOOT_UUID}"
    
    OTHER_DISK_DEVICE_DATA_UUID=$(blkid -o export ${OTHER_DISK_DEVICE}p2 | grep "^UUID" |  cut -f2 -d '=')
    echo "OTHER_DISK_DEVICE_DATA_UUID: ${OTHER_DISK_DEVICE_DATA_UUID}"
    
    
    
    
    # modify boot.ini
    mount ${OTHER_DISK_DEVICE}p1 /media/test/
    sleep 1
    sed -i.bak 's/root=UUID=[a-fA-F0-9-]*/root=UUID='${OTHER_DISK_DEVICE_DATA_UUID}'/' /media/test/boot.ini 
    
    
    
    if [ $(grep -v "^#" /media/test/boot.ini | grep "root=UUID=${OTHER_DISK_DEVICE_DATA_UUID}" | wc -l) -eq 0 ] ; then
        echo "Error: boot.ini does not have new UUID in bootargs or bootrootfs"
        rm -f ${pidfile}
        exit 1
    fi
    
    set +e
    while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
      umount /media/test
      sleep 5
    done
    set -e
    
    # write /etc/fstab
    mount ${OTHER_DISK_DEVICE}p2 /media/test/
    
    echo "UUID=${OTHER_DISK_DEVICE_DATA_UUID}	/	ext4	errors=remount-ro,noatime,nodiratime		0 1" > /media/test/etc/fstab
    echo "UUID=${OTHER_DISK_DEVICE_BOOT_UUID}	/media/boot	vfat	defaults,rw,owner,flush,umask=000	0 0" >> /media/test/etc/fstab
    echo "tmpfs		/tmp	tmpfs	nodev,nosuid,mode=1777			0 0" >> /media/test/etc/fstab
    
    
    # udev should not require changes once it is ok
    
    rm -f /root/do_recovery /media/test/root/do_recovery
    
    echo "${MAC_STRING}_${OTHER_DISK_DEVICE_TYPE}" > /media/test/etc/hostname
    
    
    set +e
    while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
      umount /media/test
      sleep 5
    done
    set -e
    
    # TODO check for failed/partial recovery !
    #TODO recovery files, certificate files, 
    
    if [ ${DEBUG} -eq 1 ] ; then
      curl --retry 10 "${DEBUG_HOST}/failovertest?status=recovery_done" || true
    fi
    
    
  else
    if [ ${DEBUG} -eq 1 ] ; then
      curl --retry 10 "${DEBUG_HOST}/failovertest?status=recovery_denied" || true
    fi
    echo "No automatic recovery. Use argument \"recover\" to invoke recovery."        
  fi
else
  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=recovery_not_needed" || true
  fi    
  echo "all looks good" 
fi



set +e
while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
  umount /media/test
  sleep 5
  done
set -e

#
# sync config and cert files
#
    
if [ -e ${OTHER_DISK_DEVICE}p2 ] ; then    
  mount ${OTHER_DISK_DEVICE}p2 /media/test/

  sleep 1

  rsync --archive --update /etc/waggle/ /media/test/etc/waggle
  rsync --archive --update /media/test/etc/waggle/ /etc/waggle

  mkdir -p /media/test/usr/lib/waggle/SSL/node /usr/lib/waggle/SSL/node

  if [ -e /usr/lib/waggle/SSL/node/ ] ; then
    rsync --archive --update /usr/lib/waggle/SSL/node/ /media/test/usr/lib/waggle/SSL/node
  fi

  if [ -e /media/test/usr/lib/waggle/SSL/node/ ] ; then
    rsync --archive --update /media/test/usr/lib/waggle/SSL/node/ /usr/lib/waggle/SSL/node
  fi

  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=rsync_done" || true
  fi

  set +e
  while [ $(mount | grep "/media/test" | wc -l) -ne 0 ] ; do
    umount /media/test
    sleep 5
  done
  set -e

fi

touch ${INIT_FINISHED_FILE}
touch ${INIT_FINISHED_FILE_WAGGLE}

if [ ${DEBUG} -eq 1 ] ; then
  curl --retry 10 "${DEBUG_HOST}/failovertest?status=done" || true
fi

rm -f ${pidfile}

if [ ${DEBUG} -eq 1 ]; then

  set +e
  shutdown -h now
  exit 1
fi
