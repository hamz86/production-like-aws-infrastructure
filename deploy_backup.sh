#!/bin/bash

set -e

REGION=$(aws configure get region)
KEY_NAME="dev_pem"
INSTANCE_TYPE="t3.micro"

echo "===================================="
echo "AWS Infrastructure Deployment"
echo "===================================="

echo "Region: $REGION"
echo "Key Pair: $KEY_NAME"
echo "Instance Type: $INSTANCE_TYPE"


# Get Default VPC
VPC_ID=$(aws ec2 describe-vpcs \
--filters "Name=isDefault,Values=true" \
--query "Vpcs[0].VpcId" \
--output text)

# Get Subnet
SUBNET_ID=$(aws ec2 describe-subnets \
--filters "Name=vpc-id,Values=$VPC_ID" \
--query "Subnets[0].SubnetId" \
--output text)


echo "VPC ID: $VPC_ID"
echo "Subnet ID: $SUBNET_ID"


echo "Creating Security Groups..."


# VPN Security Group
VPN_SG=$(aws ec2 describe-security-groups \
--filters Name=group-name,Values=vpn-sg \
--query "SecurityGroups[0].GroupId" \
--output text)

if [ "$VPN_SG" == "None" ] || [ -z "$VPN_SG" ]; then

VPN_SG=$(aws ec2 create-security-group \
--group-name vpn-sg \
--description "OpenVPN Server Security Group" \
--vpc-id $VPC_ID \
--query GroupId \
--output text)

fi

echo "VPN SG: $VPN_SG"

echo "VPN SG: $VPN_SG"


# Squid Security Group
SQUID_SG=$(aws ec2 describe-security-groups \
--filters Name=group-name,Values=squid-sg \
--query "SecurityGroups[0].GroupId" \
--output text)

if [ "$SQUID_SG" == "None" ] || [ -z "$SQUID_SG" ]; then

SQUID_SG=$(aws ec2 create-security-group \
--group-name squid-sg \
--description "Squid Proxy Server Security Group" \
--vpc-id $VPC_ID \
--query GroupId \
--output text)

fi

echo "SQUID SG: $SQUID_SG"

echo "SQUID SG: $SQUID_SG"

# Reverse Proxy Security Group
REVERSE_SG=$(aws ec2 describe-security-groups \
--filters Name=group-name,Values=reverse-proxy-sg \
--query "SecurityGroups[0].GroupId" \
--output text)

if [ "$REVERSE_SG" == "None" ] || [ -z "$REVERSE_SG" ]; then

REVERSE_SG=$(aws ec2 create-security-group \
--group-name reverse-proxy-sg \
--description "NGINX Reverse Proxy Security Group" \
--vpc-id $VPC_ID \
--query GroupId \
--output text)

fi

echo "REVERSE SG: $REVERSE_SG"

echo "REVERSE SG: $REVERSE_SG"


# Frontend Security Group
FRONTEND_SG=$(aws ec2 describe-security-groups \
--filters Name=group-name,Values=frontend-sg \
--query "SecurityGroups[0].GroupId" \
--output text)

if [ "$FRONTEND_SG" == "None" ] || [ -z "$FRONTEND_SG" ]; then

FRONTEND_SG=$(aws ec2 create-security-group \
--group-name frontend-sg \
--description "Frontend NGINX Security Group" \
--vpc-id $VPC_ID \
--query GroupId \
--output text)

fi

echo "FRONTEND SG: $FRONTEND_SG"

echo "FRONTEND SG: $FRONTEND_SG"


# Backend Security Group
BACKEND_SG=$(aws ec2 describe-security-groups \
--filters Name=group-name,Values=backend-sg \
--query "SecurityGroups[0].GroupId" \
--output text)

if [ "$BACKEND_SG" == "None" ] || [ -z "$BACKEND_SG" ]; then

BACKEND_SG=$(aws ec2 create-security-group \
--group-name backend-sg \
--description "Backend FastAPI Security Group" \
--vpc-id $VPC_ID \
--query GroupId \
--output text)

fi

echo "BACKEND SG: $BACKEND_SG"


echo "BACKEND SG: $BACKEND_SG"

echo "Adding Security Group Rules..."


# VPN Rules
aws ec2 authorize-security-group-ingress \
--group-id $VPN_SG \
--protocol tcp \
--port 22 \
--cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
--group-id $VPN_SG \
--protocol udp \
--port 1194 \
--cidr 0.0.0.0/0


# Squid Rules
aws ec2 authorize-security-group-ingress \
--group-id $SQUID_SG \
--protocol tcp \
--port 22 \
--cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
--group-id $SQUID_SG \
--protocol tcp \
--port 3128 \
--cidr 0.0.0.0/0


# Reverse Proxy Rules
aws ec2 authorize-security-group-ingress \
--group-id $REVERSE_SG \
--protocol tcp \
--port 22 \
--cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
--group-id $REVERSE_SG \
--protocol tcp \
--port 80 \
--cidr 0.0.0.0/0



# Frontend only from Reverse Proxy

aws ec2 authorize-security-group-ingress \
--group-id $FRONTEND_SG \
--protocol tcp \
--port 80 \
--source-group $REVERSE_SG

# Backend only from Reverse Proxy

aws ec2 authorize-security-group-ingress \
--group-id $BACKEND_SG \
--protocol tcp \
--port 8000 \
--source-group $REVERSE_SG

echo "Security Rules Added"

echo "Security Groups Created Successfully"
