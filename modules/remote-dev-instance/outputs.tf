# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.dev.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = var.use_elastic_ip ? aws_eip.dev[0].public_ip : aws_instance.dev.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.dev.private_ip
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_instance.dev.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ubuntu@${var.use_elastic_ip ? aws_eip.dev[0].public_ip : aws_instance.dev.public_ip}"
}

output "vscode_ssh_config" {
  description = "VS Code SSH config entry"
  value       = <<-EOF
    Host remote-dev
      HostName ${var.use_elastic_ip ? aws_eip.dev[0].public_ip : aws_instance.dev.public_ip}
      User ubuntu
      IdentityFile ${replace(var.ssh_public_key_path, ".pub", "")}
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
  EOF
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.dev.id
}

output "key_pair_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.dev.key_name
}

output "ami_id" {
  description = "ID of the AMI used"
  value       = data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "Name of the AMI used"
  value       = data.aws_ami.ubuntu.name
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_instance.dev.availability_zone
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = data.aws_subnet.selected.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.default.id
}

output "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  value       = local.my_ip
}
