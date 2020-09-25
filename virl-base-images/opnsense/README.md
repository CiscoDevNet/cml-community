# Creating the image file for CML

To get started with OPNsense, download the 'nano' image from https://opnsense.org/download/

Once you have the image archive, unarchive it, convert the image to qcow2, and then (optional) expand the image for extra headroom.

Here is an example of how I did it:

`bzip2 -d OPNsense-20.7-OpenSSL-nano-amd64.img`

`qemu-img convert -f raw -O qcow2 OPNsense-20.7-OpenSSL-nano-amd64.img OPNsense-20.7-OpenSSL-nano-amd64.qcow2`

`qemu-img resize OPNsense-20.7-OpenSSL-nano-amd64.qcow2 8G`

Default credentials are root:opnsense
