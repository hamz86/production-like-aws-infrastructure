#!/bin/bash

apt update -y

apt install -y nginx

systemctl enable nginx


cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
<title>AWS Frontend Server</title>
</head>

<body>

<h1>AWS Infrastructure Project</h1>

<h2>Frontend NGINX Server Running Successfully</h2>

<p>This page is served from EC2 Frontend Instance.</p>

</body>
</html>
EOF


systemctl restart nginx
