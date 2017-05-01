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
sudo service iscsid restart

# Install and setup JDK
sudo mkdir /usr/local/java
sudo wget -O /usr/local/java/jdk-8u121-linux-x64.tar.gz http://192.168.2.32/privateCK/jdk-8u121-linux-x64.tar.gz
cd /usr/local/java
sudo tar -zxvf jdk-8u121-linux-x64.tar.gz
echo 'JAVA_HOME=/usr/local/java/jdk1.8.0_121' | sudo tee -a /etc/profile
echo 'PATH=$PATH:$JRE_HOME/bin:$JAVA_HOME/bin' | sudo tee -a /etc/profile
echo 'export JAVA_HOME' | sudo tee -a /etc/profile
echo 'export PATH' | sudo tee -a /etc/profile
sudo update-alternatives --install "/usr/bin/java" "java" "/usr/local/java/jdk1.8.0_121/bin/java" 1
sudo update-alternatives --install "/usr/bin/javac" "javac" "/usr/local/java/jdk1.8.0_121/bin/javac" 1
sudo update-alternatives --install "/usr/bin/javaws" "javaws" "/usr/local/java/jdk1.8.0_121/bin/javaws" 1
sudo update-alternatives --set java /usr/local/java/jdk1.8.0_121/bin/java
sudo update-alternatives --set javac /usr/local/java/jdk1.8.0_121/bin/javac
sudo update-alternatives --set javaws /usr/local/java/jdk1.8.0_121/bin/javaws
source /etc/profile
