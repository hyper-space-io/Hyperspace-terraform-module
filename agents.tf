# Fetch the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Amazon Linux 2 AMI
  }
}

# Use the terraform-aws-ec2-agent-pool module
module "terraform_cloud_agents" {
  source            = "glenngillen/ec2-agent-pool/aws"
  version           = "1.0.6"
  # Required Parameters
  name              = "terraform-agent-pool"
  org_name          = "Hyperspace_project" # Replace with your Terraform Cloud organization name
  image_id          = data.aws_ami.amazon_linux.id # Dynamically fetched AMI ID
  ip_cidr_vpc       = module.vpc.vpc_cidr
  ip_cidr_agent_subnet = module.vpc.vpc_cidr
  desired_count     = 1
  max_agents        = 2

  tags = {
    Name = "Terraform Cloud Agent Pool"
  }
}