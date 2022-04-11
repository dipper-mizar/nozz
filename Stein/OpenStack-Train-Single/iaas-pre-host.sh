#!/bin/bash
# Load environment variables
source /etc/nozz/openrc.sh
# Configure the basic network environment
systemctl stop firewalld.service
systemctl disable firewalld.service >> /dev/null 2>&1
systemctl stop NetworkManager >> /dev/null 2>&1
systemctl disable NetworkManager >> /dev/null 2>&1
sed -i 's/SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
setenforce 0
yum remove -y NetworkManager firewalld
systemctl restart network
yum -y install iptables-services
systemctl enable iptables
systemctl restart iptables
iptables -F
iptables -X
iptables -Z
service iptables save
if [[ `ip a |grep -w $HOST_IP ` != '' ]];then
	hostnamectl set-hostname $HOST_NAME
else
	hostnamectl set-hostname $HOST_NAME
fi
sed -i -e "/$HOST_NAME/d" -e "/$HOST_NAME_NODE/d" /etc/hosts
echo "$HOST_IP $HOST_NAME" >> /etc/hosts
echo "$HOST_IP_NODE $HOST_NAME_NODE" >> /etc/hosts
sed -i -e 's/#UseDNS yes/UseDNS no/g' -e 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
# Install openstack package
yum -y install openstack-utils openstack-selinux python-openstackclient crudini
if [ 0  -ne  $? ]; then
	echo -e "\033[31mThe installation source configuration errors\033[0m"
	exit 1
fi
printf "\033[35mPlease Reboot or Reconnect the terminal\n\033[0m"
