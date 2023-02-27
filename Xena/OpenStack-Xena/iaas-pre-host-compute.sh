#!/bin/bash
source openrc.sh

function correct_repo() {
    sed -i -e "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-*
    sed -i -e "s|#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g" /etc/yum.repos.d/CentOS-*
}

# 配置基础网络环境
systemctl stop firewalld.service
systemctl disable  firewalld.service >> /dev/null 2>&1
sed -i 's/SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
setenforce 0
yum remove -y firewalld
correct_repo
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

yum config-manager --set-enabled powertools
cat >> /etc/yum.repos.d/CentOS-163.repo << EOF
[extras-163]
name=extras-163
baseurl=http://mirrors.163.com/centos/8-stream/extras/x86_64/os/
enable=1
gpgcheck=1
gpgkey=http://mirrors.163.com/centos/RPM-GPG-KEY-CentOS-Official
EOF
# Get the OpenStack xena repo files, and then correct the repo url.
yum -y install centos-release-openstack-xena
correct_repo
# The official OpenStack xena repo files are not able to download packages,
# didn't know the reason yet, so just replace the baseurl from official
# to 163 which tested passed.
sed -i '8d' /etc/yum.repos.d/CentOS-OpenStack-xena.repo
xena_baseurl_entry="baseurl=http://mirrors.163.com/centos/8-stream/cloud/x86_64/openstack-xena/"
sed -i "/\[centos-openstack-xena\]/a$xena_baseurl_entry" /etc/yum.repos.d/CentOS-OpenStack-xena.repo

# Fix the centos-ceph-pacific repo baseurl error.
sed -i '9d' /etc/yum.repos.d/CentOS-Ceph-Pacific.repo
ceph_pacific_baseurl_entry="baseurl=https://mirrors.aliyun.com/\$contentdir/\$avstream/storage/\$basearch/ceph-pacific/"
sed -i "/\[centos-ceph-pacific\]/a$ceph_pacific_baseurl_entry" /etc/yum.repos.d/CentOS-Ceph-Pacific.repo

yum -y upgrade
yum -y install openstack-selinux python3-openstackclient crudini