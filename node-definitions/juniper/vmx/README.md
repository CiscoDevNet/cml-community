# Juniper vMX Node Definitions

This directory contains the following node definitions:

* `jnpr-vmx-vcp.yaml` - Juniper vMX virtual control plane node definition
* `jnpr-vmx-vfp.yaml` - Juniper vMX virtual forwarding plane node definition



## Requirements

- CML 2.1.0 or higher
- Juniper vMX image distribution (tested with `vmx-bundle-17.3R3-S4.2.tar.zip`)
- The two node definitions above
- The image definition templates from https://github.com/CiscoDevNet/cml-community/tree/master/virl-base-images/juniper/vmx



## Steps

1. Extract the vMX image distribution `.tar.zip` file into a directory on your local machine.  From that archive, you will use the following files:
   - `junos-vmx-x86-64-VERSION`
   - `metadata-usb-re`
   - `vFPC-VERSION`
   - `vmxhdd`

2. Enable the OpenSSH sshd service in Cockpit on your CML server by going to Cockpit > Terminal and running the following command: `sudo systemctl enable sshd && sudo systemctl start sshd`

3. Download the `jnpr-vmx-vcp-17-3.yaml` and `jnpr-vmx-vfp-17-3.yaml` **image definitions** from the link above.

4. Edit these files to ensure that the versions found within are consistent with the version of vMX JunOS you have downloaded from Juniper.

5. In the Cockpit > Terminal, run the following command to shutdown the CML services: `sudo systemctl stop virl2.target`

6. Copy the two image definition files as well as the four disk images above to the CML server using Secure Copy (scp).  From macOS or Linux, this can be done with the following command: `scp -P1122 folder_with_disks_and_image_defs/* sysadmin@10.10.10.10:` where 10.10.10.10 is your CML server's IP address and `folder_with_disks_and_image_defs` is a directory that contains all of the above disk images and image definition YAML files.  Note the port number of 1122.  This is the port used by the OpenSSH daemon.  Also note the trailing ':'.

7. Back in Cockpit > Terminal, convert all of the disk images to qcow2 format using the following command: `qemu-img convert -cp -O diskname.oldformat diskname.qcow2`.  Here, `-c` provides compressed images and `-p` provides progress feedback while converting.

8. Create a directory for the image definitions with the following command: `sudo mkdir -p /var/local/virl2/refplat/diff/virl-base-images/junos-vmx-17-3`.  You can adjust the name of the directory to match your version of JunOS.

9. Copy all of the _converted_ disk images and the two image definition YAML files into this directory with the command: `sudo cp filename /var/local/virl2/refplat/diff/virl-base-images/junos-vmx-17-3/`.  Repeat this command to copy each file.  When done, the contents of  `/var/local/virl2/refplat/diff/virl-base-images/junos-vmx-17-3` should look like the following:

   - `jnpr-vmx-vcp-17-3.yaml`
   - `jnpr-vmx-vfp-17-3.yaml`
   - `junos-vmx-x86-64-17.3R3-S4.2.qcow2`
   - `metadata-usb-re.qcow2`
   - `vFPC-20181016.qcow2`
   - `vmxcdd.qcow2`

   **Note:** The version components may be different in your specific case.

10. Restart the CML services with the command: `sudo systemctl start virl2.target`
11. Go to Tools > Node and Image Definitions > Node Definitions and import the `jnpr-vmx-vcp.yaml` and `jnpr-vmx-vfp.yaml` files found in this repo directory.

If all has gone well, you can now start using the vMX nodes in your labs.  **Note:** when building labs with the vMX, you _must_ connect both node types (VCP and VFP) to each other, and the connection between the control and forwarding planes must be established on the second interface of both nodes.

At this point, you can disable the OpenSSH sshd on the CML server if you wish.  To do that, run the following command from Cockpit > Terminal: `sudo systemctl stop sshd && sudo systemctl disable sshd`.

## Enabling Config Extraction Support

The VCP node definition already have base support for configuration extraction, but you will need to go to the Node Definition editor within CML (under Tools > Node and Image Definitions > Node Definitions), select the VCP node definition, scroll down to the **pyATS** section, and fill in the Username and Password you will use for your vMX nodes.  After doing this, you can effectively use the CML configuration extraction feature on the VCP nodes.  The VFP node does not support nor does it need config extraction.



## Caveats

vMX support is considered **EXPERIMENTAL** within CML.