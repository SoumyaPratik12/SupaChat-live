# SupaChat - Architecture & Design

## System Architecture

### High-Level Components

```
┌────────────────────────────────────────────────────────────────────┐
│                         Internet                                    │
└────────┬─────────────────────────────────────────────────┬─────────┘
         │                                                 │
         │                                          (CI/CD Webhook)
         │                                                 │
    ┌────▼──────┐                                   ┌──────▼────┐
    │   Client   │                                   │   GitHub   │
    │  (Browser) │                                   │  (Actions) │
    └────┬──────┘                                    └──────┬────┘
         │                                                  │
         │ HTTP/HTTPS                          Build & Deploy
         │                                                  │
    ┌────▼────────────────────────────────────────────────▼──────┐
    │              AWS EC2 Instance (Public)                       │
    │  ┌───────────────────────────────────────────────────────┐  │
    │  │        Nginx Reverse Proxy (80/443)                   │  │
    │  │  ┌─────────────────────────────────────────────────┐  │  │
    │  │  │ • Rate Limiting                                 │  │  │
    │  │  │ • Gzip Compression                              │  │  │
    │  │  │ • SSL Termination                               │  │  │
    │  │  │ • Request Routing                               │  │  │
    │  │  └─────────────────────────────────────────────────┘  │  │
    │  └────┬────────────────────────────────┬─────────────────┘  │
    │       │                                │                    │
    │   ┌───▼────┐                      ┌────▼────┐               │
    │   │Frontend │                      │Backend  │               │
    │   │Container│                      │Container│               │
    │   └─────────┘                      └────┬────┘               │
    │                                         │                    │
    │   Docker Network (supachat-network)    │                    │
    │                                         │                    │
    │   ┌─────────────────────────────────────▼──────────────┐    │
    │   │    Monitoring Stack (same EC2 or separate)         │    │
    │   │  ┌──────────────┐    ┌──────────┐   ┌──────────┐  │    │
    │   │  │ Prometheus   │    │ Grafana  │   │  Loki    │  │    │
    │   │  │ (Metrics)    │    │(Visual)  │   │(Logs)    │  │    │
    │   │  └──────┬───────┘    └────┬─────┘   └────┬─────┘  │    │
    │   │         └────────────┬────┴──────────────┘         │    │
    │   │                      │                             │    │
    │   │  (Scrapes metrics    │ Data Volume                 │    │
    │   │   & log streams)     │                             │    │
    │   └──────────────────────┴─────────────────────────────┘    │
    │                                                              │
    │   Volumes:                                                   │
    │   • prometheus-data   [Metrics time series DB]              │
    │   • grafana-data      [Dashboard configs & state]           │
    │   • loki-data         [Log indices & chunks]                │
    └──────────────────────────────────────────────────────────────┘
         │
         │ (Internet connectivity for: Supabase, Docker registry, updates)
         │
    ┌────▼──────────────┐
    │  External Services │
    │ • Supabase Cloud   │  - PostgreSQL database
    │ • Docker Registry  │  - Image storage (optional)
    │ • GitHub           │  - Repository & triggers
    └───────────────────┘
```

## Container Architecture

### Frontend Container
- **Image**: Node.js 20-Alpine
- **Port**: 3000
- **Framework**: Next.js 14
- **Build**: Multi-stage (builder + runtime)
- **Health Check**: HTTP GET to `:3000`
- **Resources**:
  - CPU: 0.5 cores (recommended)
  - Memory: 256MB (recommended)

### Backend Container
- **Image**: Python 3.11-Slim
- **Port**: 8000
- **Framework**: FastAPI
- **ASGI Server**: Uvicorn
- **Build**: Multi-stage (builder + runtime)
- **Health Check**: HTTP GET to `:8000/health`
- **Resources**:
  - CPU: 1 core (recommended)
  - Memory: 512MB (recommended)

### Nginx Container
- **Image**: Nginx Alpine
- **Port**: 80 (and 443 for HTTPS)
- **Config**: Volume mounted from `nginx/nginx.conf`
- **Features**:
  - Reverse proxy to frontend & backend
  - Gzip compression
  - Rate limiting
  - Static asset caching
  - Health check endpoint
