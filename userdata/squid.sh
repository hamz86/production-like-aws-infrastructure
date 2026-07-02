#!/bin/bash

apt update -y

apt install -y squid

cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

cat > /etc/squid/squid.conf <<EOF
http_port 3128

acl all src all
http_access allow all

visible_hostname squid-proxy

cache_mem 256 MB
maximum_object_size 100 MB

access_log /var/log/squid/access.log

EOF

systemctl enable squid

systemctl restart squid
