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

# Set iSCSI initiator name to make it unique
INITNAME="InitiatorName=iqn.1993-08.org.debian:01:$HOSTNAME"
echo "$INITNAME" | sudo tee /etc/iscsi/initiatorname.iscsi
