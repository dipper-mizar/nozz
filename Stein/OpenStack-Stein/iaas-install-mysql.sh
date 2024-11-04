#!/bin/bash
source /etc/nozz/openrc.sh
# 安装RabbitMQ消息队列并添加用户
yum -y install rabbitmq-server
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
rabbitmqctl add_user $RABBIT_USER $RABBIT_PASS
rabbitmqctl set_permissions $RABBIT_USER ".*" ".*" ".*"
# 安装配置Memcached服务
yum -y install memcached python-memcached
sed -i '/OPTIONS/d' /etc/sysconfig/memcached
echo OPTIONS=\"-l 127.0.0.1,::1,$HOST_NAME\" >> /etc/sysconfig/memcached
systemctl enable memcached.service
systemctl start memcached.service
# 安装MySQL数据库服务
yum -y install mariadb mariadb-server python2-PyMySQL expect
# 配置数据库服务
cat > /etc/my.cnf.d/openstack.cnf << EOF
[mysqld]
bind-address = $HOST_IP
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
systemctl enable mariadb.service
systemctl start mariadb.service
# 初始化数据库服务
expect -c "
spawn /usr/bin/mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"y\r\"
expect \"New password:\"
send \"$DB_PASS\r\"
expect \"Re-enter new password:\"
send \"$DB_PASS\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"n\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
"
