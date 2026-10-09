### CML on AWS EC2

Recent Intel EC2 instance families support hardware nested virtualization, so CML can run on an
ordinary EC2 instance rather than a bare-metal one. A 5-node CML-Free lab runs comfortably on an
`m8i.xlarge`, which is roughly 1% of the hourly cost of an `i3en.metal`. See the first note below
for what was actually verified.

EC2 cannot boot an ISO, so the install is a two-part job: build an AMI once on a temporary
"bake" host, then launch instances from that AMI.

##### Requirements:
- An AWS account, and an instance type that supports nested virtualization. It is available on
  recent Intel families only — `c7i`, `c8i`, `c8id`, `i7i`, `i7ie`, `m7i`, `m8i`, `m8id`, `r7i`,
  `r7iz`, `r8i`, `r8id` and their `-flex` variants. Availability differs per region, so check:
  ```shell
  aws ec2 describe-instance-types --region us-east-1 \
    --filters Name=processor-info.supported-features,Values=nested-virtualization \
    --query 'InstanceTypes[].InstanceType' --output text | tr '\t' '\n' | sort
  ```
- **At least 4 vCPUs.** CML's setup refuses to continue with fewer ("This system does not have the
  minimum number of CPUs required (4)"), so `.large` types cannot be used.
- AWS CLI **2.36 or newer**. Older versions silently reject the
  `CpuOptions.NestedVirtualization` field (2.27 does not know it).
- Downloaded CML installation ISO and refplat ISO image, uploaded to an S3 bucket in the same
  region.
- EC2 serial console access enabled for the account
  (`aws ec2 get-serial-console-access-status`) — this is how you reach an instance whose network
  is not up yet.

##### Build the AMI

- Launch a bake host: Ubuntu 24.04, nested virtualization enabled, plus a second EBS volume of at
  least 64 GB that will become the CML system disk. Give it an instance profile allowing SSM
  access and reads from your bucket, so no inbound ports are needed.
  ```shell
  aws ec2 run-instances --image-id <ubuntu-24.04-ami> --instance-type m8i.xlarge \
    --cpu-options 'NestedVirtualization=enabled' \
    --iam-instance-profile Name=<ssm-profile> \
    --block-device-mappings '[
      {"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":24,"VolumeType":"gp3","DeleteOnTermination":true}},
      {"DeviceName":"/dev/sdf","Ebs":{"VolumeSize":64,"VolumeType":"gp3","DeleteOnTermination":false}}]'
  ```
  Confirm the instance really has the feature before continuing:
  ```shell
  aws ec2 describe-instances --instance-ids <id> \
    --query 'Reservations[].Instances[].CpuOptions'
  ```
- On the bake host, install KVM and copy in the ISOs:
  ```shell
  apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst ovmf unzip
  test -e /dev/kvm || echo "nested virtualization is not active"
  aws s3 cp s3://<bucket>/cml-iso.zip . && unzip cml-iso.zip
  ```
- Boot the installer with the **raw second volume as its disk**, using UEFI firmware. `/dev/nvme1n1`
  below is the 64 GB volume, not the root disk:
  ```shell
  virt-install --name cmlbake --ram 12288 --vcpus 4 --cpu host-passthrough \
    --osinfo ubuntu24.04 --boot uefi \
    --disk path=/dev/nvme1n1,format=raw,bus=virtio,cache=none \
    --cdrom /path/to/cml2_*.iso \
    --network network=default,model=virtio \
    --graphics vnc,listen=127.0.0.1 --noautoconsole --wait 0
  ```
  The installer is non-interactive: it selects the only candidate disk, installs, ejects the ISO
  and powers the VM off.
- Attach the refplat ISO and boot the VM again to run CML's first-time setup:
  ```shell
  virsh change-media cmlbake sda --source /path/to/refplat-*.iso --insert --config
  virsh start cmlbake
  ```
  Complete the setup wizard on the VNC console (`vncdotool` works well for this over SSM), or run
  it headlessly by pre-seeding `/etc/virl2-base-config.yml` on the installed disk with
  `interactive: false` and non-empty passwords for both accounts, which is the same code path the
  wizard uses. Either way, wait until the API answers before continuing:
  ```shell
  curl -sk https://<vm-ip>/api/v0/system_information   # {"version":"...","ready":true,...}
  ```
