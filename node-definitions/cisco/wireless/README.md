# Cisco Wireless Node Definitions

This directory contains the following node definitions:

* `vwlc.yaml` - Cisco virtual wireless LAN controller (AireOS) node definition
* `cat9800.yaml` - Cisco Catalyst 9800 wireless LAN controller/switch (IOS-XE) node definition



### Image Availability

Images for the vWLC can be downloaded from https://software.cisco.com/download/home/284464214/type and images for the Catalyst 9800 can be downloaded from https://software.cisco.com/download/home/286322605/type.

### Known Issues

Catalyst 9800 images starting with 16.12 do not use the serial console.  While some output will appear on the serial console, the boot process will appear to hang.  However, the nide does continue to boot and respond on the VGA console.  Therefore, use the "VNC" tab within Cisco Modeling Labs to access the console of these devices.
