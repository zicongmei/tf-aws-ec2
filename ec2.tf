locals {
  instance_type = "g4dn.xlarge"
  ami           = "Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.3.0 (Ubuntu 20.04) 20240825"
  ami_type      = "hvm"
  ami_owner     = "898082745236"
  volume_type   = "gp3"
  volume_size   = 300
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
    description      = "port 80 for nginx"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["${chomp(data.http.myip.response_body)}/32"]
    # cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "port 443 for nginx"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["${chomp(data.http.myip.response_body)}/32"]
    # cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "port 7860 for UI"
    from_port        = 7860
    to_port          = 7860
    protocol         = "tcp"
    cidr_blocks      = ["${chomp(data.http.myip.response_body)}/32"]
    # cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "port 22 for ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["${chomp(data.http.myip.response_body)}/32"]
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
apt update
apt -qqy install nginx apache2-utils --no-install-recommends
apt -qqy install google-perftools libgoogle-perftools-dev --no-install-recommends
add-apt-repository ppa:deadsnakes/ppa
apt update
apt install python3.11 python3.11-venv


mkdir /cert
pushd /cert
openssl req -x509 -newkey rsa:4096 \
  -keyout key.pem \
  -out cert.pem \
  -sha256 -days 3650 \
  -nodes -subj "/C=US/ST=NY/L=Rochester/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
popd

cat << EOF > /etc/nginx/sites-enabled/default
server {
  listen       80;
  server_name  127.0.0.1;
  location / {
    proxy_pass         http://127.0.0.1:7860/;
    #proxy_redirect     off;
    proxy_buffering off;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;
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
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;
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


EOT

  tags = { Name = "${local.name}-public-ec2" }
}

