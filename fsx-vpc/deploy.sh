#!/bin/bash
#
#  Deploy MINIWDL-AWS infrastructure with EFx to a specific availability zone and VPC
#
# exit when any command fails
set -e 
# get availability zone,vpc and optional fsx size from command line arguments
#check if we have 2 or 3 arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <availability-zone> <vpc-id> [<fsx-size>]"
    exit 1
fi
AZ=$1
VPC=$2
# Check if a third parameter was provided
if [ $# -ge 3 ]; then
    FSX_SIZE="$3"
else
    FSX_SIZE=1200  # assign a default value, or leave it empty
fi

# get region from availability zone by removing last character
az_length=${#AZ}
REGION=${AZ:0:az_length-1}
AWS_REGION=$REGION
AWS_DEFAULT_REGION=$REGION
echo "Setting MINIWDL-AWS-EFx for: Region $REGION, VPC $VPC, Availability Zone $AZ, FSx size $FSX_SIZE"

#find VPC id by name 
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=$VPC" --query 'Vpcs[0].VpcId' --output text)
# exit if VPC_ID is equal to string "None"
if [ "$VPC_ID" == "None" ]; then
    echo "VPC $VPC not found"
    exit 1
fi
# find a subnet in the specified availability zone and VPC
SUBNET=$(aws ec2 describe-subnets --region $REGION --filters "Name=availability-zone,Values=$AZ" "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text)
# exit if SUBNET is equal to string "None"
if [ "$SUBNET" == "None" ]; then
    echo "Subnet in $AZ not found"
    exit 1
fi
# find a security group in the specified VPC
SECURITY_GROUP=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text)
# exit if SECURITY_GROUP is equal to string "None"
if [ "$SECURITY_GROUP" == "None" ]; then
    echo "Security group in $VPC not found"
    exit 1
fi

echo "Setting MINIWDL-AWS-EFx for: Security Group $SECURITY_GROUP, Subnet $SUBNET"
terraform init
terraform apply \
    -var="availability_zone=$AZ" \
    -var="environment_tag=miniwdl-fsx" \
    -var="owner_tag=me@example.com" \
    -var="s3upload_buckets=[\"miniwdl-bucket-ds\"]" \
    -var="subnet_id=$SUBNET" \
    -var="security_group_id=$SECURITY_GROUP" \
    -var="task_max_vcpus=2048" \
    -var="lustre_GiB=$FSX_SIZE" \
    -var="create_spot_service_roles=false"