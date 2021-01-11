# Loading Cat8000v Image Definitions

In order to start Cat8000v nodes, you need to get a QCOW2 image from Cisco.com.  Cat8000v images can be downloaded from
https://software.cisco.com/download/home/286327102/type/282046477.

**NOTE:** When downloading the images, select the _-serial_ `.qcow2` file (e.g., `c8000v-universalk9_8G_serial.17.04.01a.qcow2`).  This
image supports a serial console.  If you download the image without the `-serial` in the name, it will expect a graphical console.  Also, do _not_ pick the EFI image.

An example image definition file is provided in this repository.  You cannot import image definitions, but you can use them as a guide.  Image
definitions are fiarly trivial.  Specify a name, ID, link it to the node definition, and then specify the uploaded .qcow2 file.  After that,
the image will be available when you add the node from the lab pallet.

