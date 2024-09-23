This works for CML v2.7.2.

### 1. Get an image

VyOS free images are [nightly](https://vyos.net/get/nightly-builds/) builds, packaged as `.iso` files.

These require installation onto a virtual machine.

### 2. Prepare the VM

This install is Proxmox VE, but other hypervisors should work.

I used the GUI and attached the above `.iso` onto a cd-rom.

Settings used:

| Option | Value | 
| ---- | ---- | 
| Type | Linux |
| Version | 6.x - 2.6 Kernel | 
| Machine | Default (i440fx) |
| vCPU | 1 | 
| Memory |  1024 MB | 
| Hard Disk | 2GB Virtio Block |
| Network Device | Virtio |

### 3. Booting the VM

When it boots, the credentials are `vyos` / `vyos`

### 4. Installing the VM

To install VyOS to the hard disk, type:

`install image`

This is mostly defaults except the config file for boot is `/opt/vyatta/etc/config.boot.default`

<pre>
Would you like to continue? y
What would you like to name this image? ENTER
Please enter a password for the vyos user: vyos
Please enter a password for the vyos user: vyos
What console should be used by default? (K: KVM, S: Serial?) ENTER
Which one should be used for installation (Default :/dev/vda) ENTER
Would you like to use all the free space on the drive [Y/n] Y 
Which file would you like as boot config? (Default: 1) 2
</pre>

Power off the VM.

### 5. QCOW2

Proxmox puts hard disks into `/var/lib/vz/images/<vm-id>`

Get the VM ID if needed
```
root@proxmox-host:/var/lib/vz/images/103# qm list
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID       
       103 VyOS                 running    2048               2.00 265237 
```

Find the file
```
root@proxmox-host:/var/lib/vz/images/103# ls
vm-103-disk-0.qcow2
```

Copy to `/tmp`
```
root@proxmox-host:/var/lib/vz/images/103# cp vm-103-disk-0.qcow2 /tmp/
```

Compress the qcow2 ... this takes the file from 2GB to 500MB. This image has the name of the .ISO to distinguish the version
```
root@proxmox-host:/tmp# qemu-img convert -c -O qcow2 /tmp/vm-103-disk-0.qcow2 /tmp/vyos-1.5-vyos-1.5-rolling-202409200006.qcow2
```
