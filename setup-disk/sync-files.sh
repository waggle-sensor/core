#!/bin/bash 

set -e

MOUNT1=$(mktemp -d)
MOUNT2=$(mktemp -d)

set -x

mount $1 $MOUNT1
mount $2 $MOUNT2

# Copy files from mount1 to mount2, preserving flags and metadata.
rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} $MOUNT1/* $MOUNT2

umount $MOUNT1
umount $MOUNT2

rmdir $MOUNT1
rmdir $MOUNT2