- Shut the VM down, then adapt the installed system for EC2 by mounting it from the bake host
  (`vgchange -ay; mount /dev/vg00/lv_root /mnt`):
  - **Interface name.** CML's configuration refers to `enp1s0`, the NIC name it saw under KVM.
    Rename the EC2 network interface to match, otherwise none of that configuration applies:
    ```
    # /etc/systemd/network/10-ena-primary.link
    [Match]
    Driver=ena

    [Link]
    Name=enp1s0
    ```
  - **Bridge MAC.** CML pins the primary NIC's MAC into the `bridge0` NetworkManager profile. EC2
    drops frames whose source MAC does not belong to the network interface, so an image carrying
    the bake host's MAC gets no DHCP reply at all. Remove any `macaddress:` and
    `ipv4.dhcp-client-id` lines from `/etc/netplan/*.yaml`.
  - **Enable a serial console** so an instance with no working network is still reachable:
    ```shell
    ln -sf /lib/systemd/system/serial-getty@.service \
      /mnt/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service
    ```
- Snapshot the volume and register the AMI. `--boot-mode uefi` is required — the image is
  UEFI-only and will not boot without it:
  ```shell
  aws ec2 create-snapshot --volume-id <64gb-volume> --description "CML system disk"
  aws ec2 register-image --name cml-free --architecture x86_64 --virtualization-type hvm \
    --ena-support --boot-mode uefi --root-device-name /dev/sda1 \
    --block-device-mappings 'DeviceName=/dev/sda1,Ebs={SnapshotId=<snap>,VolumeSize=64,VolumeType=gp3,DeleteOnTermination=true}'
  ```
  Terminate the bake host afterwards; it is not needed again.

##### Launch CML from the AMI

- Launch on a nested-virtualization instance type with `CpuOptions.NestedVirtualization=enabled`.
  If you use CloudFormation or CDK, note that `AWS::EC2::Instance` supports **neither**
  `CpuOptions.NestedVirtualization` nor `InstanceMarketOptions`; put both on an
  `AWS::EC2::LaunchTemplate` and have the instance reference it.
- Restrict the security group to your own address. CML needs TCP 443; port 22 is useful for the
  host, and Cockpit (9090) and CML's SSH (1122) can be opened if wanted.
- Associate an Elastic IP so the CML URL survives a stop/start.
- **Align `bridge0`'s MAC once per new instance.** CML re-pins the MAC whenever its setup runs, so
  a freshly created instance still comes up without an IPv4 address (the console shows
  `Access the CML UI from https:///`). Over the serial console:
  ```shell
  sudo nmcli connection modify bridge0 \
    802-3-ethernet.cloned-mac-address "$(cat /sys/class/net/enp1s0/address)" \
    ipv4.dhcp-client-id ""
  sudo nmcli connection modify bridge0-p1 802-3-ethernet.mtu 9001
  sudo nmcli connection down bridge0 && sudo nmcli connection up bridge0
  sudo nmcli connection up bridge0-p1
  ```
  This survives stop/start, because the network interface keeps its MAC.

##### Notes

- **What was verified.** On an `m8i.xlarge` with nested virtualization enabled, a KVM-backed node
  (`alpine`) boots as a hardware-accelerated QEMU domain — `qemu-system-x86_64 ... -accel kvm
  -cpu host`, with `/dev/kvm` present and `kvm_intel` loaded — and a 5-node IOL/IOL-L2 lab
  (MPLS L3VPN) runs at about 1% host CPU. IOL nodes run as native processes, not under KVM, so
  the alpine node is what demonstrates nested virtualization. Other KVM node types (IOSv, ASAv,
  …) use the same accelerated QEMU path but were not individually booted.
- **Set the bridge port MTU to 9001** as shown above. AWS DHCP gives `bridge0` an MTU of 9001
  while the bridge port stays at 1500; the symptom is confusing, because TCP handshakes succeed
  and then payload packets disappear, so port 443 accepts connections but nothing ever loads.
- **Bridged external connectors do not work on EC2**, for the same MAC filtering reason. Use NAT
  connectors in your labs.
- Disabling the network interface's source/destination check does **not** help: that setting
  governs IP-level checks, and MAC filtering is not configurable on a normal ENI.
- Spot instances work well for study labs. A *persistent* spot request with
  `InstanceInterruptionBehavior: stop` can be stopped and started by hand and survives
  interruption.
- Sizing: with CML-Free's 5-node limit, a 5-node IOL lab was observed using about 2 GB of RAM, so
  8 GB is adequate for IOL-only labs; 16 GB for ASAv or desktop nodes is extrapolation, not
  measured. See the [CML Sizing Calculator](https://ciscolearning.github.io/cml-sizer/) for
  larger deployments.

*Optional, unofficial: [cml-free-ami-baker](https://github.com/felipedbene/cml-free-ami-baker)
and [cml-free-on-aws](https://github.com/felipedbene/cml-free-on-aws) automate the AMI bake and
the deployment respectively.*
