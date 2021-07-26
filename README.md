# Equinix Metal KVM-Edge
This script will deploy an edge instance at Equinix Metal using Terraform to pre-configure a server with Ubuntu 20.04 and KVM running in hybrid unbonded mode. 

During the install process the following tasks will be completed automatically. 
  1. The server will update and install all required packages
  2. The bridges for KVM will be automatically created and registered.
  3. Netfilter will be disabled on the bridges.
  4. Forwarding will be enabled for the elastic subnet.
  5. UFW will be configured to only allow SSH to the MGMT IP.
  6. The system will reboot to complete all changes.  
 
 **Be patient after launching the instance, it takes under 10 minutes to complete in most cases.**

If you need an Equinix Metal account please visit https://console.equinix.com

Find the Equinix Metal documentation at https://metal.equinix.com/developers/docs/


## Overview
![KVM-Edge](https://user-images.githubusercontent.com/74058939/127067235-d354abce-46c1-40b6-9080-cb3a26326073.png)



In this example the management (MGMT) IP for the Instance is 100.100.100.10.<br/>
The elastic subnet forwarded to the VMs is 100.200.20.8/29.<br/>
The KVM server is administered on the MGMT IP and only allows for SSH<br/>
The first IP from the elastic block becomes the gateway for all VMs<br/>

![kvm-edge-instance](https://user-images.githubusercontent.com/74058939/127065546-2d69c95a-1e97-48f2-8048-ada843172f01.png)

## Installing / Getting started

You will need Terraform https://www.terraform.io/ and this repo to get started.<br/>
Once you clone or download this repo edit the terraform.tfvars file and fill it with your information.  You will need an API token, a project ID and an organization ID.
```shell
terraform init
terraform plan
terraform apply
```
