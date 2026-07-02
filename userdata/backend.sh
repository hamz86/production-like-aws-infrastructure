#!/bin/bash

apt update -y

apt install -y python3 python3-pip python3-venv


mkdir -p /opt/backend

cd /opt/backend


python3 -m venv venv

source venv/bin/activate


pip install fastapi uvicorn


cat > /opt/backend/main.py <<EOF
from fastapi import FastAPI

app = FastAPI()


@app.get("/api")
def api():
    return {
        "message": "Backend FastAPI running successfully",
        "server": "AWS EC2"
    }
EOF



cat > /etc/systemd/system/fastapi.service <<EOF
[Unit]
Description=FastAPI Application
After=network.target


[Service]
User=root
WorkingDirectory=/opt/backend
ExecStart=/opt/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always


[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload

systemctl enable fastapi

systemctl start fastapi
