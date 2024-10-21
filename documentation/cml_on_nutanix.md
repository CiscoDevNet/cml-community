### CML on Nutanix CE

##### Requirements:
- Installed and configured Nutanix CE node (or cluster) from https://www.nutanix.com/uk/products/community-edition
- Downloaded CML installation ISO/OVA and refplat ISO image

##### Install CML from ISO
- Upload install and refplat ISOs to datastore. Go to Settings and Image Configuration. Select correct storage container (Images in our case) and other details and click Save.
- Wait until upload task is completed.
- Go to Settings/VM and click 'Create VM'. Fill name of VM, select number of vCPUs, cores, memory.
- Switch BIOS Configuration to UEFI. If you need secure boot, switch cdrom from IDE to SATA.
- Update cdrom settings and insert CML iso there:
- Add new disk, select correct storage container (VMs in our case)
- Add also at least one NIC
- Save VM, open ssh connection to CVM and enable nested virtualization on CML VM:
```shell
nutanix@NTNX-d295a2f4-A-CVM:10.0.10.90:~$ acli vm.list
VM name              VM UUID
cml-ova-import-test  b7854f03-3117-453e-9221-2611eefe0b94
cml-test-2.8.0dev    e56f7e8d-a663-4826-b128-8e98ba8f1c84
ova-cml-test         a1dce5ed-5d12-4096-a48f-293c35837f88
ubuntu-test-vm       d5c8d107-d58f-4d6f-a585-77ef494cf2a5
nutanix@NTNX-d295a2f4-A-CVM:10.0.10.90:~$ acli vm.update cml-test-2.8.0dev cpu_passthrough=true
cml-test-2.8.0dev: pending
cml-test-2.8.0dev: complete
```
- Power on VM and launch VM console. Proceed with CML setup. Insert refplat ISO to cdrom when needed.

##### Installing CML from OVA:
In Nutanix CE, there is no option how to import OVA, you need Prism central from paid version. There should be OVA import feature in GUI - more info is here: https://portal.nutanix.com/page/documents/kbs/details?targetId=kA03200000099TXCAY

In Nutanix CE, untar OVA file and upload vmdk disk into image storage container.
When creating VM, just use 'Clone from Image Service'.
Everything else is same as when installing from ISO.
