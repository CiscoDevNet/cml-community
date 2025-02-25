# CML on Hyper-V
These instructions explain how to deploy CML as a virtual machine (VM) that runs on Hyper-V on Windows. (When deploying to Hyper-V, you do not need to install VMware Workstation on your local system.) You will need a version of Windows that supports and provides the Hyper-V feature. Recent versions of Windows Pro and Windows Enterprise should work. Windows Server 2016 should also include Hyper-V, but the steps to deploy on Windows Server may differ slightly. These instructions will probably not work on other editions of Windows, such as Windows 11 Home. YMMV.

These instructions were tested on Windows 11 Enterprise but should work for other editions of Windows that meet the requirements.

## Requirements
- Windows 10 Pro/Enterprise or later, Server 2016 or later
- Hyper-V windows feature installed and enabled

## Setup
### Enable Hyper-V
To enable Hyper-V on Windows refer to these [instructions](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/). The steps below are a summary of what is provided in the linked documentation.
- Open the **Control Panel**
- Click **Programs** and then **Programs and Features**
- Click **Turn Windows Features on or off**
- Check the checkbox for the top-level **Hyper-V** feature to enable all Hyper-V features
- Click **OK**
- Reboot when asked

### Create Hyper-V Bridged Network
By default, the CML VM will only be visible from your local host OS where Hyper-V is running. If you would like to access the CML VM from a different host on your network, you must create a bridged network in Hyper-V. You will also need to create a Hyper-V bridged network if you would like to send traffic into a lab running on the CML VM from another host or device on your network. See the CML documentation on [external connectors](https://developer.cisco.com/docs/modeling-labs/external-connectors/) for further information.

If you only plan to access the CML instance or the labs running in CML from the local machine where Hyper-V is running, you can skip these steps.

- Launch the Hyper-V GUI
- In the menu on the right of the screen, click **Virtual Switch Manager**
- In the **Create virtual switch** section, select **External** and click **Create Virtual Switch**
- From the list of external network cards, select a network card connected to your local network
- Click **OK** to save the changes

If you skip the above steps and decide later to utilize external network connections, you can follow the above instructions later. However, you will need to edit the virtual machine settings (created below) and change the associated _Virtual Switch_ to one created above to enable external connections.

### Create Hyper-V Virtual Machine
Before proceeding with the following steps, make sure to [download the latest CML ISO](https://developer.cisco.com/docs/modeling-labs/downloading-files-for-cml-installation/). For this step you do **NOT** need the _refplat_ ISO image, only the ISO for the _bare metal installation_.

#### Initial Creation
- Open the Hyper-V GUI from the windows start menu
- In the menu on the right of the screen, click **New** and **Virtual Machine** to open the **New Virtual Machine Wizard**
- Click **Next** on the **Before You Begin** screen if it was not previously dismissed
- On the **Specify a Name and Location** screen, use a **Name** without spaces to avoid quoting/escaping issues
- On the **Specify Generation** screen, select **Generation 2**
- On the **Assign Memory** screen, assign sufficient memory to meet the requirements for CML, as well as any labs you wish to run. Refer to the [CML documentation](https://developer.cisco.com/docs/modeling-labs/system-requirements/).
- Do **NOT** use dynamic memory
  - **ATTENTION** Using dynamic memory with the CML VM will have a negative impact on the performance on your labs running in the CML VM.  The nodes in your network simulation use nested virtualization, and using dynamic memory in Hyper-V can cause _significant_ performance problems because of page swapping.
- On the **Configure Networking** screen, connect the network adapter to either the external network (created above) or the default Hyper-V virtual switch (if you wish to only access CML from the host machine)
- On the **Connect Virtual Hard Disk** screen, assign sufficient disk space to meet the requirements for CML, as well as labs you wish to run. Refer to the [CML documentation](https://developer.cisco.com/docs/modeling-labs/system-requirements/).
- On the **Installation Options** screen, select **Install an Operating System Later**
- Click **Finish** to create the VM. Note the name of the VM you created for the following steps.

#### Additional Settings
- Right click the virtual machine you just created in the **Virtual Machines** list and select **Settings**
- Click the **Security** tab in the left menu
- In the **Security Settings** section, uncheck **Enable Secure Boot** on the right to disable it
- Click the **Processor** tab in the left menu
- In the **Processor** section, adjust **Number of Virtual Processors** according to the CML requirements and your lab demands. Refer to the [CML documentation](https://developer.cisco.com/docs/modeling-labs/system-requirements/).
- Click the **SCSI Controller** tab in the left menu
- In the **SCSI Controller** section, select **DVD Drive** and click **Add**.
- Under the **Media** section, select **Image File** and click **Browse** to select the CML bare metal installation ISO you downloaded earlier
- Click **OK** to save the configuration changes. Do **NOT** start the VM yet.

### Enable Nested Virtualization
- Open a PowerShell prompt as an administrator
- Run
    ```powershell
    PS C:\> Set-VMProcessor -VMName <VMName> -ExposeVirtualizationExtensions $true 
    ```
    `<VMName>` should be replaced with your VM name from above. Quote appropriately if it contains spaces.


### Boot the Virtual Machine and configure CML
- Double click the CML VM in the **Virtual Machines** list
- Click the green **Start** button in the toolbar
- Follow the [CML instructions](https://developer.cisco.com/docs/modeling-labs/bare-metal-installation-bare-metal-installation/) for a bare metal installation

