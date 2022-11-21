# NXOSv 9500 with 128 ports
This directory contains the following node definition:

*`nxosv9500-148.yaml` - Nexus 9500v with 128 ports node definition
### Image Availability
Images for the NXOSv 9500 can be downloaded from https://software.cisco.com/download/home/286312239/type/282088129/release/9.3(8) with a proper Cisco.com account and entitlement.

### Notes
NXOSv 9300 is the default image in CML, it has 64 ports. 
NXOSv 9500 allows inserting additional line cards there by increasing the number of ports. 
This node definition has boot strap configs to insert line cards in the following order. 

Module 1 Nexus 9500v 64 port Ethernet1/1 - Ethernet1/64 (Default)
    Module 2 Nexus 9500v 16 port Ethernet2/1 - Ethernet2/16
    Module 3 Nexus 9500v 32 port Ethernet3/1 - Ethernet3/32
    Module 4 Nexus 9500v 36 port Ethernet4/1 - Ethernet4/36
    
NXOSv 9500 needs 4 CPUs and 16 GB RAM
