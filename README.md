# SupaChat-live

A production-ready conversational analytics application built with React, FastAPI, Supabase PostgreSQL, and deployed with Docker, Nginx, and comprehensive monitoring.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Quick Start](#quick-start)
- [Local Development](#local-development)
- [Docker Deployment](#docker-deployment)
- [AWS EC2 Deployment](#aws-ec2-deployment)
- [Nginx Reverse Proxy](#nginx-reverse-proxy)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring & Logging](#monitoring--logging)
- [Troubleshooting](#troubleshooting)
- [DevOps Lifecycle](#devops-lifecycle)

---

## 🏗️ Architecture Overview

```
┌─────────────────┐
│  Users (Browser)│
└────────┬────────┘
         │
 ┌───────▼──────────┐
 │  Nginx Proxy     │
 │  (Port 80/443)   │
 └────┬──────────┬──┘
      │          │
   ┌──▼─┐   ┌────▼────┐
   │FE  │   │Backend   │
   │React   │FastAPI+  │
   │:3000   │MCP       │
   │        │:8000     │
   └───┬────┴────┬─────┘
       │         │
       ▲         ▼
       │    ┌─────────────┐
       │    │ Supabase    │
       │    │PostgreSQL   │
       │    └─────────────┘
       │
     Monitoring Stack:
     • Prometheus (:9090)
     • Grafana (:3001)
     • Loki (:3100)
```

### Flow

1. **User Query** → Frontend (React)
2. **API Call** → Nginx Reverse Proxy
3. **Route** → Backend (FastAPI)
4. **Translate** → NL to SQL via MCP
5. **Query** → Supabase PostgreSQL
6. **Return** → Results + Charts
7. **Monitor** → Prometheus collects metrics

---

## 🛠️ Tech Stack

### Frontend
- **React 18** / **Next.js 14** - Modern React framework
- **Recharts** - Data visualization / charts
- **Tailwind CSS** - Styling
- **Axios** - HTTP client

### Backend
- **FastAPI** - Async Python web framework
- **Supabase SDK** - PostgreSQL client
- **Prometheus Client** - Metrics export
- **Pydantic** - Data validation

### Infrastructure
- **Docker** - Containerization
- **Docker Compose** - Orchestration
- **Nginx** - Reverse proxy & load balancing
- **AWS EC2** - Cloud hosting

### Monitoring
- **Prometheus** - Metrics collection
- **Grafana** - Visualization dashboards
- **Loki** - Log aggregation

### CI/CD
- **GitHub Actions** - Automated workflows
- **Docker Registry** - Image storage

---

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Git
- Node.js 18+ (for local development)
- Python 3.11+ (for local development)

### 1. Clone Repository
```bash
git clone https://github.com/your-org/supachat.git
cd supachat
```

### 2. Setup Environment
```bash
cp .env.example .env
# Edit .env with your Supabase credentials
nano .env
```

### 3. Start with Docker Compose
```bash
docker-compose up -d
```

### 4. Access Application
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **Nginx**: http://localhost:80
- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090

---

## 💻 Local Development

### Backend (FastAPI)

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

API will be available at http://localhost:8000

### Frontend (React/Next.js)

```bash
cd frontend
npm install
npm run dev
```

Frontend will be available at http://localhost:3000

### Database Setup

Use Supabase PostgreSQL:

1. Create Supabase account at https://supabase.com
2. Create new project
3. Create table:

```sql
CREATE TABLE articles (
  id SERIAL PRIMARY KEY,
  title VARCHAR NOT NULL,
  topic VARCHAR NOT NULL,
  views INTEGER DEFAULT 0,
  engagement_rate FLOAT DEFAULT 0,
  shares INTEGER DEFAULT 0,
  published_date TIMESTAMP DEFAULT NOW()
);

INSERT INTO articles (title, topic, views, engagement_rate, shares) VALUES
('AI Trends 2024', 'AI', 450, 0.85, 32),
('DevOps Best Practices', 'DevOps', 320, 0.72, 18),
('Web3 Fundamentals', 'Web3', 210, 0.68, 12);
```

4. Add credentials to `.env`:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key
```

---

## 🐳 Docker Deployment

### Local Docker Compose

```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Rebuild images
docker-compose up -d --build
```

### Environment Variables

Create `.env` file:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key
NEXT_PUBLIC_API_URL=http://localhost:8000
BACKEND_PORT=8000
```

### Health Checks

All services include health checks:

```bash
# Check service health
docker-compose ps

# Manual health endpoint
curl http://localhost:8000/health
curl http://localhost:3000
curl http://localhost/health
```

---

## ☁️ AWS EC2 Deployment

### 1. Launch EC2 Instance

```bash
# Ubuntu 20.04 LTS
# t3.medium or larger (2GB RAM minimum)
# Security group: Allow ports 80, 443, 22, 3001, 9090
```

### 2. SSH into Instance

```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 3. Run Setup Script

```bash
curl -O https://raw.githubusercontent.com/your-org/supachat/main/scripts/setup-ec2.sh
chmod +x setup-ec2.sh
./setup-ec2.sh https://github.com/your-org/supachat.git
```

This will:
- Install Docker & Docker Compose
- Clone repository
- Setup environment
- Start services
- Configure firewall

### 4. Configure Environment

```bash
cd ~/supachat
nano .env
# Add your Supabase credentials
```

### 5. Start Application

```bash
docker-compose up -d
```

### 6. Access Application

- **Frontend**: http://your-ec2-ip
- **API**: http://your-ec2-ip/api
- **Grafana**: http://your-ec2-ip:3001
- **Prometheus**: http://your-ec2-ip:9090

---

## 🌐 Nginx Reverse Proxy

Nginx configuration in `nginx/nginx.conf`:

### Features

✅ **Routing**
- `/` → Frontend (React)
- `/api/` → Backend (FastAPI)
- `/metrics` → Prometheus metrics

✅ **Performance**
- Gzip compression
- Static asset caching (30 days)
- Connection pooling
- Buffer optimization

✅ **Security**
- Rate limiting (10 req/s general, 30 req/s API)
- Deny access to sensitive files
- Request validation

✅ **Reliability**
- Health check endpoint
- Upstream health monitoring
- Request timeouts

### Testing

```bash
# Test Nginx config
docker exec supachat-nginx nginx -t

# View access logs
docker exec supachat-nginx tail -f /var/log/nginx/access.log

# View error logs
docker exec supachat-nginx tail -f /var/log/nginx/error.log
```

---

## 🔁 CI/CD Pipeline

### GitHub Actions Workflow (`.github/workflows/deploy.yml`)

#### Stages

1. **Build**
   - Build Docker images
   - Run tests
   - Check linting

2. **Deploy** (on push to main)
   - Connect to EC2 via SSH
   - Run deployment script
   - Health checks

3. **Monitoring**
   - Verify service health
   - Notify deployment status

### Setup CI/CD

1. Add secrets to GitHub repository:
   ```
   EC2_HOST       = your-ec2-ip
   EC2_USER       = ubuntu
   EC2_KEY        = (content of private key)
   SUPABASE_URL   = https://your-project.supabase.co
   SUPABASE_KEY   = your-anon-key
   SUPABASE_SERVICE_KEY = your-service-key
   ```

2. Push to main branch:
   ```bash
   git add .
   git commit -m "Deploy updates"
   git push origin main
   ```

3. Monitor workflow:
   - Go to GitHub repo → Actions
   - Watch build and deployment progress

### Rollback

If deployment fails, rollback with:

```bash
cd ~/supachat
bash scripts/rollback.sh
```

This restores the previous working deployment.

---

## 📊 Monitoring & Logging

### Prometheus

**Metrics collected:**
- HTTP request count & latency
- NL query processing time
- FastAPI metrics
- Container CPU/Memory

**Access**: http://localhost:9090

**Example queries:**
```
# Request count
rate(supachat_requests_total[5m])

# Query duration
histogram_quantile(0.95, supachat_query_duration_seconds)

# NL queries processed
supachat_nl_queries_total
```

### Grafana

**Features:**
- Pre-configured Prometheus datasource
- System metrics dashboard
- Application performance dashboard

**Access**: http://localhost:3001 (admin/admin)

**Create Dashboard:**
1. New dashboard → Add panel
2. Select Prometheus datasource
3. Build queries visually

### Loki

**Logs aggregated from:**
- Nginx access/error logs
- Backend application logs
- Frontend logs (if configured)

**Access**: http://localhost:3100

**Query language (LogQL):**
```
{job="backend"}
{container_name="supachat-backend"} | json
| level="error"
```

### Health Checks

Run automated health checks:

```bash
bash scripts/health-check.sh localhost

# Sample output:
# 🔍 Running health checks for SupaChat at localhost...
# 📋 Application Status:
# ✓ Frontend (Port 80): Running
# ✓ Backend API (Port 8000): Running
# ✓ Nginx Reverse Proxy: Running
# 📊 Monitoring Stack:
# ✓ Prometheus (Port 9090): Running
```

---

## 🐛 Troubleshooting

### Backend not responding

```bash
# Check logs
docker-compose logs backend

# Check health endpoint
curl http://localhost:8000/health

# Restart service
docker-compose restart backend
```

### Frontend shows blank page

```bash
# Check logs
docker-compose logs frontend

# Check frontend is reachable
curl http://localhost:3000

# Clear browser cache and reload
```

### Database connection failed

```bash
# Verify Supabase credentials in .env
nano .env

# Restart backend
docker-compose restart backend

# Check connection from container
docker-compose exec backend python -c "from supabase import create_client; create_client('YOUR_URL', 'YOUR_KEY')"
```

### Nginx 502 Bad Gateway

```bash
# Check backend is running
docker-compose ps backend

# Check upstream availability
docker exec supachat-nginx curl http://backend:8000/health

# Check Nginx logs
docker logs supachat-nginx
```

### High memory usage

```bash
# Check Docker stats
docker stats

# Reduce container limits in docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
```

### CI/CD deployment failing

1. Check GitHub Actions logs
2. Verify EC2 security group allows SSH (port 22)
3. Verify SSH key is added to GitHub secrets
4. Check EC2 instance has internet connection
5. Verify docker-compose.yml is valid: `docker-compose config`

---

## 📈 DevOps Lifecycle

### Phase 1: Build ✅
- ✓ FastAPI backend with MCP integration
- ✓ React/Next.js frontend with Recharts
- ✓ Supabase PostgreSQL integration

### Phase 2: Dockerize ✅
- ✓ Multi-stage Dockerfiles
- ✓ docker-compose orchestration
- ✓ Health checks
- ✓ Environment management

### Phase 3: Deploy ✅
- ✓ AWS EC2 automation
- ✓ Reproducible deployment
- ✓ Zero-downtime updates

### Phase 4: Reverse Proxy ✅
- ✓ Nginx configuration
- ✓ Gzip compression
- ✓ Rate limiting
- ✓ Caching

### Phase 5: CI/CD ✅
- ✓ GitHub Actions workflow
- ✓ Automated testing
- ✓ Automated deployment
- ✓ Rollback capability

### Phase 6: Monitoring ✅
- ✓ Prometheus metrics
- ✓ Grafana dashboards
- ✓ Loki log aggregation
- ✓ Health monitoring

---

## 📚 Documentation

### API Documentation

**Auto-generated FastAPI docs:**
```
http://localhost:8000/docs          # Swagger UI
http://localhost:8000/redoc         # ReDoc
```

### Query Examples

**Show trending topics:**
```
POST /query
{
  "query": "Show top trending topics in last 30 days"
}
```

Response includes SQL, results, execution time, and automatically visualizes as charts.

### Custom MCP Integration

To extend with custom MCP tools:

1. Edit `backend/main.py` `translate_nl_to_sql()` function
2. Add SQL templates for new query types
3. Restart backend: `docker-compose restart backend`

---

## 🚀 Production Checklist

Before deploying to production:

- [ ] Update `NEXT_PUBLIC_API_URL` to your domain
- [ ] Set strong Grafana admin password
- [ ] Enable HTTPS (use AWS ALB or certbot)
- [ ] Configure proper CORS origins
- [ ] Set rate limiting thresholds
- [ ] Configure log retention policies
- [ ] Test rollback procedure
- [ ] Monitor Grafana dashboards
- [ ] Setup alerts in Prometheus
- [ ] Document custom configurations
- [ ] Setup SSL certificates
- [ ] Configure backup strategy

---

## 📞 Support & Resources

- **Supabase Docs**: https://supabase.com/docs
- **FastAPI Docs**: https://fastapi.tiangolo.com
- **Next.js Docs**: https://nextjs.org/docs
- **Docker Docs**: https://docs.docker.com
- **Nginx Docs**: https://nginx.org/en/docs
- **Prometheus Docs**: https://prometheus.io/docs
- **Grafana Docs**: https://grafana.com/docs/grafana

---

## 📝 License

MIT License - See LICENSE file

---

## 🙌 Contributing

1. Create feature branch: `git checkout -b feature/your-feature`
2. Commit changes: `git commit -m "Add feature"`
3. Push to branch: `git push origin feature/your-feature`
4. Open Pull Request

---

**Last Updated**: January 2024
**Version**: 1.0.0
**Status**: Production Ready ✅
