#!/bin/bash

set -x
set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###locale
locale-gen --purge "en_US.UTF-8"
#dpkg-reconfigure locales
echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' > /etc/default/locale

### timezone
echo "Etc/UTC" > /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

# because of "Failed to fetch http://ports.ubuntu.com/... ...Hash Sum mismatch"
#rm -rf /var/lib/apt/lists/*
touch -t 1501010000 /var/lib/apt/lists/*
rm -f /var/lib/apt/lists/partial/*
apt-get clean
apt-key update
apt-get update
apt-get autoclean
apt-get autoremove -y

# disable software update and new release checks and messages
# (don't want the node connecting to anything other than the beehive server)
apt-get remove --yes update-manager-core
apt-get remove --yes ubuntu-release-upgrader-core
cat /etc/pam.d/sshd | sed 's/^\(..*pam_motd..*\)/# \1/' > /tmp/sshd
mv /tmp/sshd /etc/pam.d/sshd

mkdir -p /etc/waggle/
echo "10.31.81.10" > /etc/waggle/node_controller_host

set -e

# make sure serial console requires password
#sed -i -e 's:exec /bin/login -f root:exec /bin/login:' /bin/auto-root-login

# Change the resize.log location since we delete the odroid user
device_line='device=$(df | grep '"'"'/$'"'"' | awk '"'"'{print $1}'"'"' | sed '"'"'s/p2//'"'"')'
echo $device_line
sed -i -e 's:/home/odroid/resize.log:/root/resize.log:' \
       -e "s:\(    start)\):\1\n\t\t${device_line}:" \
       -e 's:grep mmcblk0p2:grep p2:' \
       -e 's:/dev/mmcblk0:${device}:' /aafirstboot

# Change net raise timeout to something more reasonable
sed -i -e 's:^TimeoutStartSec=5min:TimeoutStartSec=5sec:' /lib/systemd/system/networking.service
sed -i -e 's:^TimeoutStartSec=5min:TimeoutStartSec=5sec:' /lib/systemd/system/ifup@.service
systemctl disable apt-daily.timer
#systemctl disable unattended-upgrades.service

# Restrict SSH connections to local port bindings
sed -i 's/^#ListenAddress ::$/ListenAddress 127.0.0.1/' /etc/ssh/sshd_config


### kill X processses
set +e
killall -u lightdm -9

### username
export odroid_exists=$(id -u odroid > /dev/null 2>&1; echo $?)
export waggle_exists=$(id -u waggle > /dev/null 2>&1; echo $?)

# rename existing user odroid to waggle
if [ ${odroid_exists} == 0 ] && [ ${waggle_exists} != 0 ] ; then
  echo "I will kill all processes of the user \"odroid\" now."
  sleep 1
  killall -u odroid -9
  sleep 2

  set -e

  #This will change the user's login name. It requires you logged in as another user, e.g. root
  usermod -l waggle odroid

  # real name
  usermod -c "waggle user" waggle

  #change home directory
  usermod -m -d /home/waggle/ waggle

  set +e
fi

# create new user waggle
if [ ${odroid_exists} != 0 ] && [ ${waggle_exists} != 0 ] ; then


  set -e

  adduser --disabled-password --gecos "" waggle

  # real name
  usermod -c "waggle user" waggle


  set +e
fi


# verify waggle user has been created
set +e
id -u waggle > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "error: user \"waggle\" was not created"
  exit 1
fi


# check if odroid group exists
getent group odroid > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "\"odroid\" group exists, will rename it to \"waggle\""
  groupmod -n waggle odroid || exit 1
else
  getent group waggle > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Neither \"waggle\" nor \"odroid\" group exists. Will create \"waggle\" group."
    addgroup waggle
  fi
fi



# verify waggle group has been created
getent group waggle > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "error: group \"waggle\" was not created"
  exit 1
fi

echo "adding user \"waggle\" to group \"waggle\""
adduser waggle waggle

echo "removing user \"waggle\" from group \"sudo\""
deluser waggle sudo

set -e


### disallow root access
sed -i 's/^\(PermitRootLogin\) .*/\1 no/' /etc/ssh/sshd_config

### default password
echo waggle:waggle | chpasswd

aot_root_shadow_file=/root/root_shadow
if [ -e ${aot_root_shadow_file} ]; then
  ### AoT password
  aot_root_shadow_entry=$(cat ${aot_root_shadow_file})
  sed -i -e "s/^root:..*/${aot_root_shadow_entry}/" /etc/shadow
else
  ### default password
  echo root:waggle | chpasswd
fi

### Remove ssh host files. Those will be recreated by the /etc/rc.local script by default.
rm -f /etc/ssh/ssh_host*

if [ ! -e '/home/waggle/.ssh' ]; then
  mkdir /home/waggle/.ssh
fi
chmod 700 /home/waggle/.ssh/
touch /home/waggle/.ssh/authorized_keys
chmod 600 /home/waggle/.ssh/authorized_keys
chown waggle:waggle /home/waggle/.ssh/ /home/waggle/.ssh/authorized_keys

### for paranoids
echo > /root/.bash_history
echo > /home/waggle/.bash_history

set +e
# monit accesses /dev/null even after leaving chroot, which makes it impossible unmount the new image
/etc/init.d/monit stop
killall monit
sleep 3

${script_dir}/setup-rabbitmq.sh
