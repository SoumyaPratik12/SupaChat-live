#!/bin/bash
# ============================================================================
# MONITORING + CI/CD VALIDATION SCRIPT
# Run on EC2 after docker compose up to confirm everything is wired.
# Usage: bash scripts/setup-monitoring.sh [HOST]
# ============================================================================

HOST="${1:-localhost}"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; FAILURES=$((FAILURES+1)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
section() { echo ""; echo -e "${BLUE}[ $1 ]${NC}"; }

FAILURES=0

echo "============================================"
echo " SupaChat Full Stack Validation"
echo " Host: $HOST"
echo " Time: $(date)"
echo "============================================"

# ── Docker containers ─────────────────────────────────────────────────────────
section "Docker Containers"
REQUIRED_CONTAINERS=(supachat-backend supachat-frontend supachat-nginx supachat-prometheus supachat-grafana supachat-loki supachat-promtail supachat-cadvisor)

for c in "${REQUIRED_CONTAINERS[@]}"; do
  STATUS=$(docker inspect --format='{{.State.Status}}' "$c" 2>/dev/null || echo "missing")
  HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$c" 2>/dev/null || echo "")
  if [ "$STATUS" = "running" ]; then
    ok "$c → running ($HEALTH)"
  else
    fail "$c → $STATUS"
  fi
done

# ── Application endpoints ─────────────────────────────────────────────────────
section "Application"
curl -sf "http://$HOST/health"     && ok "Nginx /health"       || fail "Nginx /health not reachable"
curl -sf "http://$HOST/api/health" && ok "Backend /api/health" || fail "Backend /api/health not reachable"
curl -sf "http://$HOST/api/docs"   && ok "Swagger /api/docs"   || warn "Swagger docs (optional)"

# Test a real query
QUERY_RESP=$(curl -sf -X POST "http://$HOST/api/query" \
  -H "Content-Type: application/json" \
  -d '{"query":"show top trending topics"}' 2>/dev/null || echo "")
if echo "$QUERY_RESP" | grep -q '"success":true'; then
  ok "POST /api/query → returns results"
else
  fail "POST /api/query → no response or error"
fi

# ── Prometheus ────────────────────────────────────────────────────────────────
section "Prometheus"
PROM_HEALTH=$(curl -sf "http://$HOST:9090/-/healthy" 2>/dev/null || echo "")
[ -n "$PROM_HEALTH" ] && ok "Prometheus healthy" || fail "Prometheus not reachable on :9090"

# Check scrape targets
TARGETS=$(curl -sf "http://$HOST:9090/api/v1/targets" 2>/dev/null || echo "{}")
UP_COUNT=$(echo "$TARGETS" | grep -o '"health":"up"' | wc -l)
TOTAL_COUNT=$(echo "$TARGETS" | grep -o '"health":' | wc -l)
[ "$UP_COUNT" -ge 2 ] && ok "Scrape targets: $UP_COUNT/$TOTAL_COUNT up" || warn "Scrape targets: $UP_COUNT/$TOTAL_COUNT up — check http://$HOST:9090/targets"

# Check backend metrics are being scraped
METRICS=$(curl -sf "http://$HOST:9090/api/v1/query?query=supachat_nl_queries_total" 2>/dev/null || echo "")
echo "$METRICS" | grep -q '"status":"success"' && ok "supachat_nl_queries_total metric present" || warn "supachat metrics not yet scraped (send a query first)"

# ── Loki ──────────────────────────────────────────────────────────────────────
section "Loki"
LOKI_READY=$(curl -sf "http://$HOST:3100/ready" 2>/dev/null || echo "")
[ "$LOKI_READY" = "ready" ] && ok "Loki ready" || fail "Loki not ready on :3100 — check: docker logs supachat-loki"

LOKI_HEALTH=$(curl -sf "http://$HOST:3100/loki/api/v1/labels" 2>/dev/null || echo "")
echo "$LOKI_HEALTH" | grep -q '"status":"success"' && ok "Loki API responding" || warn "Loki API not yet returning labels (may need a minute)"

# ── Grafana ───────────────────────────────────────────────────────────────────
section "Grafana"
GRAFANA_HTTP=$(curl -so /dev/null -w "%{http_code}" "http://$HOST:3001/api/health" 2>/dev/null || echo "000")
[ "$GRAFANA_HTTP" = "200" ] && ok "Grafana healthy (HTTP $GRAFANA_HTTP)" || fail "Grafana returned HTTP $GRAFANA_HTTP on :3001"

# Check datasources provisioned
DS=$(curl -su admin:admin "http://$HOST:3001/api/datasources" 2>/dev/null || echo "[]")
echo "$DS" | grep -q '"name":"Prometheus"' && ok "Prometheus datasource provisioned" || fail "Prometheus datasource missing"
echo "$DS" | grep -q '"name":"Loki"'       && ok "Loki datasource provisioned"       || fail "Loki datasource missing"

# Check dashboard provisioned
DASH=$(curl -su admin:admin "http://$HOST:3001/api/search?query=SupaChat" 2>/dev/null || echo "[]")
echo "$DASH" | grep -q "supachat-overview" && ok "SupaChat Overview dashboard provisioned" || warn "Dashboard not found — may still be loading"

# ── CI/CD validation ──────────────────────────────────────────────────────────
section "CI/CD"
if [ -f "$HOME/SupaChat-live/.github/workflows/deploy.yml" ]; then
  ok "deploy.yml present"
else
  warn "deploy.yml not found at expected path"
fi

LAST_DEPLOY=$(stat -c '%y' "$HOME/SupaChat-live/.git/FETCH_HEAD" 2>/dev/null || echo "unknown")
ok "Last git fetch: $LAST_DEPLOY"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
if [ "$FAILURES" -eq 0 ]; then
  echo -e " ${GREEN}✅ ALL CHECKS PASSED${NC}"
else
  echo -e " ${RED}❌ $FAILURES CHECK(S) FAILED${NC}"
  echo ""
  echo " Common fixes:"
  echo "   Public access:  bash scripts/aws-network-fix.sh $HOST"
  echo "   Loki restart:   docker compose restart loki promtail"
  echo "   All containers: docker compose up -d --build"
fi
echo ""
echo " Access URLs:"
echo "   App:        http://$HOST"
echo "   Grafana:    http://$HOST:3001  (admin/admin)"
echo "   Prometheus: http://$HOST:9090"
echo "   Loki:       http://$HOST:3100"
echo "   API Docs:   http://$HOST/api/docs"
echo "============================================"

exit $FAILURES
