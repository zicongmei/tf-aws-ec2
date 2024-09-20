
output "ssh_public" {
  description = "ssh to public instance"
  value       = "ssh zicong_google_com@nic0.${var.name}.${var.gcp_zone}.c.${var.gcp_project_id}.internal.gcpnode.com"
}

output "ssh_tunnel" {
  description = "ssh tunnel"
  value       = "ssh -N -L 8443:127.0.0.1:443 zicong_google_com@nic0.${var.name}.${var.gcp_zone}.c.${var.gcp_project_id}.internal.gcpnode.com"
}
