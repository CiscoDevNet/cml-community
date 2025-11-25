# this is a shell script which will be sourced at boot

# OS Level Configuration
hostname netbox-server

# Network Config: eth0
# Optional: Configure static IP address if DHCP not being used
# ip link set up dev eth0
# ip addr add 192.168.0.11/24 dev eth0
# ip route add default via 192.168.0.1
# Configure DNS servers
# echo "nameserver 192.168.0.1" > /etc/resolv.conf

# Optional: Create an additional OS user account
# Note: The user cisco/cisco is already created
# USERNAME=anotheruser
# PASSWORD=cisco

# Network Config: eth1
# Optional: Configure IP address on 2nd interface to
#           allow access to the CML controller. This
#           is required to sync the CML topology to NetBox
#           if the primary interface doesn't have a path
#           to the CML controller.
# Note: The default CML firewall configuration for the 
#       NAT ext-conn does NOT allow CML API access. 
#       Either add https to the firewall rule in Cockpit
#       or use a bridge external connector
# ip link set up dev eth1
# ip addr add 192.0.2.2/24 dev eth1

# Optional: Settings to Auto Populate NetBox from CML Topology
# By setting the following ENVs the cml2netbox/topology-2-netbox
# script will run to attempt to populate NetBox
# Notes:
#   * These variables all relate to the CML controller/server
#   * The netbox-server must be connected to an ext-conn to reach 
#     the CML API. 
#   * A bridge ext-conn will work with the default CML network config
#   * A NAT ext-conn requires HTTPs being enabled on the virbr0 firewall
#     zone from within Cockpit
#   * The example value below uses the standard NAT ext-conn address.
#     Update it for your environment if you're using a bridge ext-conn

# export VIRL2_URL=https://192.168.255.1
# export VIRL2_USER=admin
# export VIRL2_PASS=1234QWer
# export VIRL2_VERIFY_SSL=False
# export LAB_NAME="My CML Lab"
# Note: Lab_ID only needs to be set if multiple Labs with same
#       Name exist on the CML server
# export LAB_ID=****

# These two scripts will:
# 1. Check if NetBox is healthy
# 2. Check if CML is reachable, and if so...
# 3. Run the script to sync the CML topology to Netbox
/home/cisco/check_netbox.sh >> /home/cisco/startup_log.txt 2>> /home/cisco/startup_err.txt
/home/cisco/check_and_sync_cml.sh >> /home/cisco/startup_log.txt 2>> /home/cisco/startup_err.txt