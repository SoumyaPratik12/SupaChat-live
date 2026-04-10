#!/bin/bash

# ============================================================================
# HEALTH CHECK & MONITORING SCRIPT
# ============================================================================

set -e

HOST="${1:-localhost}"
PORT="${2:-80}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Running health checks for SupaChat at $HOST..."
echo ""

# ============================================================================
# APPLICATION HEALTH CHECKS
# ============================================================================
echo "📋 Application Status:"
echo "─────────────────────────"

# Frontend
if curl -sf "http://$HOST:80" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Frontend (Port 80): Running"
else
    echo -e "${RED}✗${NC} Frontend (Port 80): Not responding"
fi

# Backend
if curl -sf "http://$HOST:8001/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Backend API (Port 8001): Running"
else
    echo -e "${RED}✗${NC} Backend API (Port 8001): Not responding"
fi

# Nginx
if curl -sf "http://$HOST:80/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Nginx Reverse Proxy: Running"
else
    echo -e "${RED}✗${NC} Nginx Reverse Proxy: Not responding"
fi

# ============================================================================
# MONITORING & LOGGING STACK
# ============================================================================
echo ""
echo "📊 Monitoring Stack:"
echo "─────────────────────────"

# Prometheus
if curl -sf "http://$HOST:9090/-/healthy" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Prometheus (Port 9090): Running"
else
    echo -e "${YELLOW}⚠${NC} Prometheus (Port 9090): Check status"
fi

# Grafana
if curl -sf "http://$HOST:3001/api/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Grafana (Port 3001): Running"
else
    echo -e "${YELLOW}⚠${NC} Grafana (Port 3001): Check status"
fi

# Loki
if curl -sf "http://$HOST:3100/ready" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Loki (Port 3100): Running"
else
    echo -e "${YELLOW}⚠${NC} Loki (Port 3100): Check status"
fi

# ============================================================================
# SYSTEM METRICS
# ============================================================================
echo ""
echo "💻 System Metrics (if available):"
echo "─────────────────────────"

if command -v docker &> /dev/null; then
    echo "Docker Container Status:"
    docker-compose ps 2>/dev/null || docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "  Docker info unavailable"
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo "✅ Health check complete"
echo ""
echo "Dashboard URLs:"
echo "  Frontend:   http://$HOST/"
echo "  API Docs:   http://$HOST/api/docs"
echo "  Prometheus: http://$HOST:9090"
echo "  Grafana:    http://$HOST:3001 (admin/admin)"
echo "  Loki:       http://$HOST:3100"
