import requests
import json
import os
import yaml
requests.packages.urllib3.disable_warnings()
from cmlApiCalls import CML as cml

# get login information from login.yaml
with open("login.yaml") as f:
    login = yaml.safe_load(f.read())

# set variable from yaml file
server = login["cmlServer"]
lab = login["lab"]
username = login["username"]
password = login["password"]

# get username for secureCRT directory
user = os.getlogin()

# get authentication token from CML (funtion in cmlApiCalls.py)
auth = cml.auth(server, username, password)

# get all nodes from the cml server (funtion in cmlApiCalls.py)
allNodes = cml.getAllNodes(auth, server, lab)
# print(allNodes) -- for troubleshooting
N = True
n_id = 0
port = 9000
try:
    os.mkdir(rf"C:/Users/{user}/AppData/Roaming/VanDyke/Config/Sessions/CML-{lab}")
except:
    print("directory already exists... continue...")

    
while n_id < 100:
    node_id = f"n{n_id}"
    response = cml.getNodesByID(auth, server, lab, node_id)
    # print(response) -- for troubleshooting
    # if node does not exists, check the next node
    if response == "end of list":
        print("Node " + node_id + " does not exist, will check all nodes from n0 to n99.")
        # increment node number
        n_id = n_id + 1

    # dont count devices that cannot be consoled into    
    elif (response.get("node_definition") == "external_connector" or
            response.get("node_definition") == "unmanaged_switch"):
        # increment node number
        n_id = n_id + 1    
        
    else:
        # get label
        node_label = response.get("label")
        
        # turn port number into hex
        # strip "0x2233" and make it only 4 charators   
        hexport = hex(port).split('x')[-1]
        # node definition is also printed for troubleshooting
        print("creating: " + node_label + " Node Definition: " + response.get("node_definition"))
        # create a secureCRT Session
        with open("config.ini", "r") as config:
            temp = config.read()
            temp = temp.replace("REPLACE", "0000" + hexport)
            location = rf"C:/Users/{user}/AppData/Roaming/VanDyke/Config/Sessions/CML-{lab}/{port}-{node_label}.ini"
            with open( location, "w") as config2write:
                config2write.write(temp)
        
        # if any custom nodes are added, and they dont add by 2 ports in the breakout tool
        # add the node definition to the if statement below to only add by 1 port. 
        if (response.get("node_definition") == "wan_emulator" or 
                response.get("node_definition") == "asav" or 
                response.get("node_definition") == "ftdv" or
                response.get("node_definition") == "server" or
                response.get("node_definition") == "alpine" or
                response.get("node_definition") == "coreos" or
                response.get("node_definition") == "desktop" or
                response.get("node_definition") == "ubuntu"):
            # only add 1 to port number for the next device
            port = port + 1
        # else add 2 to port number for the next device
        else:
            port = port + 2
        # increment node number    
        n_id = n_id + 1
# 
print("Nodes 0-99 checked. if you need more, increase the number checked in the while loop")
print("example change to: while n_id < 150:")
print("exiting...")        
            


