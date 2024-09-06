
variable "name" {
  description = "instance name"
  type        = string
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}