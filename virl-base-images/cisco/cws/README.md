# Loading CWS Image Definitions

In order to start CWS nodes, you need to get a qcow2 image from the [Cisco Learning Network](https://learningnetwork.cisco.com/s/article/devnet-expert-equipment-and-software-list).  

An example image definition file is provided in this repository.  You cannot import image definitions, but you can use them as a guide.  Image
definitions are fairly trivial.  Specify a name, ID, link it to the node definition, and then specify the uploaded .qcow2 file.  After that,
the image will be available when you add the node from the lab pallet.
