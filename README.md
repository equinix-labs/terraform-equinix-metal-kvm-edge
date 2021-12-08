# Equinix Metal KVM-Edge
This script will deploy an edge instance at Equinix Metal using Terraform to pre-configure a server with Ubuntu 20.04 and KVM running in hybrid unbonded mode.  Using hybrid unbonded mode allows for isolation of the bridges to individual interfaces instead of a single bonded interface.  This will allow you to present virtual interfaces to the VMs in an isolated manner since this will be used for routers and firewalls.

During the install process the following tasks will be completed automatically. 
  1. Server will update and install all required packages
  2. Bridges for KVM will be automatically created and registered.
  3. Netfilter will be disabled on the bridges.
  4. Forwarding will be enabled for the elastic subnet.
  5. UFW will be configured to only allow SSH to the MGMT IP.
  6. System will reboot to complete all changes.  
 
 **Be patient after launching the instance, it takes under 10 minutes to complete in most cases<br/>
 You can follow the progress using the SOS out of band console**

If you need an Equinix Metal account please visit https://console.equinix.com

Find the Equinix Metal documentation at https://metal.equinix.com/developers/docs/

## This script is experimental and provided as a proof of concept.  The security and maintenance of the systems deployed is something you will need to take seriously and make sure it fits the needs of your environment.  There is no support for this script.

