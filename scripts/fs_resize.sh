#!/bin/bash
# ANL:waggle-license
#  This file is part of the Waggle Platform.  Please see the file
#  LICENSE.waggle.txt for the legal details of the copyright and software
#  license.  For more details on the Waggle project, visit:
#           http://www.wa8.gl
# ANL:waggle-license

# this script was take from the ODROID image and was slighlty modified to support mmcblk0 AND mmcblk1 device names. It also can be used directly as an executable


fs_resize() { 
	
	AC=$(whiptail --backtitle "Hardkernel ODROID Utility v$_REV" --yesno "Before running this, you must be sure that /dev/mmcblk0p2 is your root partition.
		To do this make sure you are booting the eMMC or the microSD ALONE!.
		
		DO YOU WANT TO CONTINUE?" 0 0 3>&1 1>&2 2>&3)
	
	rets=$?
	if [ $rets -eq 0 ]; then
		do_resize
	elif [ $rets -eq 1 ]; then
		return 0
	fi	
	
	return 0		
}

do_resize() {
	case "$DISTRO" in
		"ubuntu")
			resize_p2 ;;
		"debian")
			resize_p2 ;;
		"ubuntu-server")
			resize_p2 ;;
		*)
			echo "FS_RESIZE: Sorry your distro $DISTRO isn't supported yet. Please report on the forums"
			;;
	esac
}

resize_p2() {
    DEVICE=$1
	# this takes in consideration /dev/mmcblk0p2 as the rootfs! 
	rsflog=/root/resize-$DATE-log.txt
	echo "Saving the log to $rsflog"
	sleep 4
	
    set -x
    
	p2_start=`fdisk -l ${DEVICE} | grep ${CURRENT_DEVICE}p2 | awk '{print $2}'`
	
	if [ "$DISTRO_VERSION" = "15.04" ]; then
		p2_finish=$((`fdisk -l ${DEVICE} | grep Disk | grep sectors | awk '{printf $7}'` - 1024))
	else
		p2_finish=$((`fdisk -l ${DEVICE} | grep total | grep sectors | awk '{printf $8}'` - 1024))
	fi
	
	fdisk ${DEVICE} <<EOF &>> $rsflog
p
d
2
n
p
2
$p2_start
$p2_finish
p
w
EOF

	if [ "$DISTRO_VERSION" = "15.04" ]; then
	cat <<\EOF > /lib/systemd/system/fsresize.service
[Unit]
Description=Resize FS

[Service]
Type=simple
ExecStart=/etc/init.d/resize2fs_once start

[Install]
WantedBy=multi-user.target
EOF

	systemctl enable fsresize
	
fi




	cat <<\EOF > /etc/init.d/resize2fs_once
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop: 
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs [DEVICE]p2 &&
    rm /etc/init.d/resize2fs_once &&
    update-rc.d resize2fs_once remove &&
    log_end_msg $?
    ;;
  *)  
    echo "Usage: $0 start" >&2
    exit 3
    ;;
esac  
EOF

  sed -i -e 's:\[DEVICE\]:'${DEVICE}':' /etc/init.d/resize2fs_once
  chmod +x /etc/init.d/resize2fs_once
  update-rc.d resize2fs_once defaults
  
  
  REBOOT=1
  
  echo "Rootfs Extended. Please reboot to take effect"
  return 0
}



##### START ######




CURRENT_DEVICE=$(mount | grep "on / " | cut -f 1 -d ' ' | grep -o "/dev/mmcblk[0-1]")
if [ "${CURRENT_DEVICE}x" == "x" ] ; then
  echo "memory card not recognized"
  exit 1
fi

resize_p2 ${CURRENT_DEVICE}




