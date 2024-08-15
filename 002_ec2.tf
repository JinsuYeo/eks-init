#########################################################################################################
## Create keypair for ec2
#########################################################################################################
resource "tls_private_key" "ecom-pk-cli" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ecom-kp-cli" {
  key_name   = "ecom-kp-cli"
  public_key = tls_private_key.ecom-pk-cli.public_key_openssh
}

# Download key file in local
resource "local_file" "ssh-key" {
  filename        = "${var.pem_location}/ecom-pk-cli.pem"
  content         = tls_private_key.ecom-pk-cli.private_key_pem
  file_permission = "0400"
}

# resource "local_file" "ssh-key-back" {
#   filename        = "cwave.pem"
#   content         = tls_private_key.cwave-pk.private_key_pem
#   file_permission = "0400"
# }

output "pem_location" {
  value = local_file.ssh-key.filename
}

#########################################################################################################
## Create ec2 instance for Bastion
#########################################################################################################
resource "aws_iam_instance_profile" "ec2_cli_profile" {
  name = "ec2_cli_profile_allow_ssm"
  role = aws_iam_role.ecom-role-ec2cli.name
}

resource "aws_instance" "ecom-ec2-cli" {
  ami           = "ami-0c2acfcb2ac4d02a0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.ecom-sub-pri01.id

  iam_instance_profile = aws_iam_instance_profile.ec2_cli_profile.name
  key_name             = aws_key_pair.ecom-kp-cli.key_name
  vpc_security_group_ids = [
    aws_security_group.ecom-sg-cli.id
  ]

  user_data = <<-EOF
  #!/bin/bash
  set -euo pipefail
  PLATFORM=Linux_amd64
  curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
  curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
  tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
  sudo mv /tmp/eksctl /usr/local/bin
  dnf install docker -y
  . <(eksctl completion bash)
  curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  cp ./kubectl /usr/local/bin
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "ecom-ec2-cli"
  }
}