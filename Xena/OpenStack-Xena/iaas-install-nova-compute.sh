#!/bin/bash
source openrc.sh
function correct_repo() {
    sed -i -e "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-*
    sed -i -e "s|#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g" /etc/yum.repos.d/CentOS-*
}
# This version Nova need openvswitch package, but the version release
# repo didn't have ovs, just replace it to Ussuri.
yum -y install epel-release
yum -y install centos-release-openstack-ussuri
correct_repo
sed -i "9d" /etc/yum.repos.d/CentOS-Ceph-Nautilus.repo
ceph_nautilus_baseurl_entry="baseurl=https://mirrors.aliyun.com/\$contentdir/\$avstream/storage/\$basearch/ceph-nautilus/"
sed -i "/\[centos-ceph-pacific\]/a$ceph_nautilus_baseurl_entry" /etc/yum.repos.d/CentOS-Ceph-Nautilus.repo

# 安装Nova需要的软件包
yum -y install openstack-nova-compute
crudini --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
crudini --set /etc/nova/nova.conf DEFAULT compute_driver libvirt.LibvirtDriver
crudini --set /etc/nova/nova.conf DEFAULT instances_path /var/lib/nova/instances
# 连接消息队列
crudini --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$HOST_NAME
# 配置Keystone认证
crudini --set /etc/nova/nova.conf api auth_strategy keystone
crudini --set /etc/nova/nova.conf keystone_authtoken www_authenticate_uri http://$HOST_NAME:5000/
crudini --set /etc/nova/nova.conf keystone_authtoken auth_url http://$HOST_NAME:5000/
crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers $HOST_NAME:11211
crudini --set /etc/nova/nova.conf keystone_authtoken auth_type password
crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name Default
crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name Default
crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
crudini --set /etc/nova/nova.conf keystone_authtoken username nova
crudini --set /etc/nova/nova.conf keystone_authtoken password $NOVA_PASS
crudini --set /etc/nova/nova.conf DEFAULT my_ip $HOST_IP_NODE
crudini --set /etc/nova/nova.conf DEFAULT use_neutron true
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
# 配置VNC连接
crudini --set /etc/nova/nova.conf vnc enabled true
crudini --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $HOST_IP_NODE
crudini --set /etc/nova/nova.conf vnc novncproxy_base_url  http://$HOST_IP:6080/vnc_auto.html
crudini --set /etc/nova/nova.conf glance api_servers http://$HOST_NAME:9292
crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp
# 配置连接Placement认证
crudini --set /etc/nova/nova.conf placement region_name RegionOne
crudini --set /etc/nova/nova.conf placement project_domain_name DEFAULT
crudini --set /etc/nova/nova.conf placement project_name service
crudini --set /etc/nova/nova.conf placement auth_type password
crudini --set /etc/nova/nova.conf placement user_domain_name DEFAULT
crudini --set /etc/nova/nova.conf placement auth_url http://$HOST_NAME:5000/v3
crudini --set /etc/nova/nova.conf placement username placement
crudini --set /etc/nova/nova.conf placement password $PLACEMENT_PASS
crudini --set /etc/nova/nova.conf libvirt virt_type qemu
crudini --set /etc/nova/nova.conf libvirt inject_key True
iptables -F
iptables -X
iptables -Z
/usr/libexec/iptables/iptables.init save
# 落定服务
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
