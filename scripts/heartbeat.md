<!--
waggle_topic=IGNORE
-->

# Operation

The heartbeat service continuously turns on and off a General Purpose IO (GPIO) pin on the C1+ or XU4 board.

# C1+ Dead Man Trigger

Turning the GPIO pin on is dependent on the modification time of the file
/usr/lib/waggle/core/alive being within 60 seconds of the current system
time. The modification time of the alive file is periodically updated by the
connectivity monitor service (https://github.com/waggle-sensor/nodecontroller/scripts/monitor-connectivity-service).
