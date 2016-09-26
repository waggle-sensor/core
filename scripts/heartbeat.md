# Operation

The heartbeat service continuously turns on and off a General Purpose IO (GPIO) pin on the C1+ or XU4 board.

# C1+ Dead Man Trigger

Turning the GPIO pin on is dependent on the modification time of the file
/usr/lib/waggle/waggle_image/alive being within 60 seconds of the current system
time. The modification time of the alive file is periodically updated by the
wellness service. See the documentation on the wellness service
(https://github.com/waggle-sensor/nodecontroller/tree/NC_wellness/scripts/wellness-service.md)
for details on what conditions cause the alive file modification time to not be updated.
