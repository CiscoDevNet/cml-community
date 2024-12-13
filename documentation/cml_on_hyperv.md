# CML on Hyper-V
This installs CML on Hyper-V for Windows. You will need a version of windows that supports and provides Hyper-V as a feature. Editions other than Pro and Enterprise likely do not include this feature. Server 2016 and later should include Hyper-V, although the process below may change slightly if you are running this on a server instance.

This was tested on Windows 11 Enterprise, but should work for other editions of windows that meet the requirements.

## Requirements
- Windows 10 Pro/Enterprise or later, Server 2016 or later
- Hyper-V windows feature activated

## Setup
### Enable Hyper-V
- Windows Settings: "Turn Windows features on or off"
- Enable all Hyper-V options
- Reboot when asked

### Create Hyper-V Bridged Network
This is done to expose the VM to your local network. If you only plan on accessing the CML instances from your local machine only, you can skip this step.
- Launch the Hyper-V GUI
- Click the "Virtual Switch Manager"
- Create a new "External" virtual switch
- Pick a network card connected to your local network
- Confirm and save

### Create Hyper-V Virtual Machine
Before proceeding with the following steps, make sure to download the latest CML ISO for bare metal installation.

#### Initial Creation
- Create a new virtual machine
- Use a name without spaces to avoid quoting/escaping issues
- Select _Generation 2_ for the generation type
- Assign sufficient memory to meet requirements
- Do not use dynamic memory (this can impact performance on the nested nodes as page swapping may occur)
- Connect the network adapter to either the external network (created above), or the Hyper-V virtual switch
- Assign sufficient disk to meet requirements
- Choose to install an operating system later
- _Finish_ to create the VM and note the name of the VM you created for the following steps

#### Additional Settings
- Edit the virtual machine you created above
- Disable the _Secure Boot_ setting under the _Security_ tab
- Assign enough CPU to meet requirements
- Add a DVD drive to your SCSI controller if not already present
- Select _Image File_ for your DVD drive, and pick the CML ISO you downloaded
- Save the configuration changes, but do not start the VM yet

### Enable Nested Virtualization
- Open a PowerShell prompt as an administrator
- Run
    ```powershell
    PS C:\> Set-VMProcessor -VMName <VMName> -ExposeVirtualizationExtensions $true 
    ```
    `<VMName>` should be replaced with your VM name from above. Quote appropriately if it contains spaces.


### Boot the Virtual Machine and configure CML
- _Start_ the virtual machine and open the console
- Install CML as you would for a bare metal installation
- Once CML is installed, you can download refplat files as ISO and attach them to your virtual DVD drive
