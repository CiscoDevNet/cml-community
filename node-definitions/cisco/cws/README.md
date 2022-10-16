# Cisco Certified DevNet Expert Candidate Workstation (CWS)

The CWS is the workstation on which one will test for the DevNet Expert lab.  This is an Ubuntu 20.04 image with development tools pre-installed.  It is intended to be a practice environment as one prepares to take the DevNet Expert lab exam.

This directory contains the following node definition:

* `cws.yaml` - Cisco Certified DevNet Expert Candidate Workstation

## Image Availability

Images for the CWS can be downloaded from the [Cisco Learning Network](https://learningnetwork.cisco.com/s/article/devnet-expert-equipment-and-software-list).  Be sure to download the qcow2 version.

## Notes

By default, the CWS uses 8 GB of memory and 4 vCPUs.  This can be tweaked.  It is known to run with 4 GB of memory.

The CWS image exposes both serial and graphical (i.e., VNC) consoles.  However, the typical way one accesses this is to connect it to Bridge external connectivity and use an RDP client.  That will provide the most exam-like experience.

The image is pre-configured to get an IP address via DHCP.  It does not support cloud-init day 0 configuration.

By default, only one interface is allocated, but the image supports adding up to three more.
