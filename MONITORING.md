# SupaChat - Monitoring & Logging Guide

## Overview

SupaChat includes a comprehensive monitoring stack with Prometheus, Grafana, and Loki for complete observability.

## Prometheus Metrics

### Available Metrics

#### Application Metrics
```
# Request metrics
supachat_requests_total{method, endpoint, status}
  - Total HTTP requests by method, endpoint, status

supachat_query_duration_seconds{query_type}
  - Query execution time histogram with percentiles

supachat_nl_queries_total
  - Total natural language queries processed
```

#### System Metrics (auto-collected)
```
# Container metrics
container_memory_usage_bytes
container_cpu_usage_seconds_total
container_network_io_bytes_total

# Python metrics
python_gc_collections_total
python_gc_objects_collected_total
python_gc_objects_uncollected_total
```

### Querying Prometheus

Access at: `http://localhost:9090`

#### Query Examples

**Request Rate (per second)**
```
rate(supachat_requests_total[5m])
```

**Error Rate**
```
rate(supachat_requests_total{status=~"5.."}[5m])
```

**95th Percentile Latency**
```
histogram_quantile(0.95, supachat_query_duration_seconds)
```

**Request Count by Endpoint**
```
sum by (endpoint) (supachat_requests_total)
```

**NL Queries Per Day**
```
sum(rate(supachat_nl_queries_total[24h])) * 86400
```

### Prometheus Configuration

**File**: `monitoring/prometheus.yml`

```yaml
global:
  scrape_interval: 15s      # Collect metrics every 15 seconds
  evaluation_interval: 15s  # Evaluate rules every 15 seconds

scrape_configs:
  - job_name: 'backend'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'
    scrape_interval: 10s
```

### Retention & Storage

**Default**: 30 days of metrics

**Adjust retention**:
```bash
# Edit docker-compose.yml Prometheus command:
command:
  - '--storage.tsdb.retention.time=90d'    # Keep 90 days
  - '--storage.tsdb.max-block-duration=7d' # Compress old data
```

**Storage requirements**:
- Current: ~500MB per week
- 30 days: ~2GB
- 90 days: ~6GB
- Adjust EBS volume accordingly

---

## Grafana Dashboards

### Access Grafana
- **URL**: http://localhost:3001
- **Username**: admin
- **Password**: admin (change in production!)

### Pre-configured Datasources

