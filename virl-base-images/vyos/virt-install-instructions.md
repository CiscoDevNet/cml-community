**Works for CML v2.7.2**

These instructions use [libvirt's](https://libvirt.org/) `virt-install` to install the `.iso` file onto a KVM virtual machine hard disk to get a working `.qcow2` file.

This guide is for Debian.

The guide this is based on is [here.](https://docs.vyos.io/en/sagitta/installation/virtual/libvirt.html)

## 1. Install libvirt

Install libvirt and prereqs: QEMU, bridge-utils, etc.
```
sudo apt-get install -y wget qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager cpu-checker
```

Check if KVM is supported.
```
sudo kvm-ok
```

Example
<pre>
ariadne@tesseract:~$ sudo kvm-ok
INFO: /dev/kvm exists
KVM acceleration can be used
</pre>

The above **must** say, KVM acceleration can be used. 


## 2. Download the VyOS ISO

VyOS free images are [nightly](https://vyos.net/get/nightly-builds/) builds, packaged as `.iso` files.

Create a project folder
```
mkdir ~/working-with-vyos
```

Change to it
```
cd working-with-vyos
```

Use `wget` to download the `.iso`
```
wget <paste-in-the-iso-image-link>
```

Example
<pre>
ariadne@tesseract:~/working-with-vyos$ ls
vyos-1.5-rolling-202409230006-generic-amd64.iso
</pre>

## 3. Prepare a libvirt network

VyOS needs a network, this part of the guide uses a NAT network, named `br1`.

Networks in libvirt are defined in `.xml` files.

Use cat with redirection to make the br.xml file with these settings.
```
cat <<EOF > br1.xml
<network>
  <name>br1</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='br1' stp='on' delay='0'/>
  <ip address='192.168.10.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.10.10' end='192.168.10.100'/>
    </dhcp>
  </ip>
</network>
EOF
```

Define the network inside virsh
```
virsh net-define br1.xml
```

Start the network inside virsh
```
virsh net-start br1
```

Check to see if it's working
```
virsh net-list
```

Example
<pre>
root@tesseract:/home/ariadne/working-with-vyos# virsh net-list
 Name   State    Autostart   Persistent
-----------------------------------------
 br1    active   no          yes
</pre>

## 4. Prepare the VM

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

Attempt `virt-install` ... change the <vyos_download>.iso
```
sudo virt-install -n vyos_r1 \
--ram 1024 \
--vcpus 1 \
--cdrom ~/working-with-vyos/<vyos-download>.iso \
--os-type linux \
--os-variant debian10 \
--network network=br1 \
--graphics vnc \
--hvm \
--virt-type kvm \
--disk path=/var/lib/libvirt/images/vyos_r1.qcow2,bus=virtio,size=2 \
--noautoconsole
```

Example
<pre>
ariadne@tesseract:~/working-with-vyos$ sudo virt-install -n vyos_r2 \
> --ram 1024 \
> --vcpus 1 \
> --cdrom ~/working-with-vyos/vyos-1.5-rolling-202409230006-generic-amd64.iso \
> --os-type linux \
> --os-variant debian10 \
> --network network=br1 \
> --graphics vnc \
> --hvm \
> --virt-type kvm \
> --disk path=/var/lib/libvirt/images/vyos_r2.qcow2,bus=virtio,size=2 \
> --noautoconsole

Starting install...
Allocating 'vyos_r2.qcow2'

Domain is still running. Installation may be in progress.
You can reconnect to the console to complete the installation process.
</pre>

## 5. Connect to the VM

Use `virsh`
```
sudo virsh console vyos_r1
```

Press enter a few times

Credentials are `vyos` / `vyos`

Example
```
vyos login: vyos
Password: vyos
Welcome to VyOS!
```

## 6. Complete the VM install

Install VyOS to the hard disk
```
install image
```

See the below example to see what selections to pick for `install image`

Pick KVM with `config.boot.default`

Example
```
vyos@vyos:~$ install image
Welcome to VyOS installation!
This command will install VyOS to your permanent storage.
Would you like to continue? [y/N] y
What would you like to name this image? (Default: 1.5-rolling-202409230006) 
Please enter a password for the "vyos" user: 
Please confirm password for the "vyos" user: 
What console should be used by default? (K: KVM, S: Serial)? (Default: S) K
Probing disks
1 disk(s) found
The following disks were found:
Drive: /dev/vda (2.0 GB)
Which one should be used for installation? (Default: /dev/vda) 
Installation will delete all data on the drive. Continue? [y/N] Y
Searching for data from previous installations
No previous installation found
Would you like to use all the free space on the drive? [Y/n] Y
Creating partition table...
The following config files are available for boot:
        1: /opt/vyatta/etc/config/config.boot
        2: /opt/vyatta/etc/config.boot.default
Which file would you like as boot config? (Default: 1) 2
Creating temporary directories
Mounting new partitions
Creating a configuration file
Copying system image files
Installing GRUB configuration files
Installing GRUB to the drive
Cleaning up
Unmounting target filesystems
Removing temporary files
The image installed successfully; please reboot now.
```

Power off the VM.
```
sudo shutdown -h now
```

### 7. QCOW2

libvirt puts hard disks into `/var/lib/libvirt/images/`

Copy the hard disk image to /tmp
```
sudo cp /var/lib/libvirt/images/vyos_r1.qcow2 /tmp
```

Compress the qcow2 ... this takes the file from 2GB to 500MB. This image has the name of the .ISO to distinguish the version
```
sudo qemu-img convert -c -O qcow2 /tmp/vyos_r1.qcow2 /tmp/vyos-1.5-rolling-<version>.qcow2
```

Give it sane permissions
```
sudo chmod 644 /tmp/vyos-1.5-rolling-<version>.qcow2
```

This image can be added to CML via the web interface.
