#!/bin/bash

#
# Run this script manually with argument "recover" to actually start recovering partitions after all tests.
# The upstart-invoked version will not automatically do the recovery.
#

# argument "force" will kill other waggle_init process
# argument "recover" will write waggle image to other memory device (SD-card or eMMC), only if needed, e.g. filesystem broken



# Testing
# make sure to delete recovery files when you do changes
# delete /etc/udev/rules.d/70-persistent-net.rules if you plan to change the device/network

#========================
#=== HELPER FUNCTIONS ===
#========================

detect_system_info() {
  #
  # Detect Odroid model
  #
  . /usr/lib/waggle/core/scripts/detect_odroid_model.sh
  # returns ODROID_MODEL


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

  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?CURRENT_DISK_DEVICE_TYPE=${CURRENT_DISK_DEVICE_TYPE}" || true
  fi
}

start_singleton() {
  local force_execution=$1
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
    # either stop current process...
    if [ ${force_execution} -eq 0 ] ; then
       echo "Script is already running. (pid: ${oldpid})"
       exit 1  
    fi

    # ...or delete old process (only if PID is different from ours (happens easily))
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
}

assert_dependencies() {
  #
  # Test if other memory card actually exists
  #
  if [ ! -e ${OTHER_DISK_DEVICE} ] ; then
    echo "other memory card not found."
    
    echo "Exit."
    rm -f ${pidfile}
    exit 0
  else
    echo "${OTHER_DISK_DEVICE_TYPE} memory card found"
  fi

  # set -x
  set -e

  #
  # mkdosfs needed to create vfat partition
  #
  if ! hash mkdosfs > /dev/null 2>&1 ; then  
    echo "mkdosfs not found (apt-get install -y dosfstools)"
    rm -f ${pidfile}
    exit 1
  else
    echo "found mkdosfs"
  fi
}

setup_system() {
  if [ "${CURRENT_DISK_DEVICE_TYPE}x" == "SDx" ] || [ "${CURRENT_DISK_DEVICE_TYPE}x" == "MMCx" ] ; then
    echo "saving current disk device type to /etc/waggle/current_memory_device"
    echo -e "#e.g. 'SD' or 'MMC'\n${CURRENT_DISK_DEVICE_TYPE}" > /etc/waggle/current_memory_device
  else
    echo "error: memory device not recognized: ${CURRENT_DISK_DEVICE_TYPE}"
    exit 1
  fi

  #
  # set hostname and /etc/hosts
  #
  if [ "${MAC_ADDRESS}x" !=  "x" ] ; then
      NEW_HOSTNAME="${MAC_STRING}${CURRENT_DISK_DEVICE_TYPE}"
      
      OLD_HOSTNAME=$(cat /etc/hostname | tr -d '\n')
      
      if [ "${NEW_HOSTNAME}x" != "${OLD_HOSTNAME}x" ] ; then
        echo ${NEW_HOSTNAME} > /etc/hostname
        echo "setting hostname to '${NEW_HOSTNAME}'"
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
  # make sure /media/boot and /media/other* are available 
  #
  echo 'making sure the /media/other* mount points are available to use...'
  local boot_partition=/media/boot
  mkdir -p ${boot_partition}
  set +e
  while [ $(mount | grep "${boot_partition}" | wc -l) -ne 0 ] ; do
    umount ${boot_partition}
    sleep 5
  done
  set -e

  mkdir -p ${OTHER_DISK_P1}
  set +e
  while [ $(mount | grep "${OTHER_DISK_P1}" | wc -l) -ne 0 ] ; do
    umount ${OTHER_DISK_P1}
    sleep 5
  done
  set -e

  mkdir -p ${OTHER_DISK_P2}
  set +e
  while [ $(mount | grep "${OTHER_DISK_P2}" | wc -l) -ne 0 ] ; do
    umount ${OTHER_DISK_P2}
    sleep 5
  done
  set -e

  #
  # umount the other disk partitions by their /dev block devices just in case
  #
  for device in $(mount | grep "^${CURRENT_DISK_DEVICE}/p1" | cut -f1 -d ' ') ; do
    echo "Warning, device ${device} is currently mounted"
    umount ${device}
    sleep 5
  done

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
}

