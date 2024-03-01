# CML-Breakout-SecureCRT-Windows
It will launch the breakout tool and have it generate a labs.yaml file that contains any running nodes.
It will discover your secureCRT configuration folder from the windows registry.
It then purges the '{secureCrtConfigFolder}\{sessions}\_CML' folder (if it exists)
It then parses the yaml file and generates secureCRT lab folder(s) and session files under a _CML folder in your secureCRT config\sessions folder.
It then launches the breakout tool.


Assumptions:
- using windows OS
- python 3.x is installed and pyYAML module is installed. (pip install pyyaml)
- secureCRT is installed and has its config location stored in the registry for the current user. 
- .bat file assumes all files are in c:\cml\ (adjust as needed)
- breakout-windows-amd64.exe is in the same folder as the rest of the files
- this creates sessions using ipv6 loopback. 
- the session name is the label in CML, not the CLI hostname.

Tested on: 
- CML: 2.6.1-11
- breakout-windows-amd64.exe 0.3.1-build-v2.6.1-11
- secureCRT 9.4.1

Setup:
- copy files to c:\cml folder
- in config.yaml edit the server name, username, and password. 
- ensure python 3.x is installed
- ensure pyYAML module is installed (pip install pyyaml)
- download the windows breakout tool to the c:\cml folder


to run the script:
- close secureCRT
- ensure any devices you want to access are running in cml
- run start-breakout-tool.bat
- open secureCRT, you will see a _CML folder with lab folder(s) containing sessions for any running devices in cml.

Example:
```
C:\cml>start-breakout.bat
get simplified node definitions from controller...
get active console keys from controller...
get active VNC keys from controller...
get all the labs from controller...
init with --enable-all flag, enabling all running labs...
get all the nodes for the labs from controller...
get nodes for lab Lab at Wed 11:43 AM from controller...
lab file written.
Successfully loaded YAML data from: labs.yaml
Generating SecureCRT session.ini files for each node:
- Z:\Work\VanDyke\Config\sessions\_CML/Lab at Wed 1143 AM/iosv-0_9000.ini
- Z:\Work\VanDyke\Config\sessions\_CML/Lab at Wed 1143 AM/iosvl2-0_9002.ini
File Generation Complete, Restart secureCRT if open already.
System version: 2.6.1+build.11
+------------+---------+----------+
| NODE LABEL | DEVICE  | ADDRESS  |
+------------+---------+----------+
| iosv-0     | serial0 | TCP/9000 |
+------------+         +----------+
| iosvl2-0   |         | TCP/9002 |
+------------+---------+----------+

Running... Press Ctrl-C to stop.
```

Enjoy.

