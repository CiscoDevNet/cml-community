# UCS Platform Emulator (UCSPE)

## Introduction

The UCS Platform Emulator is an all-in-one VM that provides a UCS Fabric Interconnect/UCS Manager experience.
It supports loadable firmware and compute operations.

The UCSPE releases are discussed in Cisco [community posts](https://community.cisco.com/t5/custom/page/page-id/customFilteredByMultiLabel?board=6011-docs-dc-ucs&labels=ucs%20platform%20emulator).

## Image Support

All UCSPE images should work in CML; however, KVM is not an officially supported hypervisor.  To use UCSPE,
download the respective OVA image from one of the version-specific community posts (the downloads require
login and are linked from the community).

Then, extract the vmdk file from the OVA with the `tar` command.  This is built-in on macOS and Linux, and
you can perform these same steps on WSL on Windows.

Example:

```bash
tar -xf UCSPE_4.2.2aS9.ova UCSPE_4.2.2aS9-disk1.vmdk
```

Next, convert the vmdk file to qcow2 format using the `qemu-img` tool (part of the `qemu` package).

Example:

```bash
qemu-img convert -c -f vmdk -O qcow2 UCSPE_4.2.2aS9-disk1.vmdk ucspe_4.2.2aS9s.qcow2
```

The `-c` argument is optional, but provides some compression, thus making for a smaller overall qcow2 file
size.

Once converted, upload the qcow2 file to CML and create a new image definition for the _UCSPE_ node.
