import requests
import json
import os
requests.packages.urllib3.disable_warnings()
from cmlApiCalls import CML as cml

#edit the following variables
server = "cml.server.com"
username = "admin"
password = "CMLpassword123"
lab = "53b3fe"


user = os.getlogin()
auth = cml.auth(server, username, password)

N = True
n_id = 0
port = 9000
try:
    os.mkdir(rf"C:/Users/{user}/AppData/Roaming/VanDyke/Config/Sessions/CML-{lab}")
except:
    print("directory already exists... continue...")

    
while N:
    node_id = f"n{n_id}"
    response = cml.getNodesByID(auth, server, lab, node_id)
    
    if response == "end of list":
        #exit if end of list
        N = False

    elif response.get("node_definition") == "external_connector":
        # dont count external_connector as usable
        n_id = n_id + 1    
        
    else:
        # get label
        node_label = response.get("label")
        
        # turn port number into hex
        # strip "0x2233" and make it only 4 charators   
        hexport = hex(port).split('x')[-1]
        
        with open("config.ini", "r") as config:
            temp = config.read()
            temp = temp.replace("REPLACE", "0000" + hexport)
            location = rf"C:/Users/{user}/AppData/Roaming/VanDyke/Config/Sessions/CML-{lab}/{port}-{node_label}.ini"
            with open( location, "w") as config2write:
                config2write.write(temp)
        
        if response.get("node_definition") == "wan_emulator":
            # add by 1 if wan_emulator
            port = port + 1
        else:
            port = port + 2
        n_id = n_id + 1
        
            


