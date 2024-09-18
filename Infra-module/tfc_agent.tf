# TFC AGENT
resource "aws_instance" "tfc_agent" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.tfc_agent_sg.id]
  user_data = templatefile("user_data.sh.tpl", {
    tfc_agent_token = var.tfc_agent_token
  })
  tags = {
    Name = "tfc-agent"
  }
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    delete_on_termination = true
  }
}


resource "aws_security_group" "tfc_agent_sg" {
  name        = "tfc-agent-sg"
  description = "Security group for Terraform Cloud Agent"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.vpc_cidr
  }
}