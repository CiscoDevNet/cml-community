# CML-Breakout-SecureCRT-Session
performs API calls to CML and populates a secure-crt sessions for you to use with the breakout tool

Assumptions:
- secure-crt session database is in the default location. 
- using windows OS
- "populate all nodes" must be turned on in the breakout configuration. 
- This creates sessions using ipv4 loopback. 
- the device name in the database is the label in CML, not the CLI hostname. 

Tested on: 
- CML: 2.2.2+build52
- breakout-windows-x86_amd64.exe 0.2.1-build-v2.2.2-52
- secureCRT 9.0.2

Variables to edit:
on main.py edit server, username, password, and lab number. 

This python app will create a new folder and all the telnet sessions for the lab. 
Port numbers are listed in front of the devices name so you can quickly bounce it off the breakout tool if something doesnt seem right...

![alt text](https://github.com/M35a2/CML-Breakout-SecureCRT-Session/blob/main/Capture.PNG?raw=true)

easist way to update a lab after adding/deleting devices is to just delete the lab folder in secureCRT, rerun the script, and restart secureCRT

Known issues:
only tested on wan emulators, routers, switches... 
i haven't tested on anything that requires VNC or breakout might handle differently than adding by two port numbers. 