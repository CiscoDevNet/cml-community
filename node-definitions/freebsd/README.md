# FreeBSD in CML

Instructions for running a basic FreeBSD node in Cisco Modeling Lab.

# Deployable image

A pre-built FreeBSD image is available
[here](https://download.freebsd.org/snapshots/VM-IMAGES/14.1-STABLE/amd64/Latest/FreeBSD-14.1-STABLE-amd64-BASIC-CLOUDINIT.ufs.qcow2.xz).

In Linux the above image can be decomressed with:

    xz --decompress FreeBSD-14.1-STABLE-amd64-BASIC-CLOUDINIT.ufs.qcow2.xz

From there the qcow2 file can be imported into CML.

By default the FreeBSD image is configured to use DHCP.  It also supports a
native serial console which is ideal for CML.

# FreeBSD node definition

A FreeBSD [node definition](FreeBSD.yaml) is include in this directory.

# Limitations and future work

The FreeBSD 14.1 "Basic Cloud-init" image comes with "nuage-init" rather than
"cloud-init".  Nuage-init does not support all options that are available in
cloud-init.  A base configuration is provided in this
[node definition](FreeBSD.yaml).

If the CML node has Internet connectivity it is possible to use the package
manager to install cloud-init.  This will allow you to use cloud-init on
subsequent boots.  This approach may have limited utility if you are using
Terraform to provision the CML node.

## Nuage-init: MAC address required

If you are attempting to use Nuage-init in order to set an IP address please
have a look at the [source code](https://github.com/freebsd/freebsd-src/blob/f35ccf46c7c6cb7d26994ec5dc5926ea53be0116/libexec/nuageinit/nuageinit#L283-L293).

Nuage-init will explicitly check to see that there is an ```ethernets```
section with a ```match``` subsection.  The only working match clause is the
```macaddress``` clause.  If you do not explicitly state the MAC address of
your NIC it will not be able to set an IP address.  Both DHCP and IPv6 are
supported.

The following ```user-data``` example will set the IP address of the NIC with
the specified MAC address to 192.0.2.10/24.

```yaml
network:
  version: 2
  ethernets:
    id0:
      match:
        macaddress: 'aa:bb:cc:00:11:22'
      addresses:
        - 192.0.2.10/24
```
