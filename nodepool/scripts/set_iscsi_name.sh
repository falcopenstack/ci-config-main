#!/bin/bash -xe

INITNAME="InitiatorName=iqn.1993-08.org.debian:01:$RANDOM"
sudo echo "$INITNAME" > /etc/iscsi/initiatorname.iscsi
