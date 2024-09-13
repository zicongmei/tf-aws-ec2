
variable "name" {
  description = "instance name"
  type        = string
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

variable "hg_token" {
  type = string
}

variable "ipv4block" {
  type = string
}
variable "ipv6block" {
  type = string
}

