output "public_ip" {
  description = "Public ip"
  value       = module.ec2_module.public_ip
}

output "ssh_public" {
  description = "ssh to public instance"
  value       = "ssh -o'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' ubuntu@${module.ec2_module.public_ip}"
}

output "ssh_tunnel" {
  description = "ssh tunnel"
  value       = "ssh -N -L 7860:127.0.0.1:7860 ubuntu@${module.ec2_module.public_ip}"
}