- **Health Check**: HTTP GET to `:80/health`

### Prometheus Container
- **Image**: prom/prometheus
- **Port**: 9090
- **Config**: Volume mounted from `monitoring/prometheus.yml`
- **Data**: Persistent volume `prometheus-data`
- **Scrape Interval**: 15 seconds
- **Retention**: 30 days (configurable)

### Grafana Container
- **Image**: grafana/grafana
- **Port**: 3001 (port 3000 inside container)
- **Default Credentials**: admin / admin
- **Data**: Persistent volume `grafana-data`
- **Datasources**: Prometheus, Loki
- **Auto-provisioning**: Via `provisioning/` volume

### Loki Container
- **Image**: grafana/loki
- **Port**: 3100
- **Config**: Volume mounted from `monitoring/loki/loki-config.yml`
- **Data**: Persistent volume `loki-data`
- **Purpose**: Log aggregation & querying

## Data Flow

### 1. User Query Request
```
User Input → React Component
↓
Query Validation
↓
Axios HTTP Request → POST /query
↓
Nginx (Rate limit, Route)
↓
FastAPI Backend
```

### 2. Backend Processing
```
FastAPI Receives Request
↓
Input Validation (Pydantic)
↓
NL → SQL Translation (MCP)
↓
SQL Execution (Supabase)
↓
Results Formatting
↓
Metrics recording (Prometheus)
↓
Response JSON
```

### 3. Frontend Rendering
```
API Response Received
↓
Results Table Display
↓
Chart Generation (Recharts)
↓
UI Update (React State)
↓
User sees results
```

### 4. Monitoring & Observability
```
FastAPI Metrics → Prometheus (:8000/metrics)
↓
Prometheus Scrapes (15s interval)
↓
Grafana Visualizes Metrics
↓
Alerts & Dashboards
```

## Deployment Topology

### Development (Local)
```
Docker Compose → All services on localhost
├── Frontend :3000
├── Backend :8000
├── Nginx :80
├── Prometheus :9090
├── Grafana :3001
└── Loki :3100

Shared Bridge Network: supachat-network
```

### Production (AWS EC2)
```
EC2 Instance (t3.medium+)
├── Docker Daemon
│   └── Docker Compose Stack
│       ├── Frontend :3000 (internal)
│       ├── Backend :8000 (internal)
│       ├── Nginx :80/:443 (external)
│       ├── Prometheus :9090 (internal)
│       ├── Grafana :3001 (external)
│       └── Loki :3100 (internal)
│
├── EBS Volume 1 (Root /)
├── EBS Volume 2 (Data for containers)
│   ├── prometheus-data
│   ├── grafana-data
│   └── loki-data
│
└── Security Group
    ├── Port 22 (SSH)
    ├── Port 80 (HTTP)
    ├── Port 443 (HTTPS)
    ├── Port 3001 (Grafana)
    └── Port 9090 (Prometheus)
```

## Networking

### DNS & Load Balancing
- **Option 1**: Direct EC2 IP (development)
- **Option 2**: Route53 + ALB (production)
- **Option 3**: AWS API Gateway (scaling)

### Network Isolation
- Docker bridge network: `supachat-network`
- All containers can communicate by service name
- External access only through Nginx on port 80/443

### Proxy Headers
```
X-Real-IP: Client IP
X-Forwarded-For: Proxy chain
X-Forwarded-Proto: Scheme (http/https)
X-Forwarded-Host: Original host
```

## Security Architecture

### Authentication
- Frontend: Session-based (future: JWT)
- Backend: API key (future: OAuth2)

### Network Security
- Rate limiting at Nginx (10-30 req/s)
- Deny access to sensitive files (`.env`, `__pycache__`, etc.)
- CORS configurable in backend
- HTTPS enforced in production

### Data Protection
- Supabase connection via HTTPS
- Environment variables in `.env` (not in code)
- Docker secrets for sensitive data (future)
- Database connection pooling

## Scalability Design

### Horizontal Scaling
1. **Load Balancer** → Multiple EC2 instances
2. **Shared Database** → Supabase (managed)
3. **Shared Cache** → Redis/Memcached (optional)
4. **Container Orchestration** → Kubernetes (future)

