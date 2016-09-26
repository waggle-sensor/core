#!/bin/bash

set -e
set -x

# Install MBR.
parted --script $1 mklabel msdos

# Create boot partition.
parted --script $1 mkpart primary fat16 3072s 266239s
parted --script $1 set 1 lba off

# Create root partition.
parted --script $1 mkpart primary ext4 266240s 100%

# Create boot filesystem.
mkdosfs -F 16 "$1p1"

# Create root filesystem.
mkfs.ext4 "$1p2"

# NOTE We should think carefully about the fragility of this. It's possible
# that partition naming conventions may change unexpectedly.
#
# NOTE This scheme is specific to the C1+. Other will have slightly altered
# start / end regions.
#
# NOTE This also requires manual intervention right now. parted will ask you
# a few questions about destroying the MBR and about an alignment issue.
