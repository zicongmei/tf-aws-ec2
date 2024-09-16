

module "ec2_module" {
  source    = "../module"
  user_data = local.user_data
  name      = var.name
  ipv4block = var.ipv4block
  ipv6block = var.ipv6block
  instance_type = "g4dn.xlarge"
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

EOT

}
