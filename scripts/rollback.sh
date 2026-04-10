#!/bin/bash

# ============================================================================
# ROLLBACK SCRIPT - Restore Previous Deployment
# ============================================================================

set -e

PROJECT_DIR="${1:-.}"
BACKUP_DIR="$PROJECT_DIR/backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

log "SupaChat Rollback Script"
log "Project directory: $PROJECT_DIR"
echo ""

# ============================================================================
# LIST AVAILABLE BACKUPS
# ============================================================================
if [ ! -d "$BACKUP_DIR" ]; then
    error "No backups directory found at: $BACKUP_DIR"
fi

log "Available backups:"
echo "─────────────────────────"

BACKUPS=($(ls -t "$BACKUP_DIR"/docker-compose_*.yml 2>/dev/null || echo ""))

if [ ${#BACKUPS[@]} -eq 0 ]; then
    error "No backups found"
fi

for i in "${!BACKUPS[@]}"; do
    BACKUP="${BACKUPS[$i]}"
    TIMESTAMP=$(basename "$BACKUP" | sed 's/docker-compose_//;s/\.yml//')
    echo "  $((i+1)). $TIMESTAMP"
done

echo ""
read -p "Select backup number to restore (or 'q' to cancel): " CHOICE

if [ "$CHOICE" = "q" ]; then
    log "Rollback cancelled"
    exit 0
fi

# ============================================================================
# RESTORE SELECTED BACKUP
# ============================================================================
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#BACKUPS[@]} ]; then
    error "Invalid selection"
fi

SELECTED_BACKUP="${BACKUPS[$((CHOICE-1))]}"
TIMESTAMP=$(basename "$SELECTED_BACKUP" | sed 's/docker-compose_//;s/\.yml//')

log "Restoring backup: $TIMESTAMP"

# Stop current deployment
log "Stopping current deployment..."
docker-compose -f "$PROJECT_DIR/docker-compose.yml" down || warning "Could not stop current deployment"

# Restore files
log "Restoring files..."
cp "$SELECTED_BACKUP" "$PROJECT_DIR/docker-compose.yml"

ENV_BACKUP="$BACKUP_DIR/.env_${TIMESTAMP}"
if [ -f "$ENV_BACKUP" ]; then
    cp "$ENV_BACKUP" "$PROJECT_DIR/.env"
    log "Restored configuration file"
fi

# Start restored deployment
log "Starting restored deployment..."
cd "$PROJECT_DIR"
docker-compose up -d

sleep 10

# Verify
log "Verifying restored deployment..."
if curl -f http://localhost:8001/health > /dev/null 2>&1; then
    success "✓ Backend is healthy"
else
    error "✗ Backend health check failed"
fi

echo ""
success "✅ ROLLBACK COMPLETED"
log "Timestamp: $(date)"
