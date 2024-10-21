# OpenBSD-CML

Instructions for building an OpenBSD node in Cisco Modeling Lab

## Why OpenBSD in CML?

OpenBSD is standards-compliant, has good documentation, and is secure.

OpenBSD can act as a router, a routed layer 3 firewall, a NAT boundary, a
bridging Layer-3 firewall, an end host, a webserver, a load balancer, and many
other roles not mentioned here.

# Create a qcow2 OpenBSD VM

## Create the VM

Resources required for initially building the VM can differ from the resources
required for running an instance of that VM in CML.

As resources in CML are generally scarce I suggest starting with a fairly
minimal configuration while building the VM.  Although it's generally possible
to increase the resources at runtime it's hard to decrease them.

* RAM: 1GB
* Disk: 8GB
* CPU: 1
* Network: single interface with Internet access (used to install patches and
  upgrades)

When running an instance of this VM in CML it is possible (and even likely)
that you will add aditional network interfaces or increase the RAM or Disk
space.  RAM, Disk, and Network are all easily increased in your CML config.

During the install process OpenBSD will either install a single-CPU kernel or a
multi-CPU kernel.  If you want to use a multi-CPU kernel you will need to
create the VM with more than one CPU.  It is possible to change the kernel
after the fact but it's easier to just create the VM with more than one
CPU.  As this is a destined for a lab environment I suggest creating the VM
with only one CPU.

Although I used VMWare to build this image it should be mostly the same to use
other platforms (VirtualBox, QEMU, KVM, etc).

## Install OpenBSD

