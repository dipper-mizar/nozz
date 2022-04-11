#!/bin/bash
source openrc.sh
# 配置基础网络环境
systemctl stop firewalld.service
systemctl disable  firewalld.service >> /dev/null 2>&1
sed -i 's/SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
setenforce 0
yum remove -y firewalld
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
sed -i "/^pool 2.centos.pool.ntp.org iburst/d" /etc/chrony.conf
sed -i "2aserver $HOST_NAME iburst" /etc/chrony.conf
systemctl restart chronyd.service
systemctl enable chronyd.service
# 安装OpenStack软件包
yum -y install centos-release-openstack-ussuri
yum config-manager --set-enabled PowerTools
yum -y upgrade
yum -y install openstack-selinux python3-openstackclient crudini