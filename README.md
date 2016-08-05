# FalconStor CI for Cinder: project-config

The structure of this repo is based on the upstream sample [openstack-infra/project-config-example](https://github.com/openstack-infra/project-config-example).

The configuration files for zuul, nodepool, and jenkins jobs have been customized.

The directories `nodepool/elements` and `nodepool/scripts` have been copied from the upstream repo [openstack-infra/project-config](https://github.com/openstack-infra/project-config). They are used for building disk images in nodepool. 

From time to time, upstream changes may cause the disk image build process to stop working, so we should periodically copy the contents of `nodepool/elements` and `nodepool/scripts` from the upstream project-config repo into our custom repo. This will keep our scripts and elements up to date.

However, 2 custom files `set_iscsi_name.sh` and `invoke_fc_passthrough.sh` have been added to `nodepool/scripts`. Make sure you preserve those files when you update the other scripts.
`set_iscsi_name.sh` is specified as the "ready-script" in nodepool.yaml for iSCSI driver testing. When nodepool spins up a slave node, `set_iscsi_name.sh` is invoked in order to set the hostname and generate a new iSCSI initiator name.
`invoke_fc_passthrough.sh` is specified as the "ready-script" in nodepool.yaml for FC driver testing.
