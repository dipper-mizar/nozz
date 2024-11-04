#!/bin/bash
# 加载环境变量
source /etc/nozz/openrc.sh
# 安装软件包
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch ebtables ipset
# 连接消息队列
crudini --set /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$HOST_NAME
crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips true
# Keystone认证
crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
crudini --set /etc/neutron/neutron.conf keystone_authtoken www_authenticate_uri http://$HOST_NAME:5000
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://$HOST_NAME:5000
crudini --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers $HOST_NAME:11211
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name service
crudini --set /etc/neutron/neutron.conf keystone_authtoken username neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken password $NEUTRON_PASS

crudini --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp
# ML2插件配置
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,gre,vxlan,local
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,l2population
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset true
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group true
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver iptables_hybrid
# Openvswitch网桥配置
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population true
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent prevent_arp_spoofing true
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs integration_bridge br-int
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings external:br-ex
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types gre
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $HOST_IP_NODE
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs enable_tunneling true
# 在Nova连接Neutron到Keystone
crudini --set /etc/nova/nova.conf neutron url http://$HOST_NAME:9696
crudini --set /etc/nova/nova.conf neutron auth_url http://$HOST_NAME:5000
crudini --set /etc/nova/nova.conf neutron auth_type password
crudini --set /etc/nova/nova.conf neutron project_domain_name default
crudini --set /etc/nova/nova.conf neutron user_domain_name default
crudini --set /etc/nova/nova.conf neutron region_name RegionOne
crudini --set /etc/nova/nova.conf neutron project_name service
crudini --set /etc/nova/nova.conf neutron username neutron
crudini --set /etc/nova/nova.conf neutron password $NEUTRON_PASS
crudini --set /etc/nova/nova.conf DEFAULT use_neutron true
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
crudini --set /etc/nova/nova.conf DEFAULT vif_plugging_is_fatal true
crudini --set /etc/nova/nova.conf DEFAULT vif_plugging_timeout 300
# 配置内核转发
modprobe br_netfilter
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.conf
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf
sysctl -p

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

# 创建网桥
systemctl restart openvswitch
systemctl enable openvswitch
ovs-vsctl add-br br-int > /dev/null 2>&1
ovs-vsctl add-br br-ex > /dev/null 2>&1
ovs-vsctl add-port br-ex $INTERFACE_NAME > /dev/null 2>&1
# 配置外网网卡
cat > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE_NAME << EOF
DEVICE=$INTERFACE_NAME
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
EOF
ethtool -K $INTERFACE_NAME gro off
systemctl restart network
# 落定服务
systemctl restart openstack-nova-compute.service
systemctl restart neutron-metadata-agent.service
systemctl enable neutron-metadata-agent.service
systemctl restart neutron-openvswitch-agent.service
systemctl enable neutron-openvswitch-agent.service
