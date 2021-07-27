# Equinix Metal KVM-Edge
This script will deploy an edge instance at Equinix Metal using Terraform to pre-configure a server with Ubuntu 20.04 and KVM running in hybrid unbonded mode. 

During the install process the following tasks will be completed automatically. 
  1. Server will update and install all required packages
  2. Bridges for KVM will be automatically created and registered.
  3. Netfilter will be disabled on the bridges.
  4. Forwarding will be enabled for the elastic subnet.
  5. UFW will be configured to only allow SSH to the MGMT IP.
  6. System will reboot to complete all changes.  
 
 **Be patient after launching the instance, it takes under 10 minutes to complete in most cases.  You can follow the progress using the SOS out of band console**

If you need an Equinix Metal account please visit https://console.equinix.com

Find the Equinix Metal documentation at https://metal.equinix.com/developers/docs/


## Overview
![KVM-Edge](https://user-images.githubusercontent.com/74058939/127067235-d354abce-46c1-40b6-9080-cb3a26326073.png)

In this example the management (MGMT) IP for the Instance is 100.100.100.10.<br/>
The elastic subnet forwarded to the VMs is 100.200.20.8/29.<br/>
the elastic subnet will be added as an alias to bridge1.<br/>
The KVM server is administered on the MGMT IP and only allows for SSH<br/>
The first IP from the elastic block becomes the gateway for all VMs<br/>
The default route for the instance is 100.100.100.10<br/>

![kvm-edge-instance](https://user-images.githubusercontent.com/74058939/127162687-98d837f5-9bc7-4bb1-86c1-fdec1e3656ee.png)

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

## Managing the instance and install your first VM
If you setup SSH forwarding and can tunnel remote apps then using **virt-manager** remotely is a very easy, graphical way to administer the VMs on this instance.
If you have configured SSH forwarding then remotely access the instance using the management IP and run the following.
```shell
virt-manager
```

After a few seconds you will get a popup windows that looks like this


![virt-manager](https://user-images.githubusercontent.com/74058939/127195835-c5af5691-e5ba-4b8c-b582-ca2a2e7669c0.png)


Of course you can always use the CLI to manage KVM.  A simple example for an edge router would look like this
```shell
virsh....
```
