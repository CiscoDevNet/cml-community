### CML on Proxmox

##### Requirements:
- Installed and configured Proxmox node (or cluster) from https://www.proxmox.com/en/downloads
- Downloaded CML installation ISO/OVA and refplat ISO image

##### Install CML from ISO

- Import install and refplat ISOs via GUI (Folder View / Storage / local storage / ISO images / Upload or Download from URL)
If upload is not working (wrong file extension error), copy ISO files to /var/lib/vz/template/iso/ (or any other ISO compatible storage) on Proxmox host via shell.
- Start creating new VM
- General tab
  - fill VM name
- OS tab
  - switch storage to one where ISOs were uploaded
  - select CML install ISO from ISO image dropdown
- System tab
  - select VirtIO SCSI single controller
  - switch BIOS to OVMF (UEFI)
  - select some storage for EFI disk
- Disks tab
  - set disk size to at least 32GB
- CPU tab
  - set needed number of Sockets and Cores
  - CPU type must be set to 'host' to support nested virtualization
- Memory tab
  - set amount of memory
- Network tab
  - choose correct network/MTU etc for first interface (if more interfaces are needed, they must be added after VM creation via Hardware / Add / Network Device option)

Finish VM creation. Start VM and follow install instructions. Switch install iso for refplat when needed.

##### Install CML from OVA

- Import reflat ISO via GUI (Folder View / Storage / local storage / ISO images / Upload or Download from URL)
If upload is not working (wrong file extension error), copy ISO file to /var/lib/vz/template/iso/ (or any other ISO compatible storage) on Proxmox host via shell.
- Copy OVA file to folder for example /var/lib/vz/template/ova/ on Proxmox host.
- Unzip OVA with 'tar -xf cml2_2.7.0-5_amd64-21.ova' command.
- From /var/lib/vz/template/ova/ run import commad: `qm importovf 107 cml2_2.7.0-5_amd64-21_SHA256.ovf local-lvm`. 107 is VM id, choose some not used already, and local-lvm is VMs storage.
- Go to Proxmox GUI and open newly created VM (id 107 in our case).
- Edit HW of VM:
  - switch BIOS to OVMF (UEFI)
  - add new HW 'EFI disk'
  - set processor type to 'host'
  - change SCSI controller to 'VirtIO SCSI single'
  - add Network Device and set model to 'VirtIO Paravirtualized' (add more NICs if needed)
  - add CD/DVD Drive and select appropriate storage and iso image

Boot VM and complete CML installaion
