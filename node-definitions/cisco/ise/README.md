# Cisco Identity Services Engine (ISE) Node Definition

This directory contains a node definition for the Cisco Identity Services Engine (ISE).


**⚠️ The smallest ISE image is still large.  It is recommended to run ISE outside of CML and use external
connectivity to have it communicate with the virtual lab. ⚠️**

### Image Availability

If you have a support contract and general download access, you can find the image for ISE at
https://software.cisco.com/download/home/283801620/type/283802505/.  If not, ISE is provided as an eval
(see **Known Issues** below), and you can find the instructions for obtaining it in this
[blog](https://sendthepayload.com/getting-your-hands-on-identity-services-engine-and-installing-it/).
Note: you only need to follow the instructions to obtain the image.  Installing it into CML requires the
conversion an upload as described below.

There is no specific
QCOW2 for ISE, however.  You can convert the OVA's VMDK to QCOW2 using the `qemu-img` command:

```sh
qemu-img convert -f vmdk -O qcow2 ise.vmdk ise.qcow2
```

Or you can use libvirt's `virt-installer` to install the ISO to a QCOW2, and then copy that QCOW2 file to the CML server.

### Known Issues

Without a license, ISE provides a 90-day eval mode where all features are expected to work.  However, the resources
provided to the node are targeted to the small/eval deployment.  So large-scale management of devices and users will
not work without providing more CPUs and memory.
