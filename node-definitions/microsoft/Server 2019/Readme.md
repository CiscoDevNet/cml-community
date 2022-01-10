# Microsoft Server 2019

This directory contains the following node definition:

* `winServer2019.yaml` - Microsoft Windows Server 2019 node definition

### Image Availability

VHD images can be downloaded from microsoft on a trial basis here: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019
Then the VHD image will have to be converted to a .qcow2 format. Linux qumu-img makes it easy. Documentation: https://docs.openstack.org/image-guide/convert-images.html   

### Notes

This node definition uses 16g of RAM and 4vcpu's. Anything less than that and it tends to become buggy. 
