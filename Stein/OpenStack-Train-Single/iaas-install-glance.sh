#!/bin/bash
# Load environment variables
source /etc/nozz/openrc.sh
source /etc/keystone/admin-openrc.sh
# Install glance service package
yum -y install openstack-glance
# Database configuration
mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS glance;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';"
# Keystone certified
openstack user create --domain default --password $GLANCE_PASS glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://$HOST_NAME:9292
openstack endpoint create --region RegionOne image internal http://$HOST_NAME:9292
openstack endpoint create --region RegionOne image admin http://$HOST_NAME:9292
# API master profile settings
crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:$GLANCE_DBPASS@$HOST_NAME/glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri http://$HOST_NAME:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://$HOST_NAME:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers  $HOST_NAME:11211
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name default
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password $GLANCE_PASS
crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-api.conf glance_store stores file,http
crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
# Registry main profile settings
crudini --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:$GLANCE_DBPASS@$HOST_NAME/glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken www_authenticate_uri http://$HOST_NAME:5000
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://$HOST_NAME:5000
crudini --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers $HOST_NAME:11211
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-registry.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken password $GLANCE_PASS
crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
# Synchronize database
su -s /bin/sh -c "glance-manage db_sync" glance
# Finalize service
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl restart openstack-glance-api.service openstack-glance-registry.service
