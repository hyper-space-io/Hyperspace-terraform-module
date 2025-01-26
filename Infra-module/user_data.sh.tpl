#!/bin/bash

# Set up logging
LOG_FILE="/var/log/ec2-setup.log"

# Function for logging
log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Function for retry with error logging
retry() {
    local attempts=3
    local cmd="$@"
    local output
    for ((i=1; i<=attempts; i++)); do
        output=$($cmd 2>&1)
        if [ $? -eq 0 ]; then
            return 0
        else
            log "Command '$cmd' failed (Attempt $i/$attempts). Error: $output"
            [ $i -lt $attempts ] && sleep 5
        fi
    done
    return 1
}

log "Starting EC2 setup script"

# Install Docker
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    if ! retry sudo amazon-linux-extras install docker -y; then
        log "Failed to install Docker. Exiting."
        exit 1
    fi
    sudo systemctl enable --now docker || { log "Failed to enable and start Docker."; exit 1; }
    sudo usermod -a -G docker ec2-user || { log "Failed to add ec2-user to docker group."; exit 1; }
else
    log "Docker is already installed. Ensuring Docker service is enabled and started..."
    sudo systemctl enable --now docker || { log "Failed to enable and start Docker."; exit 1; }
fi

# Create and run Terraform Cloud Agent start script
log "Setting up Terraform Cloud Agent..."
cat << 'EOF' > /var/lib/cloud/scripts/per-boot/tfc-agent-start.sh
#!/bin/bash
sudo docker run -d \
    --name=terraform-agent \
    --restart=unless-stopped \
    -e TFC_AGENT_TOKEN=${tfc_agent_token} \
    hashicorp/tfc-agent:latest || echo "Failed to start Terraform Cloud Agent container."
EOF
chmod +x /var/lib/cloud/scripts/per-boot/tfc-agent-start.sh || { log "Failed to make tfc-agent-start.sh executable."; exit 1; }
/var/lib/cloud/scripts/per-boot/tfc-agent-start.sh

# Install AWS CLI v2
# Install AWS CLI v2
log "Installing AWS CLI v2..."
sudo rm -rf /bin/aws
if ! retry curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; then
    log "Failed to download AWS CLI v2. Exiting."
    exit 1
fi
unzip awscliv2.zip || { log "Failed to unzip AWS CLI package."; exit 1; }
sudo ./aws/install --bin-dir /bin --install-dir /usr/local/aws-cli || { log "Failed to install AWS CLI."; exit 1; }

# Cleanup
log "Cleaning up..."
rm -rf awscliv2.zip aws || log "Warning: Cleanup of AWS CLI installation files failed."
log "EC2 setup script completed"