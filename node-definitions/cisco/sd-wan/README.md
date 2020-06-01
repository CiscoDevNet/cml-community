# Cisco SD-WAN Node Definitions

This directory contains the following node definitions:

* `iosxe-sdwan.yaml` - Cisco cEdge CSR1000v node definition
* `viptela-bond.yaml` - Cisco vBond node definition
* `viptela-edge.yaml` - Cisco vEdge node definition
* `viptela-manage.yaml` - Cisco vManage node definition
* `viptela-smart.yaml` - Cisco vSmart node definition



### Image Availability

Images can be downloaded from https://software.cisco.com/download/home/286320995/type with a proper Cisco.com account and entitlement.



### Known Issues

While the `viptela-*` nodes support cloud-init day 0 configuration, the config extraction does not re-generate the cloud-init config.  Therefore, config extraction will not work correctly on the `viptela-*` nodes.