# SupaChat — Conversational Analytics on Supabase PostgreSQL

A production-ready full-stack app that lets users query a blog analytics database using **natural language**. Built with React/Next.js, FastAPI, Supabase PostgreSQL, and deployed through a complete DevOps lifecycle.

```
Build → Dockerize → Deploy → Reverse Proxy → CI/CD → Monitoring
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Users (Browser)                       │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTP :80
              ┌────────────▼────────────┐
              │     Nginx Reverse Proxy  │
              │   / → frontend :3000    │
              │   /api → backend :8000  │
              └──────┬──────────┬───────┘
                     │          │
          ┌──────────▼──┐  ┌────▼──────────┐
          │  Frontend    │  │   Backend      │
          │  Next.js 14  │  │   FastAPI      │
          │  Recharts    │  │   + MCP layer  │
          │  :3000       │  │   :8000        │
          └─────────────┘  └────┬───────────┘
                                │
                    ┌───────────▼───────────┐
                    │   Supabase PostgreSQL  │
                    │   (articles table)     │
                    └───────────────────────┘

Monitoring Stack:
  Prometheus :9090  ← scrapes backend + cAdvisor
  Grafana    :3001  ← dashboards (CPU, memory, latency, logs)
  Loki       :3100  ← log aggregation
  Promtail          ← ships container logs → Loki
  cAdvisor   :8080  ← container metrics
```

### Request Flow

1. User types natural language query in chat UI
2. Frontend POSTs to `/api/query` → Nginx → FastAPI
3. FastAPI `translate_nl_to_sql()` converts NL → SQL (MCP integration point)
4. SQL executes against Supabase PostgreSQL
5. Results returned as JSON → rendered as table + Recharts graph
6. Prometheus scrapes `/metrics` every 10s
7. Grafana visualises metrics + Loki logs in real-time

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Next.js 14, React 18, Recharts, Tailwind CSS, Axios |
| Backend | FastAPI, Pydantic, Supabase SDK, prometheus-client |
| Database | Supabase PostgreSQL |
| Proxy | Nginx (gzip, caching, rate limiting, WebSocket support) |
| Containers | Docker, Docker Compose (CPU/memory limits, health checks) |
| CI/CD | GitHub Actions (build → deploy → health check) |
| Monitoring | Prometheus, Grafana, Loki, Promtail, cAdvisor |
| Cloud | AWS EC2 (Ubuntu, t3.medium+) |

---

## Step 1 — Setup

### Prerequisites

- Docker & Docker Compose
- Git
- Node.js 20+ (local dev only)
- Python 3.11+ (local dev only)

### Clone & Configure

```bash
git clone https://github.com/SoumyaPratik12/SupaChat-live.git
cd SupaChat-live
cp .env.example .env
# Edit .env with your Supabase credentials
```

### Database Setup (Supabase)

1. Create a project at https://supabase.com
2. Run in the SQL editor:

```sql
CREATE TABLE articles (
  id              SERIAL PRIMARY KEY,
  title           VARCHAR NOT NULL,
  topic           VARCHAR NOT NULL,
  views           INTEGER DEFAULT 0,
  engagement_rate FLOAT   DEFAULT 0,
  shares          INTEGER DEFAULT 0,
  published_date  TIMESTAMP DEFAULT NOW()
);

INSERT INTO articles (title, topic, views, engagement_rate, shares) VALUES
  ('AI Trends 2024',        'AI',     450, 0.85, 32),
  ('DevOps Best Practices', 'DevOps', 320, 0.72, 18),
  ('Web3 Fundamentals',     'Web3',   210, 0.68, 12),
  ('Cloud Architecture',    'Cloud',  380, 0.76, 21),
  ('MLOps in Practice',     'AI',     290, 0.79, 15);
```

3. Copy your project URL and anon/service keys into `.env`

---

## Step 2 — Docker Deployment

```bash
# Build and start all services
docker compose up -d --build

# View logs
docker compose logs -f

# Check health
docker compose ps

# Stop
docker compose down
```

### Services started

| Service | Port | Purpose |
|---|---|---|
| nginx | 80 | Reverse proxy (entry point) |
| frontend | 3000 | Next.js UI |
| backend | 8001 | FastAPI (internal: 8000) |
| prometheus | 9090 | Metrics collection |
| grafana | 3001 | Dashboards |
| loki | 3100 | Log aggregation |
| promtail | — | Log shipper |
| cadvisor | 8080 | Container metrics |

All services have CPU/memory limits and health checks defined.

---

## Step 3 — AWS EC2 Deployment

### Launch EC2

- AMI: Ubuntu 22.04 LTS
- Instance: t3.medium (2 vCPU, 4GB RAM minimum)
- Security Group — open inbound ports:

| Port | Purpose |
|---|---|
| 22 | SSH |
| 80 | HTTP (app) |
| 3001 | Grafana |
| 9090 | Prometheus |