## Overview
![KVM-Edge](https://user-images.githubusercontent.com/74058939/127067235-d354abce-46c1-40b6-9080-cb3a26326073.png)

In this example the management (MGMT) IP for the Instance is 100.100.100.10<br/>
The elastic subnet forwarded to the VMs is 100.200.20.8/29<br/>
the elastic subnet will be added as an alias to bridge1<br/>
The first usable IP from the elastic block becomes the gateway for all VMs<br/>
The KVM server is administered on the MGMT IP and only allows for SSH<br/>

![kvm-edge-instance](https://user-images.githubusercontent.com/74058939/127392292-3980c90e-a80c-45cf-8a38-0b54f8035e0d.png)

## Installing / Getting started

You will need Terraform https://www.terraform.io/ and this repo to get started.<br/>
After you download this repo you will need to edit **terraform.tfvars** and add your API token, Organization ID and Project ID.<br/>
All of the required information can be found in the Metal portal.

Deploy the KVM edge instance 
```shell
terraform init
terraform plan
terraform apply
```
When you want to remove the edge instance simply run the following command.
```shell
terraform destroy
```

## Manage the instance and launch virtual machines
SSH is enabled on the management interface from any source by default when using this script and will allow remote management of the Metal instance.<br/>

Now that the script has run you can launch any NFV or VM that you like.  Below is a Mikrotik example to help get you going quickly but any KVM compatible image will work like the Cisco 1000v or Juniper vSRX if you have the image and license.

## Examples:

#### EXAMPLE 1:  Use the CLI to deploy a Mikrotik RouterOS VM
The Mikrotik CHR will only run at 1Mbps per interface in unlicensed mode.  It is very easy to get a 60 day trial that will unlock the full speed of the interfaces.  the permanent license is affordable and easy to get.  Visit https://mikrotik.com/ for more info.

Before we begin, find the public IP that you will assign to this cloud router.  If you look at the output below you will see that a subnet with a /29 network is listed below bridge1.  You will be able to use the next IP in line for this VM and the IP listed as the gateway for the VM.

```shell
ip a
...
5: bridge1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 qdisc noqueue state UP group default qlen 1000
    link/ether b4:96:91:84:3d:f8 brd ff:ff:ff:ff:ff:ff
    inet 100.100.100.10/31 brd 255.255.255.255 scope global bridge1
       valid_lft forever preferred_lft forever
    inet 100.200.20.9/29 brd 100.200.20.14 scope global bridge1:0
       valid_lft forever preferred_lft forever
...
```

Download RouterOS RAW image from Mikrotik.  Unzip the image and move it to /var/lib/libvirt/images/

```shell
apt install unzip
wget https://download.mikrotik.com/routeros/6.48.3/chr-6.48.3.img.zip
unzip chr-6.48.3.img.zip
mv chr-6.48.3.img /var/lib/libvirt/images/
```

Now that the disk image is in place you can launch the VM 

```shell
virt-install --name=CloudRouter \
--import \
--vcpus=2 \
--memory=1024 \
--disk vol=default/chr-6.48.3.img,bus=sata \
--network=network:bridge1,model=virtio \
--network=network:bridge2,model=virtio \
--os-type=generic \
--os-variant=generic \
--noautoconsole

virsh autostart CloudRouter
```


Before you begin configuring the Cloud Router find your own public IP so you can add it to the safe list for remote managment.  There are many ways to get your public IP but one of the easiest is to use the who command to see current connections on the instance.  This should return your public IP.

```shell
root@edge-gateway:~# who
root     pts/0        2021-01-01 00:00 (100.100.10.207)
```


Now you can connect to the instance and begin the configuration, To exit the console use **CTRL + ]**<br/>

```shell
root@edge-gateway:~# virsh console CloudRouter
Connected to domain CloudRouter
Escape character is ^]
MikroTik 6.48.3 (stable)
MikroTik Login: 
```
**The username is admin and there is no password**

For this example we will assign a password to the admin user, setup the public IP and default route then paste a very basic confguration to the CloudRouter.  We will also assign your remote IP to the "safe" list so you can remotely attach to the CloudRouter.  Make sure to adjust the IPs to match your environment.

```shell
### Modify this part ###

user set admin password=Choose_Your_Own_Password
ip address add interface=ether1 address=100.200.20.9/29
ip route add gateway=100.200.20.8
ip dns set servers=1.1.1.1

### This is the IP you found using the who command earlier ###
ip firewall address-list add list=safe address=100.100.10.207

### don't modify anything below ###

/ip firewall filter
add action=accept chain=input comment="accept established connection packets" connection-state=established
add action=accept chain=input comment="accept related connection packets" connection-state=related
add action=drop chain=input comment="drop invalid packets" connection-state=invalid
add action=accept chain=input comment="Allow access to router from known network" src-address-list=safe
add action=drop chain=input comment="detect and drop port scan connections" protocol=tcp psd=21,3s,3,1
add action=tarpit chain=input comment="suppress DoS attack" connection-limit=3,32 protocol=tcp src-address-list=black_list
add action=add-src-to-address-list address-list=black_list address-list-timeout=1d chain=input comment="detect DoS attack" connection-limit=10,32 protocol=tcp
add action=jump chain=input comment="jump to chain ICMP" jump-target=ICMP protocol=icmp
add action=jump chain=input comment="jump to chain services" jump-target=services
add action=accept chain=input comment="Allow Broadcast Traffic" dst-address-type=broadcast
add action=log chain=input log-prefix=Filter:
add action=drop chain=input comment="drop everything else"
add action=accept chain=ICMP comment="0:0 and limit for 5pac/s" icmp-options=0:0-255 limit=5,5:packet protocol=icmp
add action=accept chain=ICMP comment="3:3 and limit for 5pac/s" icmp-options=3:3 limit=5,5:packet protocol=icmp
add action=accept chain=ICMP comment="3:4 and limit for 5pac/s" icmp-options=3:4 limit=5,5:packet protocol=icmp
add action=accept chain=ICMP comment="8:0 and limit for 5pac/s" icmp-options=8:0-255 limit=5,5:packet protocol=icmp
add action=accept chain=ICMP comment="11:0 and limit for 5pac/s" icmp-options=11:0-255 limit=5,5:packet protocol=icmp
add action=drop chain=ICMP comment="Drop everything else" protocol=icmp
add action=accept chain=services comment="accept localhost" dst-address=127.0.0.1 src-address=127.0.0.1
add action=accept chain=services comment="allow IPSec connections" dst-port=500 protocol=udp
add action=accept chain=services comment="allow IPSec" protocol=ipsec-esp
add action=accept chain=services comment="allow IPSec" protocol=ipsec-ah
add action=return chain=services

/ip firewall filter
add action=fasttrack-connection chain=forward comment=FastTrack connection-state=established,related
add action=accept chain=forward comment="Established, Related"  connection-state=established,related
add action=drop chain=forward comment="Drop invalid" connection-state=invalid log=yes log-prefix=invalid
add action=drop chain=forward comment="Drop incoming packets that are not NATted" connection-nat-state=!dstnat connection-state=new in-interface=ether1 log=yes log-prefix=!NAT
add action=drop chain=forward comment="Drop incoming from internet which is not public IP" in-interface=ether1 log=yes log-prefix=!public src-address-list=not_in_internet

/ip firewall address-list
add address=0.0.0.0/8 comment=RFC6890 list=not_in_internet
add address=172.16.0.0/12 comment=RFC6890 list=not_in_internet
add address=192.168.0.0/16 comment=RFC6890 list=not_in_internet
add address=10.0.0.0/8 comment=RFC6890 list=not_in_internet
add address=169.254.0.0/16 comment=RFC6890 list=not_in_internet
add address=127.0.0.0/8 comment=RFC6890 list=not_in_internet
add address=224.0.0.0/4 comment=Multicast list=not_in_internet
add address=198.18.0.0/15 comment=RFC6890 list=not_in_internet
add address=192.0.0.0/24 comment=RFC6890 list=not_in_internet
add address=192.0.2.0/24 comment=RFC6890 list=not_in_internet
add address=198.51.100.0/24 comment=RFC6890 list=not_in_internet
add address=203.0.113.0/24 comment=RFC6890 list=not_in_internet
add address=100.64.0.0/10 comment=RFC6890 list=not_in_internet
add address=240.0.0.0/4 comment=RFC6890 list=not_in_internet
add address=192.88.99.0/24 comment="6to4 relay Anycast [RFC 3068]" list=not_in_internet
```

Now you can add VLANs to the second interface in the Metal portal and configure the VLANs in the RouterOS VM.  In the Metal portal go to "IPs & Networks" then "Layer 2".  Click "Add New VLAN" and add a VLAN to the correct Metro for this instance and give it a name.

![portal-add-vlan](https://user-images.githubusercontent.com/74058939/127400684-3a0a42e4-fd54-44e1-bcd4-b52f85eccc98.png)

Now from the "servers" section of the portal add the VLAN to the instance by going to the "network" menu on the left.  Scroll to the bottom and click "Add New Vlan".  Choose the interface named "eth1" and then pick the VLAN you just created.

![portal-assign-vlan](https://user-images.githubusercontent.com/74058939/127400756-e4d927f4-59aa-4fd7-94db-76e17adc6535.png)

now configure your router to use this VLAN and assign an IP to the VLAN.

```shell
### this should be your RouterOS console ###
 /interface vlan add interface=ether2 vlan-id=1000 name=myCoolVLAN
 /ip address add interface=myCoolVLAN address=10.10.1.1/24
 /ip firewall nat add chain=srcnat src-address=10.10.1.0/24 action=masquerade
 ```
 
 Now you can assign your new VLAN to other Metal instances that are in Layer2 mode and use this new subnet with 10.10.1.1 as the gateway.
