#!/bin/bash

rhn_user=''
rhn_pass=''
ose_pool_id='8a85f9823e3d5e43013e3ddd4e9509c4'
# cfme_pool_id=''

################## Hostname hack ###############################
# ensure each of nodes / masters etc have hostnames properly set
# hostnamectl set-hostname example.host.com

# ensure "$HOME/hostnames" exists, containing
# all ips/hostnames for master, nodes and etcd/lb

################## RHSM registration ###########################
subscription-manager register --username "$rhn_user" --password "$rhn_pass" --force

# subscription-manager list --available --all

# Red Hat Openstack
# subscription-manager attach --pool "8a85f98144844aff014488d058bf15be"
# subscription-manager list --available --all --matches="*OpenStack*"

# Red Hat Enterprise Linux Developer Suite
# subscription-manager attach --pool "8a85f98156f7d4310156f924bd5a2bf8"


# Cloudforms Employee Subscription
# subscription-manager attach --pool "$cfme_pool_id"
# Red Hat OpenShift Container Platform
subscription-manager attach --pool "$ose_pool_id"

subscription-manager repos --disable="*"

# OCP
subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.3-rpms" \
    --enable="rhel-7-server-rh-common-rpms"

# OSP
# subscription-manager repos --enable=rhel-7-server-rpms
# subscription-manager repos --enable=rhel-7-server-rh-common-rpms
# subscription-manager repos --enable=rhel-7-server-extras-rpms
# subscription-manager repos --enable=rhel-7-server-openstack-10-rpms
# subscription-manager repos --enable=rhel-7-server-openstack-10-devtools-rpms

# subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-rh-common-rpms --enable=rhel-ha-for-rhel-7-server-rpms --enable=rhel-7-server-openstack-10-rpms

################### Install prerequisites #######################
yum install -y wget git net-tools bind-utils iptables-services \
               bridge-utils bash-completion rhevm-guest-agent-common
yum update -y
yum -y install atomic-openshift-utils
yum -y install docker

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

#################################################################
# OSE specific
# ansible-playbook -i arco_3nodes.local.yaml openshift-ansible/playbooks/adhoc/uninstall.yml
# ansible-playbook -i arco_3nodes.local.yaml openshift-ansible/playbooks/byo/config.yml
# oc cluster up
# oc login -u system:admin -n default
# oadm policy add-cluster-role-to-user cluster-admin admin --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig
# oadm policy add-role-to-user cluster-admin admin
# oc get pods
# oc get route

