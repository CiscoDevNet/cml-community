# Palo Alto Networks vFW image

This directory contains the node definition for PAN-OS 10


### General Information

default username and password are admin/admin
mgmt interface defaults to dhcp

Once the image has booted, after you see the following msg on the console "Masterd started successfully", you can logon with
the default credentials and change the credentials after first logon.
 
        PA-HDF login: admin
        Password: 
        System initializing; please wait... (CTRL-C to bypass)
        Enter old password : 

To set a static ip address issue the following commands :

        configure
        set deviceconfig system type static
        set deviceconfig system ip-address <Firewall-IP> netmask <netmask> default-gateway <gateway-IP> dns-setting servers primary <DNS-IP>
        commit




