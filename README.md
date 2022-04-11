# Don't care here, wait to update!

# nozz

## Introduction

This is an offline deployment of openstack Stein version, which is divided into "nozz-sg" and "nozz-db". It is recommended to use CentOS 7.6 1810 environment for deployment. "nozz-sg" is a single node version of openstack Stein. It supports GRE type tenant network and VLAN type provider network, and "nozz-db" is a double node version of openstack Stein, including controller and compute nodes. It also supports GRE type tenant network and VLAN type provider network. The so-called minimal installation means the minimal openstack installation mode including mysql, rabbitmq, keystone, glance, Nova, neutron, cinder and dashboard. The remaining available components are expanding.

## Version update description

#### Current version: v1.0.0

This version systematically stores scripts in RPM package, and users can use scripts by executing the following commands:
yum -y install nozz-db or yum -y install nozz-sg

It depends on the number of nodes the user wants to install.

After that, the environment variables required by the system will be stored in "/etc/nozz/openrc.sh", which can be customized and modified by users; the script will be stored in "/usr/local/bin/" directory.

## User manual

Upload the official original images of the provided software packages "nozz-v1.0.iso" and "CentOS-7-x86_64-dvd-1810.iso" to the CentOS 7.6 1810 server, configure the local yum source, and delete the remaining online sources. Download nozz's exclusive RPM package to generate scripts. Finally, execute the script in normal order. 

Customize the system environment variables in "/etc/nozz/openrc.sh", and execute the installation script using the absolute path, take "nozz-sg" for example, /usr/local/bin/iaas-pre-host.sh.

If the user does not install "nozz-sg", it is worth noting that some components have different scripts to execute on different nodes, such as "nova", "neutron", "cinder", etc. do not execute the same script on the same node repeatedly.
