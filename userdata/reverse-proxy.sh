#!/bin/bash

apt update -y

apt install -y nginx

systemctl enable nginx


cat > /etc/nginx/sites-available/default <<EOF
server {

    listen 80 default_server;

    server_name _;


    location /api {

        proxy_pass http://BACKEND_PRIVATE_IP:8000;

        proxy_set_header Host \$host;

        proxy_set_header X-Real-IP \$remote_addr;

    }


    location / {

        proxy_pass http://FRONTEND_PRIVATE_IP;

        proxy_set_header Host \$host;

        proxy_set_header X-Real-IP \$remote_addr;

    }

}
EOF


nginx -t

systemctl restart nginx
