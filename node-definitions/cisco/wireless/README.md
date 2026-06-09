# Cisco Wireless Node Definitions

This directory contains the following node definitions:

* `vwlc.yaml` - Cisco virtual wireless LAN controller (AireOS) node definition
* `cat9800.yaml` - Cisco Catalyst 9800 wireless LAN controller/switch (IOS-XE) node definition



### Image Availability

Images for the vWLC can be downloaded from https://software.cisco.com/download/home/284464214/type and images for the Catalyst 9800 can be downloaded from https://software.cisco.com/download/home/286322605/type.

### Known Issues

Catalyst 9800 images starting with 16.12 do not use the serial console by default.  Initially, the 9800-CL uses the VNC console. Even with the command `platform console serial` in the bootstrap configuration (which is included in this node definition), the first boot will only output the full data and accept CLI input on the VNC console. Once the 9800-CL has booted and saved its day-0 configuration, you can restart the node. On subsequent boots, the node will use the serial console.