detect_recovery() {
  echo "checking for /root/do_recovery..."
  if [[ -e /root/do_recovery || ${DEBUG} -eq 1 ]] ; then
    return 1
  fi

  #
  # Check other boot partition
  #
  echo "checking ${OTHER_DISK_DEVICE_TYPE} card's boot partition..."
  if [ $(parted -s -m ${OTHER_DISK_DEVICE} print | grep "^1:.*fat16::;" | wc -l ) -eq 1 ] ; then
    echo "boot partition found"
    set +e
    fsck.fat -n ${OTHER_DISK_DEVICE}p1
    if [ $? -ne 0 ]  ; then
      echo "!!! fsch.fat returned error"
      return 1
    else
      echo "boot partition FAT filesystem OK"
    fi
    set -e
  else
    echo "!!! boot partition not found"
    return 1
  fi

  set +e
  mount ${OTHER_DISK_DEVICE}p1 ${OTHER_DISK_P1}
  if [ $? -ne 0 ]  ; then
    echo "!!! Could not mount boot partition"
    return 1
  else
    echo "boot partition mounted"

    if [ -e ${OTHER_DISK_P1}/boot.ini ] ; then
      echo "boot partition looks legit"
    else
      echo "!!! boot partition has no boot.ini"
      return 1
    fi
  fi
  echo "unmounting boot partition..."
  set +e
  while [ $(mount | grep "${OTHER_DISK_P1}" | wc -l) -ne 0 ] ; do
    umount ${OTHER_DISK_P1}
    sleep 5
  done
  set -e

  #
  # Check other data partition
  #

  echo "checking ${OTHER_DISK_DEVICE_TYPE} card's data partition..."
  if [ $(parted -s -m ${OTHER_DISK_DEVICE} print | grep "^2:.*ext4::;" | wc -l ) -eq 1 ] ; then
    echo "data partition found"
    set +e
    fsck.ext4 -n ${OTHER_DISK_DEVICE}p2
    if [ $? -ne 0 ]  ; then
      echo "!!! fsck.ext4 returned an error"
      return 1
    else
      echo "data partition ext4 filesystem OK"
    fi
    set -e
  else
    echo "!!! data partition not found"
    return 1
  fi

  set +e
  mount ${OTHER_DISK_DEVICE}p2 ${OTHER_DISK_P2}
  if [ $? -ne 0 ]  ; then
    echo "!!! Could not mount data partition"
    return 1
  else
    echo "data partition mounted"
    if [ -d ${OTHER_DISK_P2}/usr/lib/waggle ] ; then
      echo "data partition looks legit"
    else
      echo "!!! data partition has no waggle directory"
      return 1
    fi
  fi

  echo "unmounting data partition..."
  set +e
  while [ $(mount | grep "${OTHER_DISK_P2}" | wc -l) -ne 0 ] ; do
    umount ${OTHER_DISK_P2}
    sleep 5
  done
  set -e
}

