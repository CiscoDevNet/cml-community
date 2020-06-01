# Contributing to CML Community 
Have you built a cool topology, or worked out how to add a 3rd party device to CML and ready to share it?  Well this is the place to come.  We want to make the contribution process easy, so checkout the following. 

## Lab Topologies 
In your Pull Request for a new lab topology, please check that you have followed all of the these suggestions. 

- [] Create a new folder for your topology under [`lab-topologies`](lab-topologies)
- [] Include a README.md file that describes your topology. The README should make note of any required additional nodes that are NOT included with CML by default.  And if there are any unique topology setup details that are needed to use the topology list them out as well. 
- [] Add your topology file to the folder. 
- [] Update the main [`README.md`](README.md) file with your name in the Authors list!

## Node Definitions and Base Images 
In your Pull Request for a new node, please check that you have followed all these suggestions. 

- [] Add your node-definition.yaml file to the [`node-definitions`](node-definitions) folder. The node-definition file should describe the platform and device type, but **NOT** the software version.
- [] Create a new folder within [`virl-base-images`](virl-base-images) folder for the disk-image definition file. The folder name should include the platform, device-type, **AND** the software version. 
- [] Within the base-image folder, add you create your image-definition.yaml file. The name of the file can match the folder name. 
- [] Do **NOT** include the actual disk-image for the node. 
- [] Update the main [`README.md`](README.md) file with your name in the Authors list!
