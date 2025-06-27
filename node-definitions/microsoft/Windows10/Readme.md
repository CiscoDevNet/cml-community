# Microsoft Windows 10

This directory contains the following node definition:

* `win10.yaml` - Microsoft Windows 10 node definition

### Image Availability

VHD images can be downloaded from microsoft on a trial basis here: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise Then the VHD image will have to be converted to a .qcow2 format. Linux `qemu-img` makes it easy. Documentation: https://docs.openstack.org/image-guide/convert-images.html

### Notes

This node definition uses 2 VCPUS and 6 GB RAM.
