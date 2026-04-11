#!/bin/bash
# ============================================================================
# MONITORING VERIFICATION SCRIPT
# Run on EC2 after docker compose up to confirm the full stack is wired.
# ============================================================================
set -e

HOST="${1:-localhost}"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

echo "============================================"
echo " SupaChat Monitoring Stack Verification"
echo " Host: $HOST"
echo "============================================"
echo ""

# ── Application endpoints ─────────────────────────────────────────────────────
echo "[ Application ]"
curl -sf "http://$HOST/health"        && ok "Nginx /health"        || fail "Nginx /health"
curl -sf "http://$HOST/api/health"    && ok "Backend /api/health"  || fail "Backend /api/health"
curl -sf "http://$HOST:8001/health"   && ok "Backend direct :8001" || warn "Backend direct (optional)"
echo ""

# ── Prometheus ────────────────────────────────────────────────────────────────
echo "[ Prometheus ]"
curl -sf "http://$HOST:9090/-/healthy" && ok "Prometheus healthy" || fail "Prometheus not reachable"

# Check scrape targets
TARGETS=$(curl -sf "http://$HOST:9090/api/v1/targets" 2>/dev/null || echo "{}")
ACTIVE=$(echo "$TARGETS" | grep -o '"health":"up"' | wc -l)
TOTAL=$(echo "$TARGETS"  | grep -o '"health":'     | wc -l)
echo "   Scrape targets: $ACTIVE/$TOTAL up"
[ "$ACTIVE" -ge 2 ] && ok "Prometheus scraping targets" || warn "Some targets may be down — check http://$HOST:9090/targets"
echo ""

# ── Loki ──────────────────────────────────────────────────────────────────────
echo "[ Loki ]"
curl -sf "http://$HOST:3100/ready" && ok "Loki ready" || fail "Loki not ready"
echo ""

# ── Grafana ───────────────────────────────────────────────────────────────────
echo "[ Grafana ]"
HTTP=$(curl -so /dev/null -w "%{http_code}" "http://$HOST:3001/api/health" 2>/dev/null || echo "000")
[ "$HTTP" = "200" ] && ok "Grafana healthy (HTTP $HTTP)" || fail "Grafana returned HTTP $HTTP"

# Check datasources are provisioned
DS=$(curl -su admin:admin "http://$HOST:3001/api/datasources" 2>/dev/null || echo "[]")
echo "$DS" | grep -q "Prometheus" && ok "Prometheus datasource provisioned" || fail "Prometheus datasource missing"
echo "$DS" | grep -q "Loki"       && ok "Loki datasource provisioned"       || fail "Loki datasource missing"

# Check dashboard is provisioned
DASH=$(curl -su admin:admin "http://$HOST:3001/api/search?query=SupaChat" 2>/dev/null || echo "[]")
echo "$DASH" | grep -q "supachat-overview" && ok "SupaChat dashboard provisioned" || warn "Dashboard not found — may still be loading"
echo ""

echo "============================================"
echo " Access URLs:"
echo "   App:        http://$HOST"
echo "   Grafana:    http://$HOST:3001  (admin/admin)"
echo "   Prometheus: http://$HOST:9090"
echo "   Loki:       http://$HOST:3100"
echo "============================================"
