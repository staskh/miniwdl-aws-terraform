# miniwdl-aws-terraform/fsx

This variant of the [miniwdl-aws-terraform](https://github.com/miniwdl-ext/miniwdl-aws-terraform) configuration deploys [FSx for Lustre](https://aws.amazon.com/fsx/lustre/) (FSxL) instead of [EFS](https://aws.amazon.com/efs/) IN EXISTING VPC. FSxL has greater upfront costs than EFS, but offers higher throughput scalability needed for large-scale operations.

Compared to the default EFS stack, the key differences here are:

1. FSxL and Batch compute environments are confined to one availability zone
2. Compute environment for workflow jobs (running miniwdl itself) uses EC2 instead of Fargate
3. Workflow and task compute environments have an additional cloud-init script that mounts FSxL
4. FSxL capacity must be provisioned in advance, and doesn't grow automatically like EFS

### Deploy

```
git clone https://github.com/miniwdl-ext/miniwdl-aws-terraform.git
cd miniwdl-aws-terraform/fsx-vpc
terraform init
terraform apply \
    -var='availability_zone=eu-west-1c' \
    -var='environment_tag=miniwdl-fsx' \
    -var='owner_tag=stas@pheno.ai' \
    -var='s3upload_buckets=["miniwdl-bucket-ds"]' \
    -var='subnet_id=subnet-0477d22ddb3d43d63' \
    -var='security_group_id=sg-0b14136d09b98d573' \
    -var='task_max_vcpus=2048' \
    -var='lustre_GiB=1200' \
    -var='create_spot_service_roles=false'  # (your account probably has them by now)
```

`deploy.sh` script simplify lookup for subnet and security group identifiers, so you can instead of above run
```
./deploy.sh <availability_zone> <VPCname> [<optional_lustre_size>]
```

The following *additional* [variables](variables.tf) are available:

* **lustre_GiB** filesystem capacity; set to 1200 or a multiple of 2400 (default 1200)
* **lustre_weekly_maintenance_start_time** see [FSxL docs on WeeklyMaintenanceStartTime](https://docs.aws.amazon.com/fsx/latest/APIReference/API_UpdateFileSystemLustreConfiguration.html)

Then use the `--no-efs` mode of `miniwdl-aws-submit`,

IMPORTANT: if WDL dockers run not under "root" user, do ```sudo chmod 777 /mnt/net``` on the EC2 instance

```
miniwdl-aws-submit --self-test --follow --workflow-queue miniwdl-fsx-workflow --no-efs
```

### Next steps

As with EFS, you'll need a way to browse & manage the remote FSxL contents. FSxL has fewer integrations with other AWS services like Fargate & Lambda to facilitate this, so it usually involves accessing some EC2 server mounting the filesystem. A shortcut to get one:

1. Open the security group for inbound SSH (by uncommenting the relevant lines in the configuration)
2. Increase the workflow compute environment minvCpus, so that an instance will run persistently
3. Use [EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html#connect-options) to SSH into the instance and interact with `/mnt/net`
