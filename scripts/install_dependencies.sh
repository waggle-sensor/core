#!/bin/bash

apt-get install -y htop iotop iftop bwm-ng screen git python-dev python-pip python3-dev python3-pip tree psmisc dosfstools parted bash-completion fswebcam v4l-utils network-manager usbutils nano stress-ng

pip3 install -U pip

# python2 dependencies
pip install tabulate

# python3 dependencies
pip3 install tabulate