### First-time setup

```bash
ssh -i your-key.pem ubuntu@<EC2-IP>

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone and start
git clone https://github.com/SoumyaPratik12/SupaChat-live.git ~/SupaChat-live
cd ~/SupaChat-live
cp .env.example .env
nano .env   # add Supabase credentials
docker compose up -d --build
```

### Verify

```bash
bash scripts/setup-monitoring.sh localhost
```

---

## Step 4 — Nginx Reverse Proxy

Config: `nginx/nginx.conf`

| Route | Destination | Notes |
|---|---|---|
| `/` | frontend:3000 | Next.js pages |
| `/api/` | backend:8000 | FastAPI (strips /api prefix) |
| `/metrics` | backend:8000/metrics | Prometheus scrape |
| `/health` | Nginx itself | Health check endpoint |

Features enabled:
- Gzip compression (text, CSS, JS, JSON)
- Static asset caching (30 days, immutable)
- Rate limiting (10 req/s general, 30 req/s API)
- WebSocket upgrade headers
- Dotfile access blocked

---

## Step 5 — CI/CD Pipeline

File: `.github/workflows/deploy.yml`

### Pipeline stages

```
push to main
    │
    ▼
[build]
  docker build backend image
  docker build frontend image
    │
    ▼
[deploy]
  SSH into EC2 (appleboy/ssh-action)
  git reset --hard origin/main
  write .env from GitHub secrets
  docker compose up -d --build --remove-orphans
  docker image prune -f
    │
    ▼
[health-check]
  curl /health (Nginx)
  curl /api/health (Backend)
```

### GitHub Secrets required

| Secret | Value |
|---|---|
| `EC2_HOST` | EC2 public IP |
| `EC2_USER` | `ubuntu` |
| `EC2_SSH_KEY` | Private key content (`cat ~/.ssh/id_rsa`) |
| `SUPABASE_URL` | `https://xxx.supabase.co` |
| `SUPABASE_KEY` | anon key |
| `SUPABASE_SERVICE_KEY` | service key |

### Rollback

```bash
cd ~/SupaChat-live
bash scripts/rollback.sh
```

---

## Step 6 — Monitoring & Logging

### Grafana Dashboards

Access: `http://<EC2-IP>:3001` (admin / admin)

The **SupaChat Overview** dashboard auto-provisions on startup with:

| Panel | Metric |
|---|---|
| HTTP Requests/sec | `rate(supachat_requests_total[1m])` |
| NL Queries Total | `supachat_nl_queries_total` |
| Query Duration p95 | `histogram_quantile(0.95, ...)` |
| Error Rate | `rate(supachat_requests_total{status="500"}[1m])` |
| Container CPU % | `rate(container_cpu_usage_seconds_total[1m]) * 100` |
| Container Memory MB | `container_memory_usage_bytes / 1024 / 1024` |
| Network I/O | `rate(container_network_*_bytes_total[1m])` |
| Running Containers | `count(container_last_seen{name=~"supachat.*"})` |
| Backend Logs | Loki: `{job="supachat-backend"}` |
| Nginx Logs | Loki: `{job="supachat-nginx"}` |

### Prometheus

Access: `http://<EC2-IP>:9090`

Scrape targets:
- `backend:8000/metrics` — application metrics
- `cadvisor:8080/metrics` — container CPU/memory/network
- `localhost:9090` — Prometheus self-monitoring

### Loki + Promtail

Promtail auto-discovers all `supachat-*` containers via Docker socket and ships logs to Loki with job labels. Query in Grafana Explore:

```logql
{job="supachat-backend"}
{job="supachat-nginx"}
{job="supachat-loki"}
```

---

## Example Queries

| Natural Language | Chart Type |
|---|---|
| Show top trending topics in last 30 days | Bar chart |
| Compare article engagement by topic | Bar chart |
| Plot daily views trend for AI articles | Line chart |
| Show article performance metrics | Table |

---

## Local Development

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
python main.py
# → http://localhost:8000/docs
```

### Frontend

```bash
cd frontend
npm install
npm run dev
# → http://localhost:3000
```

---

## AI Tools Used

- **Amazon Q Developer** — code review, bug fixes, architecture guidance
- Used throughout: backend API design, Prometheus metric wiring, Nginx config debugging, CI/CD pipeline construction, Grafana dashboard JSON

---

## Production Checklist

- [ ] Set real Supabase credentials in `.env` / GitHub Secrets
- [ ] Change Grafana admin password from default
- [ ] Restrict `allow_origins` in FastAPI CORS to your domain
- [ ] Enable HTTPS via AWS ALB or certbot
- [ ] Set up Prometheus alerting rules
- [ ] Configure log retention in Loki
- [ ] Test rollback procedure: `bash scripts/rollback.sh`

---

**Version**: 1.0.0 | **Status**: Production Ready
