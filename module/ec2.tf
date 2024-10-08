locals {
  #instance_type = "g4dn.xlarge"
  # instance_type = "t3.nano"
  instance_type = var.instance_type
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

  user_data = var.user_data

  tags = { Name = "${local.name}-public-ec2" }
}

