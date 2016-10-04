#!/bin/bash

set -x
set -e

###locale
locale-gen "en_US.UTF-8"
dpkg-reconfigure locales

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
sed -i -e 's:exec /bin/login -f root:exec /bin/login:' /bin/auto-root-login

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

aot_config_key=/root/id_rsa_waggle_aot_config
waggle_password_file=/root/encrypted_waggle_password
if [ -e ${waggle_password_file} ]; then
  echo root:$(openssl rsautl -decrypt -inkey ${aot_config_key} -in ${waggle_password_file}) | chpasswd
else
  echo root:waggle | chpasswd
fi

### Remove ssh host files. Those will be recreated by the /etc/rc.local script by default.
rm -f /etc/ssh/ssh_host*

if [ ! -e '/home/waggle/.ssh' ]; then
  mkdir /home/waggle/.ssh
fi
chmod 700 /home/waggle/.ssh/
chmod 600 /home/waggle/.ssh/authorized_keys
touch /home/waggle/.ssh/authorized_keys
chown waggle:waggle /home/waggle/.ssh/ /home/waggle/.ssh/authorized_keys

### mark image for first boot 

touch /root/first_boot
touch /root/do_resize


rm -f /etc/network/interfaces.d/*
rm -f /etc/udev/rules.d/70-persistent-net.rules 

### for paranoids
echo > /root/.bash_history
echo > /home/waggle/.bash_history

set +e
# monit accesses /dev/null even after leaving chroot, which makes it impossible unmount the new image
/etc/init.d/monit stop
killall monit
sleep 3


### create report

report_file="/root/report.txt"
echo "image created: " > ${report_file}
date >> ${report_file}
echo "" >> ${report_file}
uname -a >> ${report_file}
echo "" >> ${report_file}
cat /etc/os-release >> ${report_file}
dpkg -l >> ${report_file}