### Vertical Scaling
- Increase EC2 instance size (t3.medium → t3.large)
- Increase container resource limits
- Increase Prometheus retention
- Increase Grafana cache size

### Performance Optimization
- Nginx gzip compression (40-80% reduction)
- Browser caching (30 days for static assets)
- Connection pooling for database
- FastAPI async/await
- React component memoization

## Disaster Recovery

### High Availability
1. **Backups**: Docker volumes can be backed up
2. **Snapshots**: EBS volume snapshots
3. **RTO**: < 15 minutes (redeploy from backup)
4. **RPO**: < 1 hour (periodic snapshots)

### Recovery Procedures
```
Failure → Docker health check detects
↓
Auto-restart container
↓
If persistent: Manual rollback
  bash scripts/rollback.sh
↓
Restore from backup
↓
Redeploy via CI/CD
```

## Cost Optimization

### Infrastructure Costs
- **Compute**: AWS t3.medium ≈ $30/month
- **Storage**: 20GB EBS ≈ $2/month
- **Network**: Minimal egress ≈ $5/month
- **Total**: ≈ $37/month

### Optimization Strategies
- Use t3.micro for development ($8/month)
- Use Reserved Instances for savings (30-40%)
- Auto-scaling groups (peak hours only)
- Supabase free tier (≈ 500k row queries/month)
- Prometheus retention policy (7-30 days)

---

## Technology Decisions

### Why FastAPI?
- ✅ Modern async support
- ✅ Built-in OpenAPI/Swagger docs
- ✅ Type hints with Pydantic
- ✅ High performance (benchmarks: 2-3x Django)
- ✅ Excellent for microservices

### Why Next.js?
- ✅ Server-side rendering
- ✅ Static generation
- ✅ File-based routing
- ✅ Built-in CSS support
- ✅ Excellent DX (developer experience)

### Why Supabase?
- ✅ PostgreSQL (industry standard)
- ✅ Managed service (no ops)
- ✅ Real-time subscriptions (future)
- ✅ Built-in auth (extensible)
- ✅ Generous free tier

### Why Docker?
- ✅ Reproducible environments
- ✅ Isolation & security
- ✅ Easy deployment
- ✅ Container orchestration ready
- ✅ Industry standard

### Why Nginx?
- ✅ Reverse proxy champion
- ✅ High performance
- ✅ Low memory footprint
- ✅ Excellent configuration
- ✅ Load balancing ready

---

## API Contract

### Request Format
```json
{
  "query": "Show top trending topics in last 30 days",
  "context": "optional context about the query"
}
```

### Response Format
```json
{
  "success": true,
  "query_type": "analytics",
  "sql_generated": "SELECT ... FROM articles ...",
  "results": [
    {"topic": "AI", "views": 5230, "engagement": 0.78}
  ],
  "row_count": 3,
  "execution_time": 0.234,
  "message": "Query executed successfully"
}
```

### Error Response
```json
{
  "detail": "Error message describing what went wrong"
}
```

---

## Metrics & KPIs

### Application Metrics
- Request latency (p50, p95, p99)
- Query processing time
- Error rate (5xx responses)
- Success rate (2xx + 3xx)
- NL queries processed

### Infrastructure Metrics
- CPU utilization (container & host)
- Memory usage (container & host)
- Network I/O
- Disk usage (volumes)
- Container uptime

### Business Metrics
- Active users
- Queries per day
- Average response time
- Feature usage

---

## Future Enhancements

### Planned Features
- [ ] User authentication & authorization
- [ ] Query caching layer (Redis)
- [ ] Advanced charting options
- [ ] History & favorites
- [ ] Custom SQL query builder
- [ ] Real-time dashboard
- [ ] WebSocket support
- [ ] Multi-tenant support

### Infrastructure Upgrades
- [ ] Kubernetes migration
- [ ] Auto-scaling groups
- [ ] CDN integration (CloudFront)
- [ ] Private database (no internet)
- [ ] VPC setup
- [ ] WAF (Web Application Firewall)
- [ ] DDoS protection

---

**Document Version**: 1.0  
**Last Updated**: January 2024
