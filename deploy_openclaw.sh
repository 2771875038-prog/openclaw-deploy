#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting OpenClaw Deployment...${NC}"

# 1. System Update & Dependencies
echo -e "${GREEN}[1/5] Updating system packages...${NC}"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl git python3-pip

# 2. Configure Swap (2GB) to prevent OOM
echo -e "${GREEN}[2/5] Configuring Swap space...${NC}"
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "Swap created successfully."
else
    echo "Swap file already exists."
fi

# 3. Install Docker & Docker Compose
echo -e "${GREEN}[3/5] Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "Docker installed."
else
    echo "Docker already installed."
fi

# 4. Setup Project Structure & Source Code
echo -e "${GREEN}[4/5] Setting up project files & cloning source...${NC}"

# Use script directory as deployment root
DEPLOY_DIR=$(dirname "$(readlink -f "$0")")
echo "Deploying in: $DEPLOY_DIR"

mkdir -p "$DEPLOY_DIR"/{config,workspace,redis_data}

# Fix ownership of the deployment directory to current user
echo -e "${GREEN}Fixing permissions...${NC}"
sudo chown -R $USER:$USER "$DEPLOY_DIR"

# Configure git safety just in case
git config --global --add safe.directory "$DEPLOY_DIR/source"
git config --global --add safe.directory "*"

# Check if source code exists (uploaded from local)
if [ ! -d "$DEPLOY_DIR/source" ]; then
    echo -e "${GREEN}Source code not found. Attempting to clone...${NC}"
    git clone https://github.com/openclaw/openclaw.git "$DEPLOY_DIR/source"
else
    echo -e "${GREEN}Using existing source code in $DEPLOY_DIR/source${NC}"
fi

# Files are already in DEPLOY_DIR, skipping cp commands
# cp docker-compose.yml ~/openclaw-deploy/
# cp arbitrage_monitor.py ~/openclaw-deploy/
# cp Dockerfile.monitor ~/openclaw-deploy/

# Generate secure token
if [ ! -f "$DEPLOY_DIR/.env" ]; then
    echo "OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)" > "$DEPLOY_DIR/.env"
fi

# Check for Telegram Config
# Force update keys to ensure they are correct (remove old entries first)
if [ -f "$DEPLOY_DIR/.env" ]; then
    sed -i '/TELEGRAM_BOT_TOKEN/d' "$DEPLOY_DIR/.env"
    sed -i '/TELEGRAM_CHAT_ID/d' "$DEPLOY_DIR/.env"
    sed -i '/GEMINI_API_KEY/d' "$DEPLOY_DIR/.env"
fi

echo "TELEGRAM_BOT_TOKEN=8605005604:AAEpeE6N8fIruOBPRN842rO9YGMcMK48Utg" >> "$DEPLOY_DIR/.env"
echo "TELEGRAM_CHAT_ID=8363729701" >> "$DEPLOY_DIR/.env"
echo "GEMINI_API_KEY=AIzaSyCwjn8Tey4fxeNzmHNzKA9WF4vH6ixBIcA" >> "$DEPLOY_DIR/.env"
echo -e "${GREEN}Telegram & Gemini Keys Updated.${NC}"

# 5. Build and Start

# 5. Build and Start
echo -e "${GREEN}[5/5] Building and starting services...${NC}"
cd "$DEPLOY_DIR"

# Cleanup conflicting containers if they exist
echo -e "${GREEN}Cleaning up old containers...${NC}"
# Stop and remove containers explicitly (Using sudo to fix permission denied)
containers=("openclaw-redis" "openclaw-gateway" "arbitrage-monitor")
for container in "${containers[@]}"; do
    if sudo docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "Removing existing container: $container"
        sudo docker rm -f "$container" || echo "Warning: Failed to remove $container"
    fi
done

# Also run compose down to clean up networks and other resources
sudo docker compose down --remove-orphans || true

# Force build since we don't have a pre-built image
sudo docker compose up -d --build

echo -e "${GREEN}Deployment Complete!${NC}"
echo "---------------------------------------------------"
echo "Gateway running on: http://<YOUR_SERVER_IP>:18789"
echo "Important: You MUST open Port 18789 in your Cloud Security Group!"
echo "---------------------------------------------------"
echo "Your Access Token (Save this!):"
cat .env | grep OPENCLAW_GATEWAY_TOKEN
echo "---------------------------------------------------"
echo "Monitor running in background."
