locals {
  #instance_type = "g4dn.xlarge"
  # instance_type = "t3.nano"
  instance_type = "g6.xlarge"
  ami           = "Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.3.0 (Ubuntu 20.04) 20240825"
  ami_type      = "hvm"
  ami_owner     = "898082745236"
  volume_type   = "gp3"
  volume_size   = 300
}

locals {
  dollar = "$"
}

resource "aws_key_pair" "this" {
  key_name   = "${local.name}-keypair"
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}

data "aws_ami" "this" {
  filter {
    name   = "name"
    values = [local.ami]
  }
  filter {
    name   = "virtualization-type"
    values = [local.ami_type]
  }
  owners      = [local.ami_owner]
  most_recent = true
}

resource "aws_security_group" "public" {
  name        = "${local.name}-public-ec2-sg"
  description = "security group for public EC2 "
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "port 80 for nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      "${chomp(data.http.myip.response_body)}/32",
      var.ipv4block,
    ]
    # cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = [var.ipv6block]
  }

  ingress {
    description = "port 443 for nginx"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      "${chomp(data.http.myip.response_body)}/32",
      var.ipv4block,
    ]
    ipv6_cidr_blocks = [var.ipv6block]
    # cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "port 22 for ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "${chomp(data.http.myip.response_body)}/32",
      var.ipv4block,
    ]
    ipv6_cidr_blocks = [var.ipv6block]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${local.name}-public-ec2-sg" }
}


resource "aws_instance" "public" {
  ami           = data.aws_ami.this.id
  instance_type = local.instance_type
  key_name      = aws_key_pair.this.key_name

  subnet_id = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.public.id]

  root_block_device {
    volume_type = local.volume_type
    volume_size = local.volume_size
  }

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
  location / {
    proxy_pass         http://127.0.0.1:7860/;
    #proxy_redirect     off;
    proxy_buffering off;
    proxy_set_header X-Real-IP \${local.dollar}remote_addr;
    proxy_set_header X-Forwarded-Host \${local.dollar}host;
    proxy_set_header X-Forwarded-Port \${local.dollar}server_port;

    # WebSocket support
    proxy_http_version 1.1;
    proxy_set_header Upgrade \${local.dollar}http_upgrade;
    proxy_set_header Connection "upgrade";
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

# webui
useradd -m webui
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

su webui -c 'huggingface-cli download stabilityai/stable-diffusion-xl-refiner-1.0 sd_xl_refiner_1.0_0.9vae.safetensors \
  --local-dir /home/webui/stable-diffusion-webui/models/Stable-diffusion'

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

  tags = { Name = "${local.name}-public-ec2" }
}

