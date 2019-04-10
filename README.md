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
mkdir -p /usr/lib/waggle
cd /usr/lib/waggle
git clone https://github.com/waggle-sensor/core
cd core
./configure
```
