# MikroTik Cloud Hosted Router Node Definitions

This directory contains a node definition for the MikroTik Cloud Hosted Router appliance.

### Image Availability

Images can be downloaded from https://mikrotik.com/download for **free**. You need to convert the downloaded img file to a qcow2 file. For example, on CentOS8, here's how it works.

```sh
dnf -y install qemu-img unzip
curl -O https://download.mikrotik.com/routeros/6.47/chr-6.47.img.zip
unzip chr-6.47.img.zip
qemu-img convert -O qcow2 chr-6.47.img chr-6.47.qcow2
```

### Description

This node definition provides for a MikroTik Cloud Hosted Router node with four default ethernet interfaces and the ability to add up to
16. The node requires 1 vCPUs and 64 MB of RAM.

This node provides a serial console.
