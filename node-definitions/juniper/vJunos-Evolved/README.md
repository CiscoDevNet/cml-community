# vJunos-Evolved

This directory contains the following node definition:
* `vjunos-evolved.yml` - vJunos-Evolved virtual router (virtualized PTX10001=36MR router running Junos OS Evolved)

## Image Availability

The image for the vJunos-Evolved router is available as a free download directly from HPE/Juniper's website. The link is included below:

https://support.juniper.net/support/downloads/?p=vjunos-evolved

## Notes

Tested with vJunos-Evolved running Junos OS Evolved 25.2R1.8-EVO. It may take a few minutes after the login prompt is initially available for all of the nested VMs (i.e., the forwarding plane) to start. Until everything is ready, you won't see any of the interfaces available in `show interfaces terse`.

You **MUST** be running a version of CML that supports EFI boot. (Tested on version 2.9.1). It is recommended that you run the image on a bare metal instance of CML (i.e., without nested virtualization). Otherwise, the image may fail to boot.

### VERY IMPORTANT!!! MUST READ!!!

The vJunos-Evolved **requires** EFI/UEFI boot to be enabled in order to properly start up. The node definition has the `efi_boot: true` option set. Additionally, CML comes with the correct OVMF EFI firmware files required to boot the vJunos-Evolved node using UEFI. However, by default, CML is not configured to use these firmware files when booting the node. As such, prior to booting the node, you must configure CML according to the following steps:

1. Ensure that the SSH service for the underlying Linux platform of the CML controller is enabled. This is **NOT** the same as the terminal server/SCP service available on the standard SSH port (tcp/22). The CML server should be listening for SSH requests on TCP port 1122
2. Use SSH to connect to the Linux CLI of the CML server
3. Run the following commands to define the appropriate EFI firmware files for the vJunos-Evolved node type in the CML configuration. The folder name is *VERY* important - it must match the ID of the node definition

```
cd /usr/share/edk2/ovmf
mkdir vjunos-evolved
cp OVMF-pure-efi.fd vjunos-evolved/efi_code.fd
cp win11/efi_vars.fd vjunos-evolved/efi_vars.fd
```
4. If you haven't already, import the node definition. Additionally, import the vJunos-Evolved qcow2 image downloaded from Juniper's website and create the associated image definition. You're good to start the node, at this point!