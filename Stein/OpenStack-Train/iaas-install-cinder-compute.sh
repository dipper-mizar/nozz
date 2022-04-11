#!/bin/bash
# 加载环境变量
source /etc/nozz/openrc.sh
# 安装需要的软件包
yum -y install lvm2 device-mapper-persistent-data
systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service
# 创建卷组
pvcreate -f /dev/$BLOCK_DISK
vgcreate cinder-volumes /dev/$BLOCK_DISK
# 安装需要的软件包
yum -y install openstack-cinder targetcli python-keystone
# 配置数据库连接
crudini --set /etc/cinder/cinder.conf database connection mysql+pymysql://cinder:$CINDER_DBPASS@$HOST_NAME/cinder
# 连接消息队列
crudini --set /etc/cinder/cinder.conf DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$HOST_NAME
# Keystone认证
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
crudini --set /etc/cinder/cinder.conf DEFAULT my_ip $HOST_IP_NODE
# 卷存储配置
crudini --set /etc/cinder/cinder.conf lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
crudini --set /etc/cinder/cinder.conf lvm volume_group cinder-volumes
crudini --set /etc/cinder/cinder.conf lvm target_protocol iscsi
crudini --set /etc/cinder/cinder.conf lvm target_helper lioadm
crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends lvm
crudini --set /etc/cinder/cinder.conf DEFAULT glance_api_servers http://$HOST_NAME:9292
crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp
# 落定服务
systemctl enable openstack-cinder-volume.service target.service
systemctl start openstack-cinder-volume.service target.service
