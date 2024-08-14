# Microsoft Server 2022

This directory contains the following node definition:

* `win2022.yaml` - Microsoft Windows Server 2022 node definition

### Image Availability

VHD images can be downloaded from microsoft on a trial basis here: https://info.microsoft.com/ww-landing-windows-server-2022.html
Then the VHD image will have to be converted to a .qcow2 format. Linux qumu-img makes it easy. Documentation: https://docs.openstack.org/image-guide/convert-images.html

For example:

```sh
qemu-img convert -f vpc -O qcow2 \
  20348.169.amd64fre.fe_release_svc_refresh.210806-2348_server_serverdatacentereval_en-us.vhd \
  20348.169.amd64fre.fe_release_svc_refresh.210806-2348_server_serverdatacentereval_en-us.qcow2
```

### Notes

This node definition uses 16g of RAM and 4vcpu's. Anything less than that and it tends to become buggy.
