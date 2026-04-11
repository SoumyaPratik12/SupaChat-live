#!/bin/bash
# ============================================================================
# DEPLOYMENT SCRIPT FOR AWS EC2
# ============================================================================
set -e

PROJECT_DIR="/home/$(whoami)/SupaChat-live"
LOG_FILE="$PROJECT_DIR/deploy.log"
BACKUP_DIR="$PROJECT_DIR/backups"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()     { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC} $1"    | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERR]${NC} $1"     | tee -a "$LOG_FILE"; exit 1; }

# ── Pre-flight ────────────────────────────────────────────────────────────────
command -v docker        &>/dev/null || error "Docker not installed"
command -v docker compose &>/dev/null || error "Docker Compose not installed"

mkdir -p "$BACKUP_DIR"
log "Starting deployment..."

# ── Backup current compose file ───────────────────────────────────────────────
if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
  TS=$(date +'%Y%m%d_%H%M%S')
  cp "$PROJECT_DIR/docker-compose.yml" "$BACKUP_DIR/docker-compose_${TS}.yml"
  [ -f "$PROJECT_DIR/.env" ] && cp "$PROJECT_DIR/.env" "$BACKUP_DIR/.env_${TS}"
  success "Backup saved: $BACKUP_DIR/docker-compose_${TS}.yml"
fi

# ── Pull latest code ──────────────────────────────────────────────────────────
cd "$PROJECT_DIR"
git fetch origin main
git reset --hard origin/main
success "Code updated to $(git rev-parse --short HEAD)"

# ── Ensure .env exists ────────────────────────────────────────────────────────
if [ ! -f "$PROJECT_DIR/.env" ]; then
  cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
  warning ".env created from .env.example — fill in credentials"
fi

# ── Build & start containers ──────────────────────────────────────────────────
log "Building and starting containers..."
docker compose up -d --build --remove-orphans 2>&1 | tee -a "$LOG_FILE"
success "Containers started"

# ── Health checks ─────────────────────────────────────────────────────────────
sleep 15
log "Running health checks..."

curl -sf http://localhost/health      && success "✓ Nginx"    || warning "Nginx pending"
curl -sf http://localhost:8001/health && success "✓ Backend"  || warning "Backend pending"
curl -sf http://localhost:3000        && success "✓ Frontend" || warning "Frontend pending"
curl -sf http://localhost:9090/-/healthy && success "✓ Prometheus" || warning "Prometheus pending"

# ── Cleanup ───────────────────────────────────────────────────────────────────
docker image prune -f >> "$LOG_FILE" 2>&1
log "Container status:"
docker compose ps | tee -a "$LOG_FILE"

success "✅ DEPLOYMENT COMPLETE — $(date)"