recover_other_disk() {
  echo "recovering the ${OTHER_DISK_DEVICE_TYPE} card..."
  
  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=recovery_init" || true
  fi
  
  set -e
  # set -x
  
  #wipe first 500MB (do not wipe eMMC on XU4)
  echo "wiping the first 500MB of the ${OTHER_DISK_DEVICE_TYPE} card..."
  if [ "${ODROID_MODEL}x" == "Cx" ] || [ "${OTHER_DISK_DEVICE_TYPE}x" == "SDx" ] ; then
    dd if=/dev/zero of=${OTHER_DISK_DEVICE} bs=1M count=500
    sync
    sleep 2
  fi
  
  # write boot loader and u-boot files (this is an odroid script)
  

  echo "creating ${OTHER_DISK_DEVICE_TYPE} card's partitions..."  
  cd /usr/lib/waggle/core/setup-disk/
  #./write-boot.sh ${OTHER_DISK_DEVICE}
  ./make-partitions.sh  ${OTHER_DISK_DEVICE}
  sleep 3
  
  echo "writing ${OTHER_DISK_DEVICE_TYPE} card's boot loader..."  
  if [ "${ODROID_MODEL}x" == "Cx" ] ; then
    cd /usr/share/c1_uboot
    ./sd_fusing.sh ${OTHER_DISK_DEVICE}
  elif [ "${ODROID_MODEL}x" == "XU3x" ] ; then
      cd /usr/lib/waggle/core/setup-disk/xu3
      ./sd_fusing.sh ${OTHER_DISK_DEVICE}
  fi

  mount ${CURRENT_DISK_DEVICE}p1 /media/boot
  mount ${OTHER_DISK_DEVICE}p1 ${OTHER_DISK_P1}/
  mount ${OTHER_DISK_DEVICE}p2 ${OTHER_DISK_P2}/

  #
  # create recovery files for partitions
  #
  echo "creating ${OTHER_DISK_DEVICE_TYPE} card's partitions..."  
  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=create_recovery_p1" || true
  fi
  set +e 

  echo "syncing boot partition files to ${OTHER_DISK_DEVICE_TYPE} card partitions..."  
  cd /media/boot
  rsync --archive --verbose ./ ${OTHER_DISK_P1} --exclude=.Spotlight-V100 --exclude=.fseventsd
  exitcode=$?
  if [ "$exitcode" != "1" ] && [ "$exitcode" != "0" ]; then
    exit $exitcode
  fi
  set -e
  touch ${OTHER_DISK_P1}/recovered.txt

  echo "syncing data partition files to ${OTHER_DISK_DEVICE_TYPE} card partitions..."  
  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=create_recovery_p2" || true
  fi
  set +e 
  cd /
  rsync --archive --verbose --one-file-system ./ ${OTHER_DISK_P2} --exclude=recovery_p1.tar.gz --exclude=recovery_p1.tar.gz_part --exclude=recovery_p2.tar.gz_part --exclude=recovery_p2.tar.gz --exclude='dev/*' --exclude='proc/*' --exclude='sys/*' --exclude='tmp/*' --exclude='run/*' --exclude='mnt/*' --exclude='media/*' --exclude=lost+found --exclude='var/cache/apt/*' --exclude='var/log/*'
  exitcode=$?
  if [ "$exitcode" != "1" ] && [ "$exitcode" != "0" ]; then
    # exit code 1 means: Some files differ
    exit $exitcode
  fi
  mkdir -p sys tmp run mnt media dev proc
  touch ${OTHER_DISK_P2}/recovered.txt
  
  #
  # indicate recovery process completed
  #
  OTHER_DISK_DEVICE_BOOT_UUID=$(blkid -o export ${OTHER_DISK_DEVICE}p1 | grep "^UUID" |  cut -f2 -d '=')
  echo "OTHER_DISK_DEVICE_BOOT_UUID: ${OTHER_DISK_DEVICE_BOOT_UUID}"
  
  OTHER_DISK_DEVICE_DATA_UUID=$(blkid -o export ${OTHER_DISK_DEVICE}p2 | grep "^UUID" |  cut -f2 -d '=')
  echo "OTHER_DISK_DEVICE_DATA_UUID: ${OTHER_DISK_DEVICE_DATA_UUID}"
  
  # modify boot.ini
  sed -i.bak 's/root=UUID=[a-fA-F0-9-]*/root=UUID='${OTHER_DISK_DEVICE_DATA_UUID}'/' ${OTHER_DISK_P1}/boot.ini 

  if [ $(grep -v "^#" ${OTHER_DISK_P2}/boot.ini | grep "root=UUID=${OTHER_DISK_DEVICE_DATA_UUID}" | wc -l) -eq 0 ] ; then
      echo "Error: boot.ini does not have new UUID in bootargs or bootrootfs"
      rm -f ${pidfile}
      exit 1
  fi

  # write /etc/fstab
  echo "UUID=${OTHER_DISK_DEVICE_DATA_UUID}	/	ext4	errors=remount-ro,noatime,nodiratime		0 1" > ${OTHER_DISK_P2}/etc/fstab
  echo "UUID=${OTHER_DISK_DEVICE_BOOT_UUID}	/media/boot	vfat	defaults,rw,owner,flush,umask=000	0 0" >> ${OTHER_DISK_P2}/etc/fstab
  echo "tmpfs		/tmp	tmpfs	nodev,nosuid,mode=1777			0 0" >> ${OTHER_DISK_P2}/etc/fstab

  rm -f /root/do_recovery ${OTHER_DISK_P2}/root/do_recovery

  echo "${MAC_STRING}_${OTHER_DISK_DEVICE_TYPE}" > ${OTHER_DISK_P2}/etc/hostname


  # unmount current disk's boot partition
  while [ $(mount | grep "/media/boot" | wc -l) -ne 0 ] ; do
    umount /media/boot
    sleep 5
  done
  set -e

  # unmount other disk's boot partition
  set +e
  while [ $(mount | grep "${OTHER_DISK_P1}" | wc -l) -ne 0 ] ; do
    umount ${OTHER_DISK_P1}
    sleep 5
  done
  set -e
  
  # unmount other disk's data partition
  set +e
  while [ $(mount | grep "${OTHER_DISK_P2}" | wc -l) -ne 0 ] ; do
    umount ${OTHER_DISK_P2}
    sleep 5
  done
  set -e

  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=recovery_done" || true
  fi
}

