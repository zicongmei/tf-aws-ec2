output "public_ip" {
  description = "Public ip"
  value       = aws_instance.public.public_ip
}

output "public_internal_ip" {
  description = "Internal ip of public instance"
  value       = aws_instance.public.private_ip
}

output "ssh_public" {
  description = "ssh to public instance"
  value       = "ssh -o'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' ubuntu@${aws_instance.public.public_ip}"
}

output "ssh_tunnel" {
  description = "ssh tunnel"
  value       = "ssh -N -L 7860:127.0.0.1:7860 ubuntu@${aws_instance.public.public_ip}"
}

