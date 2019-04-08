#!/bin/bash
# ANL:waggle-license
#  This file is part of the Waggle Platform.  Please see the file
#  LICENSE.waggle.txt for the legal details of the copyright and software
#  license.  For more details on the Waggle project, visit:
#           http://www.wa8.gl
# ANL:waggle-license

apt-get install -y htop iotop iftop bwm-ng screen git python-dev python-pip python3-dev python3-pip tree psmisc dosfstools parted bash-completion fswebcam v4l-utils network-manager usbutils nano stress-ng

pip3 install -U pip

# python2 dependencies
pip install tabulate

# python3 dependencies
pip3 install tabulate
