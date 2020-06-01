# F5 BIGIP Node Definitions

This directory contains a node definition for the F5 BIGIP Virtual Edition appliance.

### Description

This node definition provides for a BIGIP-VE node with four default ethernet interfaces and the ability to add up to
28.  The node requires 4 vCPUs and 4 GB of RAM.

This node does **not** provide a serial console.  It uses VNC instead (though it's serial over VNC).

### Known Limitations

You must use VNC to access this node's console.  Serial console does not work.

This node definition has been tested with v12 of the BIGIP software.  It is assumed to work with all later versions as
well.  While the day 0 config part is in the node definition, it is known **not** to work with v12.  It is believed
the cloud-init support will work with v13 and higher of the BIGIP software, but that has not been tested.
