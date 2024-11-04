#!/bin/bash
# Load environment variables
source /etc/nozz/openrc.sh
source /etc/keystone/admin-openrc.sh
# Add calculation node to cell database
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova > /dev/null 2>&1
# Database configuration
mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS neutron ;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS' ;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS' ;"
# Keystone certified
openstack user create --domain default --password $NEUTRON_PASS neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://$HOST_NAME:9696
openstack endpoint create --region RegionOne network internal http://$HOST_NAME:9696
openstack endpoint create --region RegionOne network admin http://$HOST_NAME:9696
# Packages required to install neutron
yum -y install openstack-neutron openstack-neutron-ml2 ebtables openstack-neutron-openvswitch haproxy ipset
# Master profile settings
crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips true
crudini --set /etc/neutron/neutron.conf DEFAULT transport_url rabbit://$RABBIT_USER:$RABBIT_PASS@$HOST_NAME
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes true
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes true
# Configure database connection
crudini --set /etc/neutron/neutron.conf database connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$HOST_NAME/neutron
# Connect Keystone
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
# Configure lock path
crudini --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp
# Connecting Nova to keystone in neutron
crudini --set /etc/neutron/neutron.conf nova auth_url http://$HOST_NAME:5000
crudini --set /etc/neutron/neutron.conf nova auth_type password
crudini --set /etc/neutron/neutron.conf nova project_domain_name default
crudini --set /etc/neutron/neutron.conf nova user_domain_name default
crudini --set /etc/neutron/neutron.conf nova region_name RegionOne
crudini --set /etc/neutron/neutron.conf nova project_name service
crudini --set /etc/neutron/neutron.conf nova username nova
crudini --set /etc/neutron/neutron.conf nova password $NOVA_PASS
# ML2 plug in configuration
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks external
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges external:1:1000
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,gre,vxlan,local
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,l2population
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset true
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group true
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver iptables_hybrid
# DHCP settings
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata true
# Layer 3 routing settings
crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/l3_agent.ini DEFAULT ovs_integration_bridge br-int
crudini --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex
# Openvswitch settings
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population true
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini agent prevent_arp_spoofing true
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs integration_bridge br-int
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings external:br-ex
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types gre
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $HOST_IP
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs enable_tunneling true
# Configure metadata service
crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_host $HOST_NAME
crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $METADATA_SECRET
crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_port 8775
# Connecting neutron to keystone in Nova
crudini --set /etc/nova/nova.conf DEFAULT auto_assign_floating_ip true
crudini --set /etc/nova/nova.conf DEFAULT metadata_listen 0.0.0.0
crudini --set /etc/nova/nova.conf DEFAULT metadata_listen_port 8775
crudini --set /etc/nova/nova.conf DEFAULT use_neutron true
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
crudini --set /etc/nova/nova.conf DEFAULT vif_plugging_is_fatal true
crudini --set /etc/nova/nova.conf DEFAULT vif_plugging_timeout 300
crudini --set /etc/nova/nova.conf neutron url http://$HOST_NAME:9696
crudini --set /etc/nova/nova.conf neutron auth_url http://$HOST_NAME:5000
crudini --set /etc/nova/nova.conf neutron auth_type password
crudini --set /etc/nova/nova.conf neutron project_domain_name default
crudini --set /etc/nova/nova.conf neutron user_domain_name default
crudini --set /etc/nova/nova.conf neutron region_name RegionOne
crudini --set /etc/nova/nova.conf neutron project_name service
crudini --set /etc/nova/nova.conf neutron username neutron
crudini --set /etc/nova/nova.conf neutron password $NEUTRON_PASS
crudini --set /etc/nova/nova.conf neutron service_metadata_proxy true
crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $METADATA_SECRET

# Configure kernel forwarding
modprobe br_netfilter
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
sysctl -p

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
# Synchronize database
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
# Create bridges
systemctl restart openvswitch
systemctl enable openvswitch
ovs-vsctl add-br br-int > /dev/null 2>&1
ovs-vsctl add-br br-ex > /dev/null 2>&1
ovs-vsctl add-port br-ex $INTERFACE_NAME > /dev/null 2>&1
# Configure external network
cat > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE_NAME << EOF
DEVICE=$INTERFACE_NAME
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
EOF
ethtool -K $INTERFACE_NAME gro off
systemctl restart network
# Synchronize service
systemctl restart openstack-nova-api.service openstack-nova-compute.service
systemctl enable neutron-server.service neutron-openvswitch-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service
systemctl restart neutron-server.service neutron-openvswitch-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service
