# Arista vEOS CML node definition 

This directory contains the following node definitions:

* vEOS.yaml - Arista vEOS node definition 

### Image 

A valid vEOS image can be downloaded the through Arista support portal. https://www.arista.com/en/support/software-download

### Notes

This node definition uses recommended values for vEOS instances. However, lowering the DRAM to 1.5GB should theoritically work but YMMV.

> [!IMPORTANT]
> For day0 configuration (`veos_usr.dat` file on ISO drive labeled `ARISTA_CONFIG_DRIVE`) to work, you must boot the QCOW2 image from Arista, allow it to install the full `vEOS-lab.swi` image, touch the file `/mnt/flash/kickstart-config`, then shut the system down.  This image will become your base QCOW2 image to load into CML.

* First boot the raw image:

```
...
Data in /mnt/flash/vEOS-lab.swi differs from previous boot image on /mnt/flash.
Saving new boot image to /mnt/flash...
...
localhost login: admin
localhost>en
localhost#bash

Arista Networks EOS shell

[admin@localhost ~]$ sudo cat /mnt/flash/.CloudInitLogs
Execute sudo mount /dev/disk/by-label/ARISTA_CONFIG_DRIVE /tmp/userdata8c9kqk8e
Output:
Erorr : b'mount: /tmp/userdata8c9kqk8e: WARNING: source write-protected, mounted read-only.\n'
Caught exception [Errno 2] No such file or directory: '/mnt/flash/kickstart-config'. Ignoring KVM CloudInit
Execute sudo umount /tmp/userdata8c9kqk8e
Output:
Erorr : b''
CloudInit done !

[admin@localhost ~]$ sudo touch /mnt/flash/kickstart-config
[admin@localhost ~]$ sudo shutdown -h now
```

* [Collapse/Flatten](https://blog.programster.org/qemu-img-cheatsheet#collapse-all-images) image as normal and copy to a new image definition.