sync_disks() {
  #
  # sync config and cert files
  #
      
  if [ -e ${OTHER_DISK_DEVICE}p2 ] ; then    
    mount ${OTHER_DISK_DEVICE}p2 ${OTHER_DISK_P2}/

    sleep 1

    rsync --archive --update /etc/waggle/ ${OTHER_DISK_P2}/etc/waggle
    rsync --archive --update ${OTHER_DISK_P2}/etc/waggle/ /etc/waggle

    local node_dir=/usr/lib/waggle/SSL/node
    local other_disk_node_dir=${OTHER_DISK_P2}${node_dir}
    mkdir -p ${other_disk_node_dir} ${node_dir}

    if [ -e ${node_dir}/ ] ; then
      rsync --archive --update ${node_dir}/ ${other_disk_node_dir}
    fi

    if [ -e ${other_disk_node_dir}/ ] ; then
      rsync --archive --update ${other_disk_node_dir}/ ${node_dir}
    fi

    # make sure we don't have an extra copy of the registration key lying around
    if [[ -e ${other_disk_node_dir}/cert.pem && ${other_disk_node_dir}/key.pem ]]; then
      rm -f ${OTHER_DISK_P2}/root/id_rsa_waggle_aot_registration
    fi

    if [ ${DEBUG} -eq 1 ]; then
      curl --retry 10 "${DEBUG_HOST}/failovertest?status=rsync_done" || true
    fi

    set +e
    while [ $(mount | grep "${OTHER_DISK_P2}" | wc -l) -ne 0 ] ; do
      umount ${OTHER_DISK_P2}
      sleep 5
    done
    set -e

  fi
}

stop_singleton() {
  rm -f ${pidfile}
}


#====================
#===     MAIN     ===
#====================

FORCE_EXECUTION=0
FORCE_RECOVERY=0
while [[ $# -gt 0 ]]; do
  key="$1"
  echo "Key: $key"
  case $key in
    --force)
      FORCE_EXECUTION=1
      ;;
    --recover)
      FORCE_RECOVERY=1
      ;;
      *)
      ;;
  esac
  shift
done


declare -r DEBUG=0
declare -r DEBUG_HOST=""

# This file can be used by other services to avoid reboots
# until the waggle-init service has finished performing
# critical activities.
declare -r INIT_FINISHED_FILE="/root/init_finished"
declare -r INIT_FINISHED_FILE_WAGGLE="/home/waggle/init_finished"

declare -r OTHER_DISK_P1=/media/otherp1
declare -r OTHER_DISK_P2=/media/otherp2

if [ ${DEBUG} -eq 1 ] ; then
  curl --retry 10 "${DEBUG_HOST}/failovertest?status=starting" || true
fi

echo "starting waggle_init.sh"

rm ${INIT_FINISHED_FILE}
rm ${INIT_FINISHED_FILE_WAGGLE}

# set the following global variables:
#   ODROID_MODEL, MAC_ADDRESS, MAC_STRING, CURRENT_DISK_DEVICE, CURRENT_DISK_DEVICE_NAME,
#   CURRENT_DISK_DEVICE_TYPE, OTHER_DISK_DEVICE, OTHER_DISK_DEVICE_NAME, and OTHER_DISK_DEVICE_TYPE
detect_system_info

# keep track of the PID to prevent multiple executions of this script
start_singleton $FORCE_EXECUTION

# assert that all dependencies for execution have been met
assert_dependencies

# set the hostname and do some other things
setup_system

# check various conditions to determine if recovery of the other boot disk is needed
RECOVERY_NEEDED=0
if [ ${FORCE_RECOVERY} -eq 0 ]; then
  detect_recovery
  RECOVERY_NEEDED=$?
fi

# recover the other boot disk if necessary
if [[ ${FORCE_RECOVERY} -eq 1 || ${RECOVERY_NEEDED} -eq 1 ]] ; then
  recover_other_disk
else
  if [ ${DEBUG} -eq 1 ] ; then
    curl --retry 10 "${DEBUG_HOST}/failovertest?status=recovery_not_needed" || true
  fi    
  echo "all looks good" 
fi

# make sure both boot media have the same /etc/waggle contents and node credentials
sync_disks

touch ${INIT_FINISHED_FILE}
touch ${INIT_FINISHED_FILE_WAGGLE}

if [ ${DEBUG} -eq 1 ] ; then
  curl --retry 10 "${DEBUG_HOST}/failovertest?status=done" || true
fi

stop_singleton

if [ ${DEBUG} -eq 1 ]; then
  set +e
  shutdown -h now
  exit 1
fi
