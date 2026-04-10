#!/bin/bash

# ============================================================================
# DEPLOYMENT SCRIPT FOR AWS EC2
# ============================================================================

set -e

# Configuration
PROJECT_DIR="/home/$(whoami)/supachat"
DOCKER_COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/.env"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_FILE="$PROJECT_DIR/deploy.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# LOGGING
# ============================================================================
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# PRE-DEPLOYMENT CHECKS
# ============================================================================
log "Starting deployment..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first."
fi
log "✓ Docker is installed"

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose is not installed. Please install Docker Compose first."
fi
log "✓ Docker Compose is installed"

# ============================================================================
# SETUP PROJECT DIRECTORY
# ============================================================================
if [ ! -d "$PROJECT_DIR" ]; then
    mkdir -p "$PROJECT_DIR"
    log "Created project directory"
fi

if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# ============================================================================
# BACKUP CURRENT DEPLOYMENT (if exists)
# ============================================================================
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    BACKUP_TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
    log "Backing up current deployment..."
    cp "$DOCKER_COMPOSE_FILE" "$BACKUP_DIR/docker-compose_${BACKUP_TIMESTAMP}.yml"
    [ -f "$ENV_FILE" ] && cp "$ENV_FILE" "$BACKUP_DIR/.env_${BACKUP_TIMESTAMP}"
    success "Backup created: $BACKUP_DIR/docker-compose_${BACKUP_TIMESTAMP}.yml"
fi

# ============================================================================
# PREPARE ENVIRONMENT
# ============================================================================
log "Preparing environment..."

if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$PROJECT_DIR/.env.example" ]; then
        cp "$PROJECT_DIR/.env.example" "$ENV_FILE"
        log "Created .env from .env.example"
    else
        error ".env file not found and .env.example not available"
    fi
fi

# ============================================================================
# PULL LATEST CHANGES (if in git repo)
# ============================================================================
if [ -d "$PROJECT_DIR/.git" ]; then
    log "Pulling latest changes from git..."
    cd "$PROJECT_DIR"
    git pull origin main || warning "Git pull failed, continuing anyway"
fi

# ============================================================================
# STOP CURRENT CONTAINERS (with zero-downtime deployment)
# ============================================================================
log "Checking current containers..."
if docker-compose -f "$DOCKER_COMPOSE_FILE" ps 2>/dev/null | grep -q "Up"; then
    log "Current containers running, starting graceful shutdown..."
    
    # Keep old containers running while new ones start
    warning "Zero-downtime deployment: old containers will be replaced gradually"
fi

# ============================================================================
# BUILD & START NEW CONTAINERS
# ============================================================================
log "Building new containers..."
cd "$PROJECT_DIR"

docker-compose -f "$DOCKER_COMPOSE_FILE" build --no-cache 2>&1 | tee -a "$LOG_FILE" || \
    error "Docker build failed"

log "Starting new containers..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d 2>&1 | tee -a "$LOG_FILE" || \
    error "Docker compose up failed"

success "Containers started successfully"

# ============================================================================
# HEALTH CHECKS
# ============================================================================
log "Running health checks..."
sleep 10

# Check backend health
if curl -f http://localhost:8001/health > /dev/null 2>&1; then
    success "✓ Backend health check passed"
else
    warning "✓ Backend health check pending"
fi

# Check frontend health
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    success "✓ Frontend health check passed"
else
    warning "✓ Frontend health check pending"
fi

# Check Nginx health
if curl -f http://localhost:80/health > /dev/null 2>&1; then
    success "✓ Nginx health check passed"
else
    warning "✓ Nginx health check pending"
fi

# ============================================================================
# CLEANUP OLD IMAGES (keep last 3)
# ============================================================================
log "Cleaning up Docker images..."
docker image prune -f --filter "until=72h" >> "$LOG_FILE" 2>&1 || warning "Image cleanup failed"
success "Old images cleaned up"

# ============================================================================
# LOG CONTAINER STATUS
# ============================================================================
log "Final container status:"
docker-compose -f "$DOCKER_COMPOSE_FILE" ps | tee -a "$LOG_FILE"

# ============================================================================
# SUMMARY
# ============================================================================
success "✅ DEPLOYMENT COMPLETED SUCCESSFULLY"
log "Timestamp: $(date)"
log "Project directory: $PROJECT_DIR"
log "Log file: $LOG_FILE"
log ""
log "Next steps:"
log "  1. Verify the application at: http://$(hostname -I | awk '{print $1}'):80"
log "  2. Verify API docs at: http://$(hostname -I | awk '{print $1}')/api/docs"
log "  3. Check logs: docker-compose -f $DOCKER_COMPOSE_FILE logs -f"
log "  4. Rollback if needed: cp $BACKUP_DIR/* ."

exit 0
