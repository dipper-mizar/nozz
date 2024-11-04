#!/bin/bash
# Load environment variables
source /etc/nozz/openrc.sh
# Installation of keystone basic components
yum -y install openstack-keystone httpd mod_wsgi
# Creation and authorization of keystone database
mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS keystone;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';"
# Modification of keystone master profile
crudini --set /etc/keystone/keystone.conf database connection  mysql+pymysql://keystone:$KEYSTONE_DBPASS@$HOST_NAME/keystone
crudini --set /etc/keystone/keystone.conf token provider fernet
su -s /bin/sh -c "keystone-manage db_sync" keystone
# Keystone security and authentication configuration
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://$HOST_NAME:5000/v3/ \
  --bootstrap-internal-url http://$HOST_NAME:5000/v3/ \
  --bootstrap-public-url http://$HOST_NAME:5000/v3/ \
  --bootstrap-region-id RegionOne
sed -i "s/#ServerName www.example.com:80/ServerName $HOST_NAME/g" /etc/httpd/conf/httpd.conf
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
systemctl enable httpd.service
systemctl start httpd.service
# Import temporary environment variables
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_AUTH_URL=http://$HOST_NAME:5000/v3
export OS_IDENTITY_API_VERSION=3
# Creation of keystone users, tenants, roles, services and endpoints
openstack domain create --description "My Domain" demo
openstack project create --domain default --description "My Project" demo
openstack user create --domain default --password $DEMO_PASS demo
openstack role create user
openstack role add --project demo --user demo user
openstack project create --domain default --description "Service Project" service
# Creation of keystone environment variable script
cat > /etc/keystone/admin-openrc.sh << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$HOST_NAME:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
