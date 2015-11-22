#!/bin/bash -xe

HOSTNAME=$1

sudo hostname $HOSTNAME
if [ -n "$HOSTNAME" ] && ! grep -q $HOSTNAME /etc/hosts ; then
    echo "127.0.1.1 $HOSTNAME" | sudo tee -a /etc/hosts
fi

echo $HOSTNAME > /tmp/image-hostname.txt
sudo mv /tmp/image-hostname.txt /etc/image-hostname.txt

INITNAME="InitiatorName=iqn.1993-08.org.debian:01:$RANDOM"
echo "$INITNAME" | sudo tee /etc/iscsi/initiatorname.iscsi
