import requests
import json
requests.packages.urllib3.disable_warnings()


class CML:
    
    def auth(server, username, password):
        headers = {
            "accept": "application/json",
            "Content-Type": "application/json"
        }

        data = {"username":username,"password":password}
        a = '{"username":'
        b = f'"{username}","password":"{password}'
        c = '"}'
        data = a+b+c
        response = requests.post(f"https://{server}/api/v0/authenticate", headers=headers, data=data, verify=False)

        access_token = "Bearer " + json.loads(response.text)
        return(access_token)
    
    def getNodesByID(auth, server, lab, node_id):
        headers = {
        'accept': 'application/json',
        'Authorization': auth,
        }

        response = requests.get(f'https://{server}/api/v0/labs/{lab}/nodes/{node_id}?simplified=true', headers=headers, verify=False)
        
        node = json.loads(response.text)

        if response.status_code == 200:
            return(node)
        else:
            return("end of list")