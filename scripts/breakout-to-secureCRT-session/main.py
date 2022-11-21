import requests
import json
import os
import yaml
import sys
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
# print(allNodes) # -- for troubleshooting

port = 9000

## Changing to use Lab title vs Lab ID.
labInfo = cml.getLabInfo(auth, server, lab)
labName = labInfo.get("lab_title")

## Adding some code to determine if it is running on Mac OS.
## Not yet tested on Win OS.

crtPath = "VanDyke/SecureCRT/Config/Sessions"
if sys.platform == 'darwin':
    appPath = "/Users/{}/Library/Application Support/{}/CML-{}".format(user,crtPath,labName)
    pathMode = 0o777
else: 
    appPath = "C:/Users/{}/AppData/Roaming/{}/CML-{}".format(user,crtPath,labName)

if os.path.exists(appPath):
    print("directory already exists... continue...")
else:
    os.mkdir(appPath,pathMode)

# Create a Dict consisting of all (label:node_definition) from CML
nodeDict = {}

for n_id in allNodes:
    response = cml.getNodesByID(auth, server, lab, n_id)
    nodeDict.update({response.get("label"): response.get("node_definition")})

# Sort keys to match breakout tool.  Tool assigned ports based on label.

for node in sorted(nodeDict):
    # dont count devices that cannot be consoled into    
    if (nodeDict.get(node) == "external_connector" or
            nodeDict.get(node) == "unmanaged_switch"):
        print ("Found {}, skipping".format(nodeDict.get(node)))
    else:
        # get label
        node_label = node

        # turn port number into hex
        # strip "0x2233" and make it only 4 charators   
        hexport = hex(port).split('x')[-1]
        # node definition is also printed for troubleshooting
        print("creating: " + node_label + " Node Definition: " + nodeDict.get(node))
        # create a secureCRT Session
        with open("config.ini", "r") as config:
            temp = config.read()
            temp = temp.replace("REPLACE", "0000" + hexport)
            location = rf"{appPath}/{port}-{node_label}.ini"
            with open( location, "w") as config2write:
                config2write.write(temp)

        # if any custom nodes are added, and they dont add by 2 ports 
        # in the breakout tool add the node definition to the if 
        # statement below to only add by 1 port. 
        if (nodeDict.get(node) == "wan_emulator" or
                nodeDict.get(node) == "asav" or
                nodeDict.get(node) == "ftdv" or
                nodeDict.get(node) == "server" or
                nodeDict.get(node) == "alpine" or
                nodeDict.get(node) == "coreos" or
                nodeDict.get(node) == "desktop" or
                nodeDict.get(node) == "trex" or
                nodeDict.get(node) == "viptela-bond" or
                nodeDict.get(node) == "viptela-smart" or
                nodeDict.get(node) == "viptela-manage" or
                nodeDict.get(node) == "ubuntu"):
            # only add 1 to port number for the next device
            port = port + 1
        # else add 2 to port number for the next device
        else:
            port = port + 2

print("exiting...")


