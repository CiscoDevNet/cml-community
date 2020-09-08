# Cisco Next-Gen Firewall Node Definitions

This directory contains the following node definition:

* `ftdv.yaml` - Cisco Firepower Threat Defense Virtual node definition


### Image Availability

Images can be downloaded from https://software.cisco.com/download/home/286306503/type/286306337 with a proper Cisco.com account and entitlement.

### Notes

The FTDv image supports a day0 configuration that accepts the EULA, sets a hostname, and enables local management.  This config is editable, so you can choose to use Firepower Device Manager instead.

The FTDv image uses the default 4 vCPUs and 8 GB of RAM.  You may need to override that for larger deployments.

The FTDv default username / password in the provide day0 config are admin / Admin123.
