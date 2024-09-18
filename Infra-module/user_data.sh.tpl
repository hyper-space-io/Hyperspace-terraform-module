#!/bin/bash
if ! command -v docker &> /dev/null; then
  amazon-linux-extras install docker -y
  service docker start
  systemctl enable docker
  usermod -a -G docker ec2-user
else
  service docker start
fi
systemctl enable docker
cat << 'EOF' > /var/lib/cloud/scripts/per-boot/tfc-agent-start.sh
#!/bin/bash
if [ $(docker ps -q -f name=terraform-agent) ]; then
  echo "Terraform Cloud Agent is already running"
else
  docker rm -f terraform-agent || true
  docker run -d \
    --name=terraform-agent \
    --restart=unless-stopped \
    -e TFC_AGENT_TOKEN=${tfc_agent_token} \
    hashicorp/tfc-agent:latest
fi
EOF
chmod +x /var/lib/cloud/scripts/per-boot/tfc-agent-start.sh
/var/lib/cloud/scripts/per-boot/tfc-agent-start.sh
