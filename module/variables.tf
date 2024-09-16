
variable "name" {
  description = "instance name"
  type        = string
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}


variable "ipv4block" {
  type = string
}
variable "ipv6block" {
  type = string
}

variable "user_data" {
  type = string
}

variable "instance_type" {
  type = string
  default = "g6.xlarge"
}
