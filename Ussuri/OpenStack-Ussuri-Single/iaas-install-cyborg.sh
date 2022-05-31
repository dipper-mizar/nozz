#!/bin/bash
source openrc.sh
source /etc/keystone/admin-openrc.sh
rm -rf ~/cyborg && mkdir ~/cyborg
cd ~/cyborg
git clone https://opendev.org/openstack/cyborg -b stable/ussuri
if [ $? -ne 0 ]; then
        echo "[ERROR] Clone cyborg failed."
        rm -rf /root/cyborg
        exit 1
fi
cd ~/cyborg/cyborg
pip3 install tox
if [ $? -ne 0 ]; then
        echo "[ERROR] Install tox failed."
        exit 1
fi
yum -y install gcc
tox -e genconfig
cp -r etc/cyborg /etc && cd /etc/cyborg
ln -s cyborg.conf.sample cyborg.conf
cd ~/cyborg/cyborg
python3 setup.py install
if [ $? -ne 0 ]; then
        echo "[ERROR] Install package failed."
        exit 1
fi
echo "[INFO] Upgrading SQLAlchemy to void a database migration failure."
pip3 install --upgrade sqlalchemy
if [ $? -ne 0 ]; then
        echo "[ERROR] Upgrade SQLAlchemy failed."
        exit 1
fi
pip3 install python-cyborgclient
if [ $? -ne 0 ]; then
        echo "[ERROR] Install Cyborg Python client failed."
        exit 1
fi
rm -rf /root/cyborg
mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS cyborg;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON cyborg.* TO 'cyborg'@'localhost' IDENTIFIED BY '$CYBORG_DBPASS';"
openstack user create --domain default --password $CYBORG_PASS cyborg
openstack role add --project service --user cyborg admin
openstack service create --name cyborg --description "Acceleration Service" accelerator
openstack endpoint create --region RegionOne accelerator public http://$HOST_NAME:6666/v2
openstack endpoint create --region RegionOne accelerator internal http://$HOST_NAME:6666/v2
openstack endpoint create --region RegionOne accelerator admin http://$HOST_NAME:6666/v2
crudini --set /etc/cyborg/cyborg.conf DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$HOST_NAME
crudini --set /etc/cyborg/cyborg.conf DEFAULT use_syslog False
crudini --set /etc/cyborg/cyborg.conf DEFAULT state_path /var/lib/cyborg
crudini --set /etc/cyborg/cyborg.conf DEFAULT debug True
crudini --set /etc/cyborg/cyborg.conf database connection mysql+pymysql://cyborg:$CYBORG_DBPASS@$HOST_NAME/cyborg
crudini --set /etc/cyborg/cyborg.conf service_catalog cafile /opt/stack/data/ca-bundle.pem
crudini --set /etc/cyborg/cyborg.conf service_catalog project_domain_id default
crudini --set /etc/cyborg/cyborg.conf service_catalog user_domain_id default
crudini --set /etc/cyborg/cyborg.conf service_catalog project_name service
crudini --set /etc/cyborg/cyborg.conf service_catalog password $CYBORG_PASS
crudini --set /etc/cyborg/cyborg.conf service_catalog username cyborg
crudini --set /etc/cyborg/cyborg.conf service_catalog auth_url http://$HOST_NAME/identity
crudini --set /etc/cyborg/cyborg.conf service_catalog auth_type password
crudini --set /etc/cyborg/cyborg.conf placement project_domain_name Default
crudini --set /etc/cyborg/cyborg.conf placement project_name service
crudini --set /etc/cyborg/cyborg.conf placement user_domain_name Default
crudini --set /etc/cyborg/cyborg.conf placement password $PLACEMENT_PASS
crudini --set /etc/cyborg/cyborg.conf placement username placement
crudini --set /etc/cyborg/cyborg.conf placement auth_url http://$HOST_NAME/identity
crudini --set /etc/cyborg/cyborg.conf placement auth_type password
crudini --set /etc/cyborg/cyborg.conf placement auth_section keystone_authtoken
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken memcached_servers $HOST_NAME:11211
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken signing_dir /var/cache/cyborg/api
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken cafile /opt/stack/data/ca-bundle.pem
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken project_domain_name Default
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken project_name service
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken user_domain_name Default
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken password $CYBORG_PASS
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken username cyborg
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken auth_url http://$HOST_NAME/identity
crudini --set /etc/cyborg/cyborg.conf keystone_authtoken auth_type password

cyborg-dbsync --config-file /etc/cyborg/cyborg.conf upgrade

echo "
[Unit]
Description=OpenStack Cyborg API Server
After=syslog.target network.target

[Service]
Type=notify
NotifyAccess=all
TimeoutStartSec=0
Restart=always
User=nova
ExecStart=/usr/local/bin/cyborg-api

[Install]
WantedBy=multi-user.target
" > /usr/lib/systemd/system/openstack-cyborg-api.service

echo "
[Unit]
Description=OpenStack Cyborg Conductor
After=syslog.target network.target

[Service]
Type=notify
NotifyAccess=all
TimeoutStartSec=0
Restart=always
User=nova
ExecStart=/usr/local/bin/cyborg-conductor

[Install]
WantedBy=multi-user.target
" > /usr/lib/systemd/system/openstack-cyborg-conductor.service

echo "
[Unit]
Description=OpenStack Cyborg Agent
After=syslog.target network.target

[Service]
Type=notify
NotifyAccess=all
TimeoutStartSec=0
Restart=always
User=nova
ExecStart=/usr/local/bin/cyborg-agent

[Install]
WantedBy=multi-user.target
" > /usr/lib/systemd/system/openstack-cyborg-agent.service
systemctl restart openstack-cyborg-api openstack-cyborg-conductor openstack-cyborg-agent
systemctl enable openstack-cyborg-api openstack-cyborg-conductor openstack-cyborg-agent