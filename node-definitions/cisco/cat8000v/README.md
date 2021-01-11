# Cisco Catalyst 8000V Edge Software

This directory contains the following node definition:

* `cat8000v.yaml` - Cisco Catalyst 8000V Edge Software node definition

### Image Availability

Images for the Cat8000v can be downloaded from https://software.cisco.com/download/home/286327102/type/282046477 with a proper Cisco.com account and entitlement.

### Notes

The Cat8000v comes in 8 GB and 16 GB flavors.  However, this node definition uses 1 vCPU and 4 GB of RAM.  That should
be fine for basic testing.  However, you can override the CPU and memory on a per-image definition and per-node level
if need be.

When downloading new images from Cisco.com, be sure to get images have `-serial` in the name and are **not** EFI images.
