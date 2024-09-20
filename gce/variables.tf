
variable "name" {
  description = "instance name"
  type        = string
}

variable "hg_token" {
  type = string
}

variable "sshkey" {
  type = string
}

variable "gcp_region" {
  type = string
  default = "us-central1"
}


variable "gcp_zone" {
  type = string
  default = "us-central1-b"
}
variable "gcp_project_id" {
  type = string
}

