# FalconStor CI for Cinder: project-config

The structure of this repo is based on the upstream sample [openstack-infra/project-config-example](https://github.com/openstack-infra/project-config-example).

The configuration files for zuul, nodepool, and jenkins jobs have been customized.

The directories nodepool/elements and nodepool/scripts directories have been copied from the upstream repo [openstack-infra/project-config](https://github.com/openstack-infra/project-config). 

However, one custom file (set_iscsi_name.sh) has been added to nodepool/scripts. This custom script is specified as the "ready-script" in nodepool.yaml. When nodepool spins up a slave node, set_iscsi_name.sh is invoked in order to set the hostname and generate a new iSCSI initiator name.
