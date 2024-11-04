#!/bin/bash
source /etc/nozz/openrc.sh
# 配置基础网络环境
systemctl stop firewalld.service
systemctl disable  firewalld.service >> /dev/null 2>&1
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
elif [[ `ip a |grep -w $HOST_IP_NODE ` != '' ]];then
	hostnamectl set-hostname $HOST_NAME_NODE
else
	hostnamectl set-hostname $HOST_NAME
fi
sed -i -e "/$HOST_NAME/d" -e "/$HOST_NAME_NODE/d" /etc/hosts
echo "$HOST_IP $HOST_NAME" >> /etc/hosts
echo "$HOST_IP_NODE $HOST_NAME_NODE" >> /etc/hosts
sed -i -e 's/#UseDNS yes/UseDNS no/g' -e 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
# 安装配置NTP服务
yum install chrony -y
if [ 0  -ne  $? ]; then
	echo -e "\033[31mThe installation source configuration errors\033[0m"
	exit 1
fi
sed -i "/^server /d" /etc/chrony.conf
sed -i "2aserver $HOST_NAME iburst" /etc/chrony.conf
systemctl restart chronyd.service
systemctl enable chronyd.service
# 安装软件包
yum -y install openstack-utils openstack-selinux python-openstackclient crudini
printf "\033[35mPlease Reboot or Reconnect the terminal\n\033[0m"
