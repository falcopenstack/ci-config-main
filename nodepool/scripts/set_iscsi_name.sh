#!/bin/bash -xe

# Nodepool invokes this script and passes the node name as a parameter
# The node name contains the node ID as a suffix, so we know it is unique

HOSTNAME=$1

# Set hostname
sudo hostname $HOSTNAME
if [ -n "$HOSTNAME" ] && ! grep -q $HOSTNAME /etc/hosts ; then
    echo "127.0.1.1 $HOSTNAME" | sudo tee -a /etc/hosts
fi
echo $HOSTNAME > /tmp/image-hostname.txt
sudo mv /tmp/image-hostname.txt /etc/image-hostname.txt

# Quick fix so that slave node can resolve the master
echo "192.168.2.32 ci-master" | sudo tee -a /etc/hosts

# Set iSCSI initiator name to make it unique
INITNAME=`sudo iscsi-iname`
if [ -z "$INITNAME" ]; then
    INITNAME="iqn.1993-08.org.debian:01:$HOSTNAME"
fi
echo "InitiatorName=$INITNAME" | sudo tee /etc/iscsi/initiatorname.iscsi
sudo service open-iscsi restart
