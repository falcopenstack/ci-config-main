#!/usr/bin/env bash

# Copyright (C) 2015 Hewlett-Packard Development Company, L.P.
# Copyright (C) 2015 Pure Storage, Inc.
# Copyright (C) 2016 FalconStor Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.


# Shell commands to get virsh the information it
# needs to successfully pass through a Fibre Channel PCI Card to the virtual
# machine this script is running on. The instance only knows its IP address,
# while its Virsh name is required for pass through. This script uses Nova on
# the provider blade as an intermediary to find the name. Meanwhile, this
# script finds the Fibre Channel PCI card on the provider and generates the
# information Virsh needs to attach it.
#
# Expect four env variables, the provider hostname (optionally user if needed)
# the private key file we should use to connect to the provider, and the file
# that should be sourced for OpenStack credentials.
#
# export FC_PROVIDER=my.provider.hostname
# export FC_PROVIDER_USER=root
# export FC_PROVIDER_KEY=/opt/nodepool-scripts/passthrough
# export FC_PROVIDER_RC=/root/keystonerc_jenkins

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

#
# FC Passthrough setup starts here
#
echo "===Export FC_PROVIDER env variable==="
 export FC_PROVIDER=192.168.2.70
 export FC_PROVIDER_USER=root
 export FC_PROVIDER_KEY=/opt/nodepool-scripts/passthrough
 export FC_PROVIDER_RC=/root/keystonerc_admin
#
# For single node setups where the hypervisor is the same as the provider, and dns
# is not configured, export this variable to use the provider ip as the hypervisor
 export FC_SINGLE_NODE=1
# /opt/nodepool-scripts/invoke-fc-passthrough.sh

eth0_ip=$(hostname  -I | cut -f1 -d' ')

PROVIDER=${FC_PROVIDER}
echo "===FC_PROVIDER(PROVIDER) is $PROVIDER==="
if [[ -z $PROVIDER ]]; then
    eth0_ip_base=$(echo $eth0_ip | cut -f1,2,3 -d.)
    PROVIDER="${eth0_ip_base}.1"
fi

PROVIDER_KEY=${FC_PROVIDER_KEY:-"/opt-nodepool-scripts/passthrough"}
PROVIDER_RC=${FC_PROVIDER_RC:-"keystonerc_jenkins"}

CURRENT_USER=$(whoami)
PROVIDER_USER=${FC_PROVIDER_USER:-$CURRENT_USER}

# Passthrough is a private key that needs to be setup for the provider
# and any compute nodes that might end up hosting the VM we want passthrough on.
# We will assume ownership of the key (probably as the jenkins user..), also
# assuming the group is the same name as the user...
sudo chown $CURRENT_USER:$CURRENT_USER $PROVIDER_KEY
chmod 0400 $PROVIDER_KEY

# Get our NOVA_ID
NOVA_LIST=$(ssh -i $PROVIDER_KEY $PROVIDER_USER@$PROVIDER "source $PROVIDER_RC && nova list")
nova_result=$?
NOVA_ID=$(echo "$NOVA_LIST" | grep ACTIVE | grep -v deleting | grep $eth0_ip | cut -d \| -f 2 | tr -d '[:space:]')
echo "NOVA_ID result: $nova_result"
if [[ $nova_result -ne 0 || -z "$NOVA_ID" ]]; then
    echo "Unable to get Nova ID. Aborting. Debug info:"
    echo $NOVA_LIST
    echo "NOVA_ID: $NOVA_ID"
    exit 2
fi

# Get instance details
NOVA_DETAILS=$(ssh -i $PROVIDER_KEY $PROVIDER_USER@$PROVIDER "source $PROVIDER_RC && nova show $NOVA_ID")
nova_results=$?

# Get our Virsh name
VIRSH_NAME=$(echo "$NOVA_DETAILS" | grep instance_name | cut -d \| -f 3 | tr -d '[:space:]')
virsh_result=$?
echo "VIRSH_NAME is $VIRSH_NAME"
echo "VIRSH_NAME result: $virsh_result"
if [[ $nova_result -ne 0 || $virsh_result -ne 0 || -z "$VIRSH_NAME" ]]; then
    echo "Unable to get Virsh Name. Aborting. Debug info:"
    echo "NOVA_LIST:"
    echo $NOVA_LIST
    echo "NOVA_DETAILS:"
    echo $NOVA_DETAILS
    echo "VIRSH_NAME: $VIRSH_NAME"
    exit 2
