<!--
waggle_topic=/node_controller,Waggle Core Software
waggle_topic=/edge_processor,Waggle Core Software
-->

# Node Stack - Core Repo

This repo contains software and tools common to both the node controller and edge processor, covering functionality such as:

* Managing deployment state.
* Controlling plugins.
* Heartbeating
* Media recovery.

## Setup

Dependencies and services are installed and configured by running:

```sh
git clone https://github.com/waggle-sensor/core /usr/lib/waggle/core
cd /usr/lib/waggle/core
./configure
```