I used the amd64
[install76.iso](https://cdn.openbsd.org/pub/OpenBSD/7.6/amd64/install76.iso)
image to perform a base install.  I did not install games nor any of the x11
packages (just to save space).

I used ```cisco``` for the root password.  I disabled root SSH logins out of
habit.

### Partitioning

Although auto partitioning is sufficient for this, I created a single
partition in order to both use the entire disk and to avoid the need to create
a swap partition.

### Users

I created a second user named ```cisco``` with the same password.

## First boot

Once the base system is installed reboot and log in as root.

Right away you should check for updates:

    syspatch
    pkg_add -u

### Install additional packages

This is an exellent opportunity to install some of the packages that are
useful for network operations.  Of course, it may be possible to install
these packages later if your labs have Internet connectivity.

If you intend to use ```cloud-init``` you will need to install git:

    pkg_add git

#### Install now

The benefit of installing packages now is that they will be available
for use immediately on all instances of the node.  The downsiide is that
it will occupy more space on the image.

These packages have been extremely useful through the years:

    pkg_add mtr-- wget gnuwatch nmap wireguard-tools

Please note the ```--``` in ```mtr--```.  If ```mtr``` is specified without
the ```--``` the ```pkg_add``` command will ask the user which version is
desired; normal MTR or MTR with GTK support.  By using the ```--``` suffix the
non-GTK version is installed.

#### Install later

If there is Internet connectivity for the instance at runtime it is also
possible to install these packages later.  This will save space on the image.

To install at runtime, become root on the instance and run the following
command:

    pkg_add mtr-- wget gnuwatch nmap wireguard-tools

Alternatively, if you are using ```cloud-init``` you can include a
```packages``` section in your ```user-data``` file.  For example:

```yaml
#cloud-config
packages:
  - mtr--
  - wget
  - gnuwatch
  - nmap
  - wireguard-tools
```

### Add username and password hints

If some other admin tries to use your newly minted node it would be nice if
they can easily see what username and password to use.  This will appear on
the serial console.

Update the ```/etc/gettytab``` file.  Replace the existing default section with
this:

    default:\
            :np:im=\r\n%s/%m (%h) (%t)\r\n\
    ************************\r\n\
    * Console login        *\r\n\
    * username = root      *\r\n\
    * password = cisco     *\r\n\
    *                      *\r\n\
    * General login (SSH)  *\r\n\
    * username = cisco     *\r\n\
    * password = cisco     *\r\n\
    ************************\r\n\
    \r\n:sp#1200:

### Enable IP forwarding

Enable IP forwarding.  By default this is turned off.  This isn't strictly
required for an end host nor webserver; but it's a step easily missed.

    echo "net.inet.ip.forwarding=1" > /etc/sysctl.conf

### cloud-init

```cloud-init``` is a tool that allows you to configure a VM on first boot.
This allows you to configure a VM without having to use the VM's console.

#### Install cloud-init

There is no pre-built ```cloud-init``` package for OpenBSD.  However, it's not
difficult to install it from source:

    git clone https://github.com/canonical/cloud-init.git
    cd cloud-init
    ./tools/build-on-openbsd

If it was successful you should see several ```cloud-init``` commands
in ```/etc/rc.local```.  These commands will be run on boot.

#### Configure cloud-init

By it's very nature ```cloud-init``` is typically used with a cloud provider
with access to the Internet.  As the intent here is to build a VM that will run
inside a CML environment is is necessary to configure ```cloud-init``` to look
for a local data source.

Edit ```/etc/cloud/cloud.cfg``` and add the following:

    datasource_list: ["NoCloud"]
    datasource:
      NoCloud:
        fs_label: cidata

The configuration above will look for a mounted CDROM with a label of
```cidata``` during the boot process.  The following files will be read (if
present):

* ```meta-data```
* ```user-data```
* ```network-config```
* ```vendor-data```

The files above are optional.  Please note that they do not have a file
extension (there is no ```.yml``` extension).

#### Configure the boot process

By default ```cloud-init``` will populate the ```/etc/rc.local``` file.  The
```ds-identify``` command will be run by default but is not required since
the datasource is already configured.  I recommend commenting out this line
in order to speed up the boot process.

### Enable logins on serial console

Enable serial console to provide a login prompt
Edit ```/etc/ttys``` so that ```tty00``` reads as:

    tty00   "/usr/libexec/getty std.9600"   vt220   on  secure

This file uses a combination of tabs and spaces.  It will work fine if you only
use spaces.  Copying and pasting from this README will work fine.

NB: you can output to a serial console without being able to login on it.  This
step enables that login.

## Snapshot

Now is a good time to create a snapshot of your VM. This point in the install
it's still fairly easy to install future patches and additional software.

## Finalize the image

These commands will enable output to the serial console needed for CML and
cleanup the original network interface.  It's hard to undo these (but not
impossible).

    # remove the network interface config that was created by the installer:
    rm /etc/hostname.em0
    # remove the SSH host keys that were generated during the boot:
    rm /etc/ssh/ssh_host_*
    # remove the configuration files that cloud-init created:
    rm -r /var/lib/cloud
    rm -r /var/run/cloud-init
    # redirect the default console to the serial console:
    echo "set tty com0" > /etc/boot.conf
    # shutdown and power off the VM:
    shutdown -p now

## Create a clone of the VM

This is the last step before exporting your image to a qcow2 file.

If you attempt to convert the VMWare image to a qcow2 image from the
snapshotted VMDKs above you will end up with a non-bootable image.  I do not
understand why.  I suspect it is due to how qemu-img handles snapshots.  For
best success I recommend you clone your VM to get a flattened VMDK image.  I
had success with ```Clone to Template...``` in VMWare.

## Convert VM to qcow2

This step is not required if you already have a qcow2 image.  VMWare provides
a series of VMDK files which need to be converted.

Copy all of the VMDK files from your image to someplace where you can run the
```qemu-img``` tool (available in Linux).

    qemu-img convert -f vmdk -O qcow2 <base filename.vmdk> <target qcow2 filename>

If you receive an error you may be specifying the wrong base VMDK file.  Look
for the smallest VMDK file and use it.

Now you can export your qcow2 image for use in CML.

## OpenBSD node definition

An OpenBSD [node definition](OpenBSD.yaml) is include in this directory.
