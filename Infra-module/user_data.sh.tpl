#!/bin/bash
amazon-linux-extras install docker -y
service docker start
usermod -a -G docker ec2-user

# Run Terraform Cloud Agent
docker run -d \
  --name=terraform-agent \
  -e TFC_AGENT_TOKEN=${agent_token} \
  hashicorp/tfc-agent:latest
