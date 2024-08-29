# Fetch Terraform Cloud IP ranges using the HTTP data source
data "http" "terraform_cloud_ip_ranges" {
  url = "https://api.hashicorp.com/terraform-cloud-ip-ranges/v1"

  request_headers = {
    Accept = "application/json"
  }
}

# Parse the JSON response to extract the "ip_ranges" object
locals {
  terraform_cloud_ip_ranges = jsondecode(data.http.terraform_cloud_ip_ranges.response_body)["ip_ranges"]["hashicorp"]
}

# Security group allowing ingress and egress to Terraform Cloud IP ranges only
resource "aws_security_group" "agent_sg" {
  name        = "terraform-agent-sg"
  description = "Security group for EC2 instances running Terraform Cloud agents"
  vpc_id      = module.vpc.vpc_id

  # Ingress rules to allow SSH access from Terraform Cloud IP ranges
  dynamic "ingress" {
    for_each = local.terraform_cloud_ip_ranges
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Egress rules to allow traffic only to Terraform Cloud IP ranges
  dynamic "egress" {
    for_each = local.terraform_cloud_ip_ranges
    content {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [egress.value]
    }
  }
}

# Data source to fetch the latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Amazon Linux 2 AMI
  }
}

# EC2 instance with Docker and Terraform Cloud Agent
resource "aws_instance" "terraform_agent" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.agent_sg.id]

  # User data script to install Docker and run Terraform Cloud Agent in a Docker container
  user_data = <<-EOF
                #!/bin/bash
                # Install Docker
                yum update -y
                amazon-linux-extras install docker -y
                service docker start
                usermod -a -G docker ec2-user
                # Run the Terraform Cloud Agent Docker container
                docker run -d --name tfc-agent \
                  -e TFC_AGENT_TOKEN="${var.agent_token}" \
                  -e TFC_AGENT_NAME="agen1" \
                  hashicorp/tfc-agent:latest
              EOF

  tags = {
    Name = "Terraform Cloud Agent"
  }
}