fi

# Get the hypervisor_hostname
if [[ -z $FC_SINGLE_NODE ]]; then
    HYPERVISOR=$(echo "$NOVA_DETAILS" | grep hypervisor_hostname | cut -d \| -f 3 | tr -d '[:space:]')
    hypervisor_result=$?
    echo "HYPERVISOR result: $hypervisor_result"
    if [[ $hypervisor_result -ne 0 || -z "$HYPERVISOR" ]]; then
        echo "Unable to get Hypervisor Host Name. Aborting. Debug info:"
        echo "NOVA_LIST:"
        echo $NOVA_LIST
        echo "NOVA_DETAILS:"
        echo $NOVA_DETAILS
        echo "HYPERVISOR: $HYPERVISOR"
        exit 2
    fi
else
    HYPERVISOR=$PROVIDER
fi
echo "Found Hypervisor hostname: $HYPERVISOR"

fc_pci_device=$(ssh -i $PROVIDER_KEY $PROVIDER_USER@$HYPERVISOR 'echo $fc_pci_device')

if [[ -z $fc_pci_device ]]; then
    echo "No FC device known. Set fc_pci_device in your /etc/profile.d or /etc/environment (depending on distro and ssh configuration) to the desired 'Class Device path', e.g. '0000:21:00.2'"
    exit 2
fi

echo "Found pci devices: $fc_pci_device"

exit_code=1
errexit=$(set +o | grep errexit)
#Ignore errors
set +e
i=0
#dettach all the device in provider first
for pci in $fc_pci_device; do
    echo $pci
    BUS=$(echo $pci | cut -d : -f2)
    SLOT=$(echo $pci | cut -d : -f3 | cut -d . -f1)
    FUNCTION=$(echo $pci | cut -d : -f3 | cut -d . -f2)
    XML="<hostdev mode='subsystem' type='pci' managed='yes'><source><address domain='0x0000' bus='0x$BUS' slot='0x$SLOT' function='0x$FUNCTION'/></source></hostdev>"
    #echo $XML
    fcoe[$i]=`mktemp --suffix=_fcoe.xml`
    echo $XML > ${fcoe[$i]}

    scp -i $PROVIDER_KEY ${fcoe[$i]} $PROVIDER_USER@$HYPERVISOR:/tmp/

    # Run passthrough and clean up.
    # TODO: At the point where we can do more than one node on a provider we
    # will need to do this cleanup at the end of the job and not *before* attaching
    # since we won't know which ones are still in use
    #echo $(sudo lspci | grep -i fib)
    ssh -i $PROVIDER_KEY $PROVIDER_USER@$HYPERVISOR "virsh nodedev-dettach pci_0000_${BUS}_${SLOT}_${FUNCTION}"

    detach_result=$?
    let i+=1
    echo "Detach result: $detach_result"
    if [[ $detach_result -ne 0 ]]; then
        echo "Detach failed. Trying next device..."
        continue
    fi
done
$errexit
#Attach all the devices for passthrough
for f in ${fcoe[@]}; do
    #echo $(sudo lspci | grep -i fib)
    ssh -i $PROVIDER_KEY $PROVIDER_USER@$HYPERVISOR "virsh attach-device $VIRSH_NAME $f"
    attach_result=$?
    echo "Attach result: $attach_result"
    if [[ $attach_result -eq 0 ]]; then
        echo "Attached succeed. Trying next device..."
        exit_code=0
    fi
    #echo $(sudo lspci | grep -i fib)
done
$errexit

if [[ $exit_code -ne 0 ]]; then
    echo "FC Passthrough failed. Aborting."
    exit $exit_code
fi

# Make sure that really it worked...
#sudo modprobe lpfc
#echo $?

#sudo apt-get install -y -qq sysfsutils > /dev/null
#echo $?

#sudo systool -c fc_host -v
#echo $?

#echo $(sudo lspci | grep -i fib)

#device_path=$(sudo systool -c fc_host -v | grep "Device path")
#if [[ ${device_path}  -eq 0 ]]; then
#    echo "Failed to install FC Drivers. Aborting."
#    exit 1
#fi

# Install and configure JDK
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
