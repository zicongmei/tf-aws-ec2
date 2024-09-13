

module "sdui" {
  source    = "../module"
  user_data = local.user_data
  name      = var.name
  ipv4block = var.ipv4block
  ipv6block = var.ipv6block
}


locals {
  dollar    = "$"
  user_data = <<EOT
#!/bin/bash
set -x

apt_cmds(){
  add-apt-repository ppa:deadsnakes/ppa && \
  apt update && \
  apt -qqy install nginx apache2-utils \
    google-perftools libgoogle-perftools-dev \
    python3.11 python3.11-venv python3-venv python3-pip --no-install-recommends
}

apt_cmds

while [[ $? -ne 0 ]]; do
  date
  sleep 3
  apt_cmds
done

echo "
${var.sshkey}" >> /home/ubuntu/.ssh/authorized_keys

mkdir /cert
chmod  0755 /cert
pushd /cert
openssl req -x509 -newkey rsa:4096 \
  -keyout key.pem \
  -out cert.pem \
  -sha256 -days 3650 \
  -nodes -subj "/C=US/ST=NY/L=Rochester/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
popd

cat << EOF > /etc/nginx/sites-enabled/default
server {
  listen  80 default_server;
  listen  [::]:80 default_server;
  server_name localhost;

  location / {
      return 301 https://\${local.dollar}host\${local.dollar}request_uri;
  }
}

server {
  listen              443 ssl;
  server_name         www.example.com;
  ssl_certificate     /cert/cert.pem;
  ssl_certificate_key /cert/key.pem;
  ssl_protocols       TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
  ssl_ciphers         HIGH:!aNULL:!MD5;
   
  proxy_buffering off;
  proxy_set_header X-Real-IP \${local.dollar}remote_addr;
  proxy_set_header X-Forwarded-Host \${local.dollar}host;
  proxy_set_header X-Forwarded-Port \${local.dollar}server_port;

  # WebSocket support
  proxy_http_version 1.1;
  proxy_set_header Upgrade \${local.dollar}http_upgrade;
  proxy_set_header Connection "upgrade";
  
  location / {
    proxy_pass         http://127.0.0.1:7861/;
  }
  location /img/ {
    proxy_pass         http://127.0.0.1:7860/;
  }
}
EOF

systemctl enable nginx
systemctl restart nginx

# install github
(type -p wget >/dev/null || ( apt update &&  apt-get install wget -y)) \
  &&  mkdir -p -m 755 /etc/apt/keyrings \
  && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg |  tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  &&  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |  tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  &&  apt update \
  &&  apt install gh -y
git config --global core.editor "vim"


# hugging face
pip install -U "huggingface_hub[cli]"
echo ${var.hg_token} > /cert/hg_token
huggingface-cli login --token ${var.hg_token} 

# cahtbot webui
mkdir /root
cd /root
git clone https://github.com/oobabooga/text-generation-webui.git

cd /root/text-generation-webui
python3.11 -m venv venv

cat << EOF > /root/start_chat_bit.sh
#!/bin/bash
set -ex

cd /root/text-generation-webui
source /root/text-generation-webui/venv/bin/activate
pip install -r requirements.txt
python /root/text-generation-webui/server.py --listen --listen-port 7861
EOF


cat << EOF > /lib/systemd/system/chatbot.service
[Unit]
Description=chatbot web ui
After=network.target

[Service]
Type=simple
ExecStart=bash /root/start_chat_bit.sh
TimeoutStopSec=5
KillMode=mixed
TimeoutSec=60

[Install]
WantedBy=multi-user.target
EOF
systemctl enable chatbot
systemctl start chatbot 

# sd webUI
useradd -m webui
cd /home/webui
cd /home/webui
su webui -c 'git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git'
cd stable-diffusion-webui
su webui -c 'python3.11 -m venv venv'

cat << EOF > /lib/systemd/system/webui.service
[Unit]
Description=web ui
After=network.target

[Service]
Type=simple
ExecStart=/home/webui/stable-diffusion-webui/webui.sh --listen
TimeoutStopSec=5
KillMode=mixed
User=webui
Group=webui
TimeoutSec=60

[Install]
WantedBy=multi-user.target
EOF
systemctl enable webui
systemctl start webui 

su webui -c 'huggingface-cli login --token ${var.hg_token}'

su webui -c 'huggingface-cli download stabilityai/stable-diffusion-xl-base-1.0 sd_xl_base_1.0_0.9vae.safetensors \
  --local-dir /home/webui/stable-diffusion-webui/models/Stable-diffusion'

su webui -c 'huggingface-cli download stabilityai/stable-diffusion-xl-base-1.0  sd_xl_base_1.0.safetensors \
  --local-dir /home/webui/stable-diffusion-webui/models/Stable-diffusion'

su webui -c 'huggingface-cli download stabilityai/stable-diffusion-3-medium sd3_medium_incl_clips.safetensors \
  --local-dir /home/webui/stable-diffusion-webui/models/Stable-diffusion'

su webui -c 'huggingface-cli download stabilityai/stable-diffusion-3-medium sd3_medium_incl_clips_t5xxlfp16.safetensors \
  --local-dir /home/webui/stable-diffusion-webui/models/Stable-diffusion'

su webui -c 'huggingface-cli download stabilityai/stable-diffusion-3-medium sd3_medium_incl_clips_t5xxlfp8.safetensors \
  --local-dir /home/webui/stable-diffusion-webui/models/Stable-diffusion'

su webui -c 'huggingface-cli download stabilityai/stable-diffusion-3-medium text_encoders/t5xxl_fp16.safetensors \
  --local-dir /home/webui/stable-diffusion-webui/models/Stable-diffusion'

EOT

}
