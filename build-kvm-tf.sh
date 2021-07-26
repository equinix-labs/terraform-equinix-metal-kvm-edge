#!/bin/bash

# Update and install packages
apt update
apt -y upgrade
apt -y install virt-manager
apt -y install bridge-utils
apt -y install ufw
apt -y install moreutils

# Collect network info for the management interface
ipaddr=$(ifdata -pa bond0)
netmask=$(ifdata -pn bond0)
gateway=$(route | awk '/^default/ { print $2 }')

# Find actual interfaces
read -r name if1 if2 < <(grep bond-slaves /etc/network/interfaces)

# Disable netfilter on bridges
echo net.bridge.bridge-nf-call-ip6tables=0 >> /etc/sysctl.d/bridge.conf
echo net.bridge.bridge-nf-call-iptables=0 >> /etc/sysctl.d/bridge.conf
echo net.bridge.bridge-nf-call-arptables=0 >> /etc/sysctl.d/bridge.conf
echo ACTION=="add", SUBSYSTEM=="module", KERNEL=="br_netfilter", RUN+="/sbin/sysctl -p /etc/sysctl.d/bridge.conf" >> /etc/udev/rules.d/99-bridge.rules

# Remove default bridges for KVM
virsh net-destroy default
virsh net-undefine default

# Build new interfaces file
mv /etc/network/interfaces /etc/network/interfaces."$(date +"%m-%d-%y-%H-%M")"
echo "auto lo" >> /etc/network/interfaces
echo "iface lo inet loopback" >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "auto bridge1 " >> /etc/network/interfaces
echo "iface bridge1 inet static" >> /etc/network/interfaces
echo "    address "$ipaddr >> /etc/network/interfaces
echo "    netmask "$netmask >> /etc/network/interfaces
echo "    gateway "$gateway >> /etc/network/interfaces
echo "    dns-nameservers 1.1.1.1" >> /etc/network/interfaces
echo "    bridge_ports "$if1 >> /etc/network/interfaces
echo "    bridge_stp off" >> /etc/network/interfaces
echo "    bridge_maxwait 0" >> /etc/network/interfaces
echo "    bridge_fd 0" >> /etc/network/interfaces
echo "    mtu 9000" >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "auto bridge1:0" >> /etc/network/interfaces
echo "iface bridge1:0 inet static" >> /etc/network/interfaces
echo "    address "${pub_ip} >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "auto bridge2" >> /etc/network/interfaces
echo "iface bridge2 inet manual" >> /etc/network/interfaces
echo "    bridge_ports "$if2 >> /etc/network/interfaces
echo "    bridge_stp off" >> /etc/network/interfaces
echo "    bridge_maxwait 0" >> /etc/network/interfaces
echo "    bridge_fd 0" >> /etc/network/interfaces
echo "    mtu 9000" >> /etc/network/interfaces

# Create and apply bridge files for KVM
echo "<network>" >> /tmp/bridge1.xml
echo "  <name>bridge1</name>" >> /tmp/bridge1.xml
echo "  <forward mode=\"bridge\"/>" >> /tmp/bridge1.xml
echo "  <bridge name=\"bridge1\"/>" >> /tmp/bridge1.xml
echo "</network>" >> /tmp/bridge1.xml

echo "<network>" >> /tmp/bridge2.xml
echo "  <name>bridge2</name>" >> /tmp/bridge2.xml
echo "  <forward mode=\"bridge\"/>" >> /tmp/bridge2.xml
echo "  <bridge name=\"bridge2\"/>" >> /tmp/bridge2.xml
echo "</network>" >> /tmp/bridge2.xml

virsh net-define /tmp/bridge1.xml
virsh net-autostart bridge1
virsh net-define /tmp/bridge2.xml
virsh net-autostart bridge2

# Configure UFW to allow SSH on management IP
ufw logging on
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# Configure forwarding for elastic SUBNET
sed -i "s/DEFAULT_FORWARD_POLICY=\"DROP\"/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/g" /etc/default/ufw
echo "net/ipv4/ip_forward=1" >> /etc/ufw/sysctl.conf
echo "net/ipv4/conf/all/forwarding=1" >> /etc/ufw/sysctl.conf

# Reboot to apply everything
reboot
