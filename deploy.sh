#!/bin/bash

set -e

REGION=$(aws configure get region)
KEY_NAME="dev_pem"
INSTANCE_TYPE="t3.micro"
AMI_ID="ami-04dd8a25f4efa9b82"

echo "===================================="
echo "AWS Infrastructure Deployment"
echo "===================================="

echo "Region: $REGION"
echo "Key Pair: $KEY_NAME"
echo "Instance Type: $INSTANCE_TYPE"

# Default VPC
VPC_ID=$(aws ec2 describe-vpcs \
--query "Vpcs[?IsDefault==\`true\`].VpcId" \
--output text)

# Default Subnet
SUBNET_ID=$(aws ec2 describe-subnets \
--filters Name=vpc-id,Values=$VPC_ID \
--query "Subnets[0].SubnetId" \
--output text)

echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"

############################################
# Create Security Group
############################################

create_sg(){

NAME=$1
DESC=$2

SG=$(aws ec2 describe-security-groups \
--filters Name=group-name,Values=$NAME Name=vpc-id,Values=$VPC_ID \
--query "SecurityGroups[0].GroupId" \
--output text)

if [ "$SG" = "None" ]; then

SG=$(aws ec2 create-security-group \
--group-name "$NAME" \
--description "$DESC" \
--vpc-id "$VPC_ID" \
--query GroupId \
--output text)

fi

echo "$SG"

}

VPN_SG=$(create_sg vpn-sg "OpenVPN Server")
SQUID_SG=$(create_sg squid-sg "Squid Proxy")
REVERSE_SG=$(create_sg reverse-proxy-sg "Reverse Proxy")
FRONTEND_SG=$(create_sg frontend-sg "Frontend")
BACKEND_SG=$(create_sg backend-sg "Backend")

echo "Security Groups Ready"

############################################
# Add Rules
############################################

cidr_rule(){

aws ec2 authorize-security-group-ingress \
--group-id $1 \
--protocol $2 \
--port $3 \
--cidr $4 >/dev/null 2>&1 || true

}

sg_rule(){

aws ec2 authorize-security-group-ingress \
--group-id $1 \
--protocol $2 \
--port $3 \
--source-group $4 >/dev/null 2>&1 || true

}

# VPN
cidr_rule $VPN_SG tcp 22 0.0.0.0/0
cidr_rule $VPN_SG udp 1194 0.0.0.0/0

# Squid
cidr_rule $SQUID_SG tcp 22 0.0.0.0/0
cidr_rule $SQUID_SG tcp 3128 0.0.0.0/0

# Reverse Proxy
cidr_rule $REVERSE_SG tcp 22 0.0.0.0/0
cidr_rule $REVERSE_SG tcp 80 0.0.0.0/0

# Frontend (Only Reverse Proxy)
sg_rule $FRONTEND_SG tcp 80 $REVERSE_SG

# Backend (Only Reverse Proxy)
sg_rule $BACKEND_SG tcp 8000 $REVERSE_SG

echo "Security Rules Added"

############################################
# Launch Instance
###########################################

launch(){

NAME=$1
SG=$2
USERDATA=$3

INSTANCE_ID=$(aws ec2 run-instances \
--image-id $AMI_ID \
--instance-type $INSTANCE_TYPE \
--key-name $KEY_NAME \
--security-group-ids $SG \
--subnet-id $SUBNET_ID \
--associate-public-ip-address \
--user-data file://$USERDATA \
--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=\"$NAME\"}]" \
--query "Instances[0].InstanceId" \
--output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
    echo "ERROR: Failed to launch $NAME"
    exit 1
fi

echo "$INSTANCE_ID"

}

############################################
# Launch Servers
############################################

VPN_ID=$(launch "OpenVPN Server" $VPN_SG userdata/vpn.sh)

SQUID_ID=$(launch "Squid Proxy Server" $SQUID_SG userdata/squid.sh)

FRONTEND_ID=$(launch "Frontend NGINX Web Server" $FRONTEND_SG userdata/frontend.sh)

BACKEND_ID=$(launch "Backend Python FastAPI" $BACKEND_SG userdata/backend.sh)


echo "Waiting for instances..."

aws ec2 wait instance-running \
--instance-ids \
$VPN_ID \
$SQUID_ID \
$FRONTEND_ID \
$BACKEND_ID

FRONTEND_IP=$(aws ec2 describe-instances \
--instance-ids $FRONTEND_ID \
--query "Reservations[0].Instances[0].PrivateIpAddress" \
--output text)


BACKEND_IP=$(aws ec2 describe-instances \
--instance-ids $BACKEND_ID \
--query "Reservations[0].Instances[0].PrivateIpAddress" \
--output text)


echo "Frontend Private IP: $FRONTEND_IP"
echo "Backend Private IP: $BACKEND_IP"

############################################
# Launch Reverse Proxy
############################################

sed "s/FRONTEND_PRIVATE_IP/$FRONTEND_IP/g; s/BACKEND_PRIVATE_IP/$BACKEND_IP/g" \
userdata/reverse-proxy.sh > /tmp/reverse-proxy.sh


REVERSE_ID=$(launch "NGINX Reverse Proxy" $REVERSE_SG /tmp/reverse-proxy.sh)


echo "Reverse Proxy ID: $REVERSE_ID"


aws ec2 wait instance-running \
--instance-ids $REVERSE_ID


echo "Reverse Proxy Running"

echo "===================================="
echo "Instances Running"
echo "===================================="


aws ec2 describe-instances \
--instance-ids \
$VPN_ID \
$SQUID_ID \
$REVERSE_ID \
$FRONTEND_ID \
$BACKEND_ID \
--query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value|[0],PublicIpAddress]" \
--output table

echo "Deployment Completed"

