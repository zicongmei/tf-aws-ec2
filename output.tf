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


#output "lb" {
#  description = "ALB address"
#  value       = aws_lb.alb.dns_name
#}