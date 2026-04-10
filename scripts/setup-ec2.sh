#!/bin/bash

# ============================================================================
# SETUP SCRIPT FOR AWS EC2 INSTANCE
# Run this script on a fresh Ubuntu EC2 instance to set up SupaChat
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

log "Starting EC2 setup for SupaChat..."

# ============================================================================
# UPDATE SYSTEM
# ============================================================================
log "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y
success "System updated"

# ============================================================================
# INSTALL DOCKER
# ============================================================================
log "Installing Docker..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
log "Docker installed (user will need to log out and back in)"

# ============================================================================
# INSTALL DOCKER COMPOSE (standalone)
# ============================================================================
log "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
success "Docker Compose installed"

# ============================================================================
# INSTALL GIT
# ============================================================================
log "Installing Git..."
sudo apt-get install -y git
success "Git installed"

# ============================================================================
# INSTALL MONITORING TOOLS
# ============================================================================
log "Installing monitoring tools..."
sudo apt-get install -y htop curl wget
success "Monitoring tools installed"

# ============================================================================
# CLONE REPOSITORY
# ============================================================================
REPO_URL="${1:-https://github.com/your-org/supachat.git}"
INSTALL_DIR="/home/$USER/supachat"

log "Cloning repository..."
git clone "$REPO_URL" "$INSTALL_DIR" || \
    warning "Repository clone failed, assuming code is already present"

cd "$INSTALL_DIR"

# ============================================================================
# CREATE ENVIRONMENT FILE
# ============================================================================
log "Creating environment configuration..."
if [ ! -f .env ]; then
    cp .env.example .env
    log "Environment file created at .env"
    warning "⚠️  IMPORTANT: Edit .env with your Supabase credentials:"
    warning "   nano .env"
fi

# ============================================================================
# START SERVICES
# ============================================================================
log "Starting SupaChat services..."
docker-compose up -d
sleep 15

# ============================================================================
# VERIFY SERVICES
# ============================================================================
log "Verifying services..."
if curl -f http://localhost:8001/health > /dev/null 2>&1; then
    success "✓ Backend is running"
else
    warning "⚠️  Backend health check pending"
fi

if curl -f http://localhost:3000 > /dev/null 2>&1; then
    success "✓ Frontend is running"
else
    warning "⚠️  Frontend health check pending"
fi

# ============================================================================
# SETUP FIREWALL (if using AWS Security Groups, this may not be needed)
# ============================================================================
log "Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 9090/tcp   # Prometheus
sudo ufw allow 3001/tcp   # Grafana
sudo ufw --force enable || warning "Firewall configuration failed"
success "Firewall configured"

# ============================================================================
# SETUP SYSTEMD SERVICE (optional, for auto-start)
# ============================================================================
log "Creating systemd service for auto-start..."
sudo tee /etc/systemd/system/supachat.service > /dev/null <<EOF
[Unit]
Description=SupaChat Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable supachat.service
success "Systemd service created and enabled"

# ============================================================================
# SETUP LOG ROTATION
# ============================================================================
log "Setting up log rotation..."
sudo tee /etc/logrotate.d/supachat > /dev/null <<EOF
$INSTALL_DIR/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 $USER $USER
    sharedscripts
}
EOF

success "Log rotation configured"

# ============================================================================
# FINAL INFORMATION
# ============================================================================
echo ""
success "✅ EC2 SETUP COMPLETED"
echo ""
echo "Next steps:"
echo "  1. Edit environment variables: nano $INSTALL_DIR/.env"
echo "  2. Restart Docker: sudo systemctl restart docker"
echo "  3. Start services: docker-compose up -d"
echo "  4. Access the application:"
echo "     - Frontend: http://$(hostname -I | awk '{print $1}'):80"
echo "     - API Docs: http://$(hostname -I | awk '{print $1}')/api/docs"
echo "     - Backend API: http://$(hostname -I | awk '{print $1}'):8001"
echo "     - Grafana: http://$(hostname -I | awk '{print $1}'):3001 (admin/admin)"
echo "     - Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo ""
echo "Useful commands:"
echo "  docker-compose logs -f              # View all logs"
echo "  docker-compose ps                   # Check service status"
echo "  docker-compose down                 # Stop all services"
echo ""
