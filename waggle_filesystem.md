<!--
waggle_topic=/node_controller,Waggle Filesystem
waggle_topic=/edge_processor,Waggle Filesystem
-->

# Waggle Filesystem

Waggle runs on Linux-based systems. In order to secure Waggle and OS critical components and prevent any file corruption on those components, the components are stored in a read-only partition. This read-only partition becomes writable only when Waggle software upgrade occurs. The upgrade process is responsible for putting the partition back to read-only mode after the process is finished successfully. There are 3 partitions in a Waggle system.

## Boot Partition

U-boot partition, usually is about 120 MB in its size.

## Read-only Partition

System partition that mounts `/`. The size of the partition is about 8 GB (half of the storage that Waggle nodes use). This partition includes all system files as well as Waggle service codes, configurations, and security files.

## Writable Partition

This writable partition takes the remaining storage capability (e.g., 8 GB out of 16 GB storage). The partition is mounted under `/wagglerw`. `/var` and `/srv` are linked to this partition (under `/wagglerw`) as those directories should remain writable by OS and software. Waggle plugin software codes, their configuration files, raw-to-intermediate data, used by Waggle services and plugins, etc are stored in this partition.

## Instructions on Making The Read-only Partition in Waggle

Pseudocode of the instructions is described below. The actual code block can be found in [waggle_init.sh](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L344) (Line 344 through 503).

1) [Make 3 partitions](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L347)
2) [Make bootloader](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L353)
3) [Copy boot partition files from host](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L379)
4) [Copy read-only partition files from host](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L401)
5) [Copy writable partition files from host](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L409)
6) [Configure `/wagglerw` and links](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L431)
7) [Modify boot.ini](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L474)
8) [Apply read-only to fstab](https://github.com/waggle-sensor/core/blob/master/scripts/waggle_init.sh#L491)
