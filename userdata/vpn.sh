#!/bin/bash

apt update -y

apt install -y openvpn easy-rsa

make-cadir /etc/openvpn/easy-rsa

cd /etc/openvpn/easy-rsa

./easyrsa init-pki

echo | ./easyrsa build-ca nopass

./easyrsa gen-req server nopass

echo yes | ./easyrsa sign-req server server

./easyrsa gen-dh

openvpn --genkey secret ta.key

cp pki/ca.crt /etc/openvpn/
cp pki/private/server.key /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/dh.pem /etc/openvpn/

cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp
dev tun

ca ca.crt
cert server.crt
key server.key
dh dh.pem

server 10.8.0.0 255.255.255.0

push "redirect-gateway def1 bypass-dhcp"

keepalive 10 120

persist-key
persist-tun

verb 3
EOF


systemctl enable openvpn@server

systemctl restart openvpn@server
