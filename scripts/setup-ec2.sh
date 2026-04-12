#!/bin/bash
# ============================================================================
# EC2 FIRST-TIME SETUP SCRIPT
# Run once on a fresh Ubuntu 22.04 EC2 instance.
# Usage: bash scripts/setup-ec2.sh
# ============================================================================
set -e

REPO_URL="https://github.com/SoumyaPratik12/SupaChat-live.git"
INSTALL_DIR="$HOME/SupaChat-live"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC} $1"; exit 1; }

log "Starting EC2 setup for SupaChat..."

# ── System update ─────────────────────────────────────────────────────────────
log "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
ok "System updated"

# ── Install Docker ────────────────────────────────────────────────────────────
log "Installing Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  ok "Docker installed"
else
  ok "Docker already installed: $(docker --version)"
fi

# ── Install Docker Compose v2 plugin ─────────────────────────────────────────
log "Installing Docker Compose..."
if ! docker compose version &>/dev/null 2>&1; then
  COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
  sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null || \
  sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null || \
  sudo chmod +x /usr/local/bin/docker-compose
  ok "Docker Compose installed"
else
  ok "Docker Compose already installed: $(docker compose version)"
fi

# ── Install utilities ─────────────────────────────────────────────────────────
log "Installing utilities..."
sudo apt-get install -y -qq git curl wget htop unzip
ok "Utilities installed"

# ── Clone repository ──────────────────────────────────────────────────────────
log "Setting up repository..."
if [ ! -d "$INSTALL_DIR/.git" ]; then
  git clone "$REPO_URL" "$INSTALL_DIR"
  ok "Repository cloned to $INSTALL_DIR"
else
  cd "$INSTALL_DIR"
  git fetch origin main
  git reset --hard origin/main
  ok "Repository updated"
fi

cd "$INSTALL_DIR"

# ── Create .env ───────────────────────────────────────────────────────────────
if [ ! -f .env ]; then
  cp .env.example .env
  warn "⚠️  .env created from template — edit with your Supabase credentials:"
  warn "   nano $INSTALL_DIR/.env"
  warn "   Then run: docker compose up -d --build"
fi

# ── Configure firewall ────────────────────────────────────────────────────────
log "Configuring UFW firewall..."
sudo ufw allow 22/tcp   comment "SSH"
sudo ufw allow 80/tcp   comment "HTTP"
sudo ufw allow 443/tcp  comment "HTTPS"
sudo ufw allow 3001/tcp comment "Grafana"
sudo ufw allow 9090/tcp comment "Prometheus"
sudo ufw --force enable
ok "Firewall configured"

# ── Systemd service for auto-start on reboot ──────────────────────────────────
log "Creating systemd service..."
sudo tee /etc/systemd/system/supachat.service > /dev/null <<EOF
[Unit]
Description=SupaChat Application
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$INSTALL_DIR
ExecStart=/bin/bash -c 'docker compose up -d || docker-compose up -d'
ExecStop=/bin/bash -c 'docker compose down || docker-compose down'
Restart=on-failure
RestartSec=10
User=$USER

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable supachat.service
ok "Systemd service created and enabled (auto-starts on reboot)"

# ── Log rotation ──────────────────────────────────────────────────────────────
sudo tee /etc/logrotate.d/supachat > /dev/null <<EOF
$INSTALL_DIR/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    missingok
    create 0640 $USER $USER
}
EOF
ok "Log rotation configured"

# ── Summary ───────────────────────────────────────────────────────────────────
PUBLIC_IP=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
ok "✅ EC2 SETUP COMPLETE"
echo ""
echo "Next steps:"
echo "  1. Add Supabase credentials:  nano $INSTALL_DIR/.env"
echo "  2. Start the app:             cd $INSTALL_DIR && docker compose up -d --build"
echo "  3. Verify monitoring:         bash $INSTALL_DIR/scripts/setup-monitoring.sh localhost"
echo ""
echo "Access URLs (after docker compose up):"
echo "  App:        http://$PUBLIC_IP"
echo "  API Docs:   http://$PUBLIC_IP/api/docs"
echo "  Grafana:    http://$PUBLIC_IP:3001  (admin/admin)"
echo "  Prometheus: http://$PUBLIC_IP:9090"
echo ""
echo "If app is not publicly accessible, run:"
echo "  bash $INSTALL_DIR/scripts/aws-network-fix.sh $PUBLIC_IP"
