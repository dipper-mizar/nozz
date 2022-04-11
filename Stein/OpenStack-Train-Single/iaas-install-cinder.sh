#!/bin/bash
# Load environment variables
source /etc/nozz/openrc.sh
source /etc/keystone/admin-openrc.sh
# Install package
yum -y install openstack-cinder lvm2 device-mapper-persistent-data targetcli python-keystone
systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service
# Create volume group
pvcreate -f /dev/$BLOCK_DISK
vgcreate cinder-volumes /dev/$BLOCK_DISK
# Configuration database
mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS cinder;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';"
# Keystone certified
openstack user create --domain default --password $CINDER_PASS cinder
openstack role add --project service --user cinder admin
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
openstack endpoint create --region RegionOne volumev2 public http://$HOST_NAME:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://$HOST_NAME:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://$HOST_NAME:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://$HOST_NAME:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://$HOST_NAME:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://$HOST_NAME:8776/v3/%\(project_id\)s
# Master profile settings
crudini --set /etc/cinder/cinder.conf database connection mysql+pymysql://cinder:$CINDER_DBPASS@$HOST_NAME/cinder
crudini --set /etc/cinder/cinder.conf DEFAULT transport_url rabbit://$RABBIT_USER:$RABBIT_PASS@$HOST_NAME
crudini --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
crudini --set /etc/cinder/cinder.conf keystone_authtoken www_authenticate_uri http://$HOST_NAME:5000
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://$HOST_NAME:5000
crudini --set /etc/cinder/cinder.conf keystone_authtoken memcached_servers $HOST_NAME:11211
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_type password
crudini --set /etc/cinder/cinder.conf keystone_authtoken project_domain_name default
crudini --set /etc/cinder/cinder.conf keystone_authtoken user_domain_name default
crudini --set /etc/cinder/cinder.conf keystone_authtoken project_name service
crudini --set /etc/cinder/cinder.conf keystone_authtoken username cinder
crudini --set /etc/cinder/cinder.conf keystone_authtoken password $CINDER_PASS
crudini --set /etc/cinder/cinder.conf DEFAULT my_ip $HOST_IP
crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp
# Volume storage configuration
crudini --set /etc/cinder/cinder.conf lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
crudini --set /etc/cinder/cinder.conf lvm volume_group cinder-volumes
crudini --set /etc/cinder/cinder.conf lvm target_protocol iscsi
crudini --set /etc/cinder/cinder.conf lvm target_helper lioadm
crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends lvm
crudini --set /etc/cinder/cinder.conf DEFAULT glance_api_servers http://$HOST_NAME:9292
crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp
# Synchronize database
su -s /bin/sh -c "cinder-manage db sync" cinder
crudini --set /etc/nova/nova.conf cinder os_region_name RegionOne
# Finalize service
systemctl restart openstack-nova-api.service
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service openstack-cinder-volume.service target.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service openstack-cinder-volume.service target.service