1. **Prometheus** (http://prometheus:9090)
   - Metrics database
   - Pre-configured & ready to use

2. **Loki** (http://loki:3100)
   - Logs database
   - Pre-configured & ready to use

### Creating Dashboards

#### Step 1: New Dashboard
1. Click **+** icon → **Dashboard**
2. Click **Add Panel**
3. Select **Prometheus** as datasource

#### Step 2: Build Query
```
Example: Request Rate
Query: rate(supachat_requests_total[5m])
Legend: {{endpoint}} - {{status}}
Unit: requests per second
```

#### Step 3: Visualizations

**Table**
- Use for detailed data
- Sorting & filtering
- Export to CSV

**Graph/Time Series**
- Use for metrics over time
- Great for trends
- Multiple series support

**Gauge**
- Use for current status
- Min/max ranges
- Color thresholds

**Pie Chart**
- Use for distribution
- Summary view
- Percentage breakdown

**Stat Panel**
- Single number
- Big Number display
- Color coding

#### Step 4: Save Dashboard
1. Click **Save** button
2. Enter name: e.g., "Application Performance"
3. Select folder: "SupaChat"
4. Click **Save**

### Example Dashboards

#### Dashboard 1: Application Performance
```
Panel 1: Request Volume
  Query: rate(supachat_requests_total[1m])
  Visualization: Graph
  
Panel 2: Error Rate
  Query: rate(supachat_requests_total{status=~"5.."}[5m])
  Visualization: Graph
  
Panel 3: p95 Latency
  Query: histogram_quantile(0.95, supachat_query_duration_seconds)
  Visualization: Graph
  
Panel 4: Requests by Status
  Query: sum by (status) (supachat_requests_total)
  Visualization: Pie Chart
```

#### Dashboard 2: Container Health
```
Panel 1: CPU Usage
  Query: rate(container_cpu_usage_seconds_total[5m])
  Unit: percentunit
  
Panel 2: Memory Usage
  Query: container_memory_usage_bytes / 1024 / 1024
  Unit: bytes
  
Panel 3: Network I/O
  Query: rate(container_network_io_bytes_total[5m])
  Unit: Bps
  
Panel 4: Connected Containers
  Query: count(up)
  Visualization: Gauge
```

#### Dashboard 3: Business Metrics
```
Panel 1: Total Queries
  Query: supachat_nl_queries_total
  Visualization: Stat
  
Panel 2: Queries Per Hour
  Query: rate(supachat_nl_queries_total[1h])
  Unit: short
  
Panel 3: Query Success Rate
  Query: sum(rate(supachat_requests_total{status="200"}[5m])) / sum(rate(supachat_requests_total[5m]))
  Unit: percentunit
```

### Alerting Rules

**File**: `monitoring/prometheus-alerts.yml` (optional, create if needed)

```yaml
groups:
  - name: supachat-alerts
    rules:
      # High Error Rate Alert
      - alert: HighErrorRate
        expr: rate(supachat_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "High error rate detected"
          description: "Error rate above 5% for 5 minutes"
      
      # High Latency Alert
      - alert: HighLatency
        expr: histogram_quantile(0.95, supachat_query_duration_seconds) > 2
        for: 5m
        annotations:
          summary: "High query latency"
          description: "p95 latency above 2 seconds"
      
      # Service Down Alert
      - alert: ServiceDown
        expr: up{job="backend"} == 0
        for: 1m
        annotations:
          summary: "Service is down"
          description: "Backend service is not responding"
```

---

## Loki Logs

### Access Logs
- **Loki API**: http://localhost:3100
- **Via Grafana**: **Explore** → Select Loki datasource

### Log Sources

Logs are collected from:
1. **Backend Container** - FastAPI logs
2. **Frontend Container** - Next.js logs
3. **Nginx Container** - Access & error logs
4. **System** - Docker daemon logs

### LogQL Queries

**Basic Syntax**
```
{job="backend"}           # Filter by job
{container_name="..."}    # Filter by container
| grep "error"           # Text search
| level="error"          # Parse JSON field
| status >= 500          # Numeric filter
```

#### Query Examples

**All Backend Logs**
```
{job="backend"}
```

**Parse JSON and Find Errors**
```
{container_name="supachat-backend"} 
| json 
| level="ERROR"
```

**Nginx Access Logs**
```
{container_name="supachat-nginx"}
```

**Find Slow Queries** (if logged)
```
{job="backend"} 
| json 
| execution_time > "1"
```

**Count Errors by Type**
```
sum by (error_type) (
  {job="backend"} 
  | json 
  | level="ERROR"
)
```

### Configuring Log Collection

**Docker Logging Driver**

To collect Docker container logs to Loki, update docker-compose.yml:

```yaml
services:
  backend:
    logging:
      driver: loki
      options:
        loki-url: "http://localhost:3100/loki/api/v1/push"
        loki-batch-size: "400"
    # ... rest of config
```

(Requires Loki Docker driver plugin installation)

### Log Retention

**File**: `monitoring/loki/loki-config.yml`

```yaml
limits_config:
  retention_period: 720h    # Keep logs for 30 days
  max_cache_freshness_period: 10m
```

### Parsing Logs

**JSON Parsing**
```
json | level="INFO"
```

**Logfmt Parsing**
```
logfmt | level=error
```

**Regex Parsing**
```
pattern `<_> - <user> [<_>] "<method> <path> <_>" <status> <_>`
```

---

## Health Monitoring

### Health Check Endpoints

All services expose health endpoints:

```bash
# Backend
curl http://localhost:8000/health

# Frontend (Next.js app)
curl http://localhost:3000

# Nginx
curl http://localhost:80/health

# Prometheus
curl http://localhost:9090/-/healthy

# Grafana
curl http://localhost:3001/api/health

# Loki
curl http://localhost:3100/ready
```

### Automated Health Checks

Run the health check script:

```bash
bash scripts/health-check.sh localhost

# Output:
# 🔍 Running health checks...
# ✓ Frontend (Port 80): Running
# ✓ Backend API (Port 8000): Running
# ✓ Prometheus (Port 9090): Running
```

### Docker Health Checks

Configured in docker-compose.yml:

```yaml
healthcheck:
  test: ['CMD', 'curl', '-f', 'http://localhost:8000/health']
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 5s
```

View docker health status:

```bash
docker-compose ps    # Shows health status
docker inspect <container-id>  # Detailed health info
```

---

## Metrics Export

### Prometheus Metrics Endpoint

**Backend exports metrics**:
```
http://localhost:8000/metrics
```

**Format**: Prometheus text format

**Example output**:
```
# HELP supachat_requests_total Total API requests
# TYPE supachat_requests_total counter
supachat_requests_total{endpoint="/query",method="POST",status="200"} 1425.0
supachat_requests_total{endpoint="/health",method="GET",status="200"} 2840.0

# HELP supachat_query_duration_seconds Query execution time
# TYPE supachat_query_duration_seconds histogram
supachat_query_duration_seconds_bucket{le="0.1",query_type="analytics"} 120.0
supachat_query_duration_seconds_bucket{le="0.5",query_type="analytics"} 1350.0
```

### Custom Metrics

To add custom metrics to backend, edit `backend/main.py`:

```python
from prometheus_client import Counter, Histogram

# Define metric
custom_events = Counter(
    'supachat_custom_events_total',
    'Custom events count',
    ['event_type']
)

# Use metric
custom_events.labels(event_type='query_saved').inc()

# Query: rate(supachat_custom_events_total[5m])
```

---

## Troubleshooting & Performance

### Prometheus High Memory Usage

**Symptoms**: Container using > 500MB RAM

**Solutions**:
```bash
# Reduce retention
docker-compose down
# Edit docker-compose.yml prometheus command:
# Add: --storage.tsdb.retention.time=7d

docker-compose up -d
```

### Grafana Dashboard Not Loading

**Symptoms**: Empty dashboard, no data

**Solutions**:
```bash
# Check Prometheus datasource
# Grafana → Configuration → Data Sources → Prometheus
# Click "Test" button

# Check if metrics are available
curl http://localhost:9090/api/v1/query?query=up
```

### Loki Query Slow

**Symptoms**: Query takes > 30 seconds

**Solutions**:
```bash
# Reduce time range (recent logs are faster)
# Use more specific filters: {job="backend"} | level="ERROR"
# Avoid regex patterns if possible
```

### Missing Logs

**Symptoms**: No logs appearing in Grafana

**Solutions**:
```bash
# Verify Loki is running
docker-compose ps loki

# Check Loki logs
docker-compose logs loki

# Verify container logs are accessible
docker logs supachat-backend
```

---

## Best Practices

### Metrics
- ✅ Use appropriate scrape intervals (10-30s)
- ✅ Keep retention balanced (storage vs. analysis needs)
- ✅ Use recording rules for complex queries
- ✅ Set up alerts for critical thresholds
- ❌ Don't scrape too frequently (high load)
- ❌ Don't keep metrics longer than needed

### Logs
- ✅ Parse structured logs (JSON, logfmt)
- ✅ Use consistent log levels
- ✅ Include request IDs for tracing
- ✅ Rotate logs regularly
- ❌ Don't log sensitive data (passwords, keys)
- ❌ Don't log at DEBUG level in production

### Dashboards
- ✅ Use meaningful titles & descriptions
- ✅ Organize related panels into rows
- ✅ Use consistent colors & units
- ✅ Set appropriate refresh rates (30s-1m)
- ❌ Don't overcrowd dashboards
- ❌ Don't use overly complex queries

---

## Resources

- **Prometheus Docs**: https://prometheus.io/docs
- **Grafana Docs**: https://grafana.com/docs/grafana
- **Loki Docs**: https://grafana.com/docs/loki
- **LogQL**: https://grafana.com/docs/loki/latest/logql
- **PromQL**: https://prometheus.io/docs/prometheus/latest/querying/basics

---

**Monitoring Guide Version**: 1.0  
**Last Updated**: January 2024
