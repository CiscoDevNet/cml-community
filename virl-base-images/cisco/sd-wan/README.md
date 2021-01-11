# Loading SD-WAN Image Definitions

To get the Viptela (v\*) QCOW2 images, start at https://software.cisco.com/download/home/286320995/type to find the image you need.  To get the
IOS-XE SD-WAN router image, go to https://software.cisco.com/download/home/286323714/type.  Note that you must be entitled contract-wise to
access these URLs and download the images.

**NOTE:** When downloading the IOS-XE router image, select the _-serial_ `.qcow2` file (e.g., `csr1000v-universalk9.17.03.02-serial.qcow2`).  This
image supports a serial console.  If you download the image without the `-serial` in the name, it will expect a graphical console.  Also, if given
a choice, do _not_ pick the EFI image.

Example image definition files are provided in this repository.  You cannot import image definitions, but you can use them as a guide.  Image
definitions are fiarly trivial.  Specify a name, ID, link it to the node definition, and then specify the uploaded .qcow2 file.  After that,
the image will be available when you add the node from the lab pallet.

