#!/bin/bash

rhn_user=''
rhn_pass=''
ose_pool_id=''
# cfme_pool_id=''

################## Hostname hack ###############################
# ensure each of nodes / masters etc have hostnames properly set
# hostnamectl set-hostname example.host.com

# ensure "$HOME/hostnames" exists, containing
# all ips/hostnames for master, nodes and etcd/lb

################## RHSM registration ###########################
subscription-manager register --username "$rhn_user" --password "$rhn_pass" --force

# subscription-manager list --available --all

# Cloudforms Employee Subscription
# subscription-manager attach --pool "$cfme_pool_id"
# Red Hat OpenShift Container Platform
subscription-manager attach --pool "$ose_pool_id"

subscription-manager repos --disable="*"
subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.3-rpms"

################### Install prerequisites #######################
yum install -y wget git net-tools bind-utils iptables-services bridge-utils bash-completion
yum update -y
yum -y install atomic-openshift-utils
yum -y install docker-1.10.3

################ Configure Docker storage options ###############
sed -i '/OPTIONS=.*/c\OPTIONS="--selinux-enabled --insecure-registry 172.30.0.0/16 --selinux-enabled --log-opt max-size=1M --log-opt max-file=3"' \
      /etc/sysconfig/docker

vgcreate docker-vg /dev/vdb

sed -i  '/VG=.*/d' /etc/sysconfig/docker-storage-setup
sed -i -e '$aVG=docker-vg' /etc/sysconfig/docker-storage-setup

docker-storage-setup

sed -i  '/dm.thinpooldev=.*/d' /etc/sysconfig/docker-storage-setup
sed -i -e '$adm.thinpooldev=/dev/mapper/docker--vg-docker--pool' \
              /etc/sysconfig/docker-storage-setup

lvs && pvs && vgs

status=$(systemctl is-active docker)

if [[ $status -eq 'unknown' ]]; then
  systemctl enable docker
  systemctl start docker
  systemctl status docker
else
  systemctl stop docker
  rm -rf /var/lib/docker/*
  systemctl restart docker
fi

################## Password less access #######################
# ensure "$HOME/hostnames" exists, containing
# all ips/hostnames for master, nodes and etcd/lb

# generate key pair. don't use a keyring password
# ssh-keygen
# ./automate_ssh-copy-id.exp

################################################################
# semanage fcontext -a -t httpd_sys_content_t "/home/arcolife(/.*)?"
# restorecon -R -v "/home/arcolife"
