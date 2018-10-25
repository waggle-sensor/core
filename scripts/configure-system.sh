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

# enable persistent systemd journaling
mkdir -p /var/log/journal

mkdir -p /etc/waggle/
echo "10.31.81.10" > /etc/waggle/node_controller_host

# Change to 'wellness' when ready for deployment
echo "always" > /etc/waggle/hbmode

set -e

# make sure serial console requires password
#sed -i -e 's:exec /bin/login -f root:exec /bin/login:' /bin/auto-root-login

cp ${script_dir}/aafirstboot /
cp ${script_dir}/screenrc /root/.screenrc

# Change net raise timeout to something more reasonable
if [ -f /lib/systemd/system/networking.service ]; then
    sed -i -e 's:^TimeoutStartSec=5min:TimeoutStartSec=5sec:' /lib/systemd/system/networking.service
fi
if [ -f /lib/systemd/system/ifup@.service ]; then
    sed -i -e 's:^TimeoutStartSec=5min:TimeoutStartSec=5sec:' /lib/systemd/system/ifup@.service
fi

systemctl disable apt-daily.timer
systemctl disable time-sync.target
systemctl disable systemd-timesyncd

# Restrict SSH connections to local port bindings
sed -i 's/^#ListenAddress ::$/ListenAddress 127.0.0.1/' /etc/ssh/sshd_config

### username
export odroid_exists=$(id -u odroid > /dev/null 2>&1; echo $?)
export waggle_exists=$(id -u waggle > /dev/null 2>&1; echo $?)

# rename existing user odroid to waggle
set +e
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

set -e

### default password
echo waggle:waggle | chpasswd

### Remove ssh host files. Those will be recreated by the /etc/rc.local script by default.
rm -f /etc/ssh/ssh_host*

if [ ! -e '/home/waggle/.ssh' ]; then
  mkdir /home/waggle/.ssh
fi
chmod 700 /home/waggle/.ssh/
touch /home/waggle/.ssh/authorized_keys
chmod 600 /home/waggle/.ssh/authorized_keys
chown waggle:waggle /home/waggle/.ssh/ /home/waggle/.ssh/authorized_keys
chmod 777 /var/run/screen/

# Setup a proper terminal emulator
fgrep 'export TERM' /home/waggle/.bashrc && true
if [ $? -eq 1 ]; then
  echo 'export TERM=vt100' >> /home/waggle/.bashrc
fi
fgrep 'export TERM' /root/.bashrc && true
if [ $? -eq 1 ]; then
  echo 'export TERM=vt100' >> /root/.bashrc
fi

### for paranoids
echo > /root/.bash_history
echo > /home/waggle/.bash_history
