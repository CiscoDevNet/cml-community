# Cisco Next-Gen Firewall Node Definitions

This directory contains the following node definition:

* `ftdv.yaml` - Cisco Firepower Threat Defense Virtual node definition
* `fmcv.yaml` - Cisco Firepower Management Center Virtual Application node definition


### Image Availability

Images for FTDv can be downloaded from https://software.cisco.com/download/home/286306503/type/286306337 with a proper Cisco.com account and entitlement.

Images for FMCv can be downloaded from https://software.cisco.com/download/home/286259687/type/286271056 with a proper Cisco.com account and entitlement.

### Notes

The FTDv image supports a day0 configuration that accepts the EULA, sets a hostname, and enables local management.  This config is editable, so you can choose to use Firepower Device Manager instead.

The FTDv image uses the default 4 vCPUs and 8 GB of RAM.  You may need to override that for larger deployments.

The FMCv images requires at least 4 vCPUs and 28 GB of RAM.  The installation guide recommends 32 GB of RAM.

The FTDv and FMCv default username / password in the provided day0 config are admin / Admin123.
