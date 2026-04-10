# SupaChat - Quick Reference Guide

## 🚀 Most Useful Commands

### Local Development

```bash
# Start all services
docker-compose up -d

# View logs (all or specific service)
docker-compose logs -f
docker-compose logs -f backend

# Stop services
docker-compose down

# Rebuild images (after code changes)
docker-compose up -d --build

# Check service status
docker-compose ps

# Health check
bash scripts/health-check.sh localhost
```

### Frontend Development

```bash
# Run frontend in development mode
cd frontend
npm install
npm run dev          # http://localhost:3000

# Build for production
npm run build
npm start
```

### Backend Development

```bash
# Run backend in development mode
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py       # http://localhost:8000

# Access API docs
# http://localhost:8000/docs
```

### Database (Supabase)

```bash
# Test database connection
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query": "Show top articles"}'

# View in browser
# http://localhost/api/health
```

### Monitoring & Logging

```bash
# Prometheus
# http://localhost:9090

# Grafana
# http://localhost:3001 (admin/admin)

# View metrics endpoint
curl http://localhost:8000/metrics

# View logs
docker-compose logs backend
docker-compose logs nginx
docker-compose logs prometheus
```

---

## 🌐 EC2 Deployment

### First-Time Setup

```bash
# SSH into instance
ssh -i key.pem ubuntu@YOUR_EC2_IP

# Automated setup (installs Docker, clones repo, etc.)
curl -O https://raw.githubusercontent.com/your-org/supachat/main/scripts/setup-ec2.sh
chmod +x setup-ec2.sh
./setup-ec2.sh https://github.com/your-org/supachat.git

# OR manual setup
sudo apt-get update
sudo apt-get install -y docker.io
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

git clone https://github.com/your-org/supachat.git
cd supachat
cp .env.example .env
nano .env        # Add Supabase credentials
docker-compose up -d
```

### Ongoing Operations

```bash
# Check service health
bash scripts/health-check.sh YOUR_EC2_IP

# View logs
cd ~/supachat
docker-compose logs -f backend

# Update & redeploy
cd ~/supachat
git pull origin main
docker-compose up -d --build

# Graceful restart
docker-compose restart backend

# Stop everything
docker-compose down

# Rollback to previous version
bash scripts/rollback.sh
```

---

## 🔄 CI/CD & Deployment

### GitHub Actions

```bash
# Setup: Add secrets to GitHub repo
# EC2_HOST, EC2_USER, EC2_KEY, SUPABASE_URL, etc.

# Deploy by pushing to main
git add .
git commit -m "Changes to deploy"
git push origin main

# Monitor in GitHub
# Repo → Actions → View latest run

# Check deployment logs
# Repo → Actions → deploy.yml → Click run
```

### Manual Deployment (if needed)

```bash
# SSH to EC2
ssh -i key.pem ubuntu@YOUR_EC2_IP
cd ~/supachat

# Run deployment script
bash scripts/deploy.sh

# Verify deployment
bash scripts/health-check.sh
```

---

## 📊 Monitoring Commands

### Prometheus Queries

```bash
# In browser: http://localhost:9090/graph

# Request rate (per second)
rate(supachat_requests_total[5m])

# Error rate
rate(supachat_requests_total{status=~"5.."}[5m])

# p95 latency
histogram_quantile(0.95, supachat_query_duration_seconds)

# Query count
sum(supachat_nl_queries_total)

# CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Memory usage (bytes)
container_memory_usage_bytes
```

### Grafana Dashboard Creation

```
1. Open http://localhost:3001
2. Login (admin/admin)
3. Click "+" → Dashboard
4. Add Panel
5. Select Prometheus
6. Build query (examples above)
7. Change visualization
8. Save dashboard
```

### Looking at Logs (Loki)

```
1. Open http://localhost:3001
2. Go to Explore
3. Select Loki datasource
4. Build query:
   {container_name="supachat-backend"}
   {container_name="supachat-nginx"}
   
5. Click "Run query"
6. View matching logs
```

---

## 🐛 Troubleshooting

### Backend not responding

```bash
# Check if service is running
docker-compose ps backend

# Check logs
docker-compose logs backend

# Try to restart
docker-compose restart backend

# Check health endpoint
curl http://localhost:8000/health

# Check environment variables
docker-compose exec backend env | grep SUPABASE
```

### Frontend blank page

```bash
# Check if service is running
docker-compose ps frontend

# Check logs
docker-compose logs frontend

# Check if accessible
curl http://localhost:3000

# Restart frontend
docker-compose restart frontend
```

### Database connection failed

```bash
# Verify .env has correct credentials
cat .env | grep SUPABASE

# Test Supabase connection
docker-compose exec backend curl -v https://YOUR_SUPABASE_URL

# Restart backend
docker-compose restart backend

# Check logs for specific error
docker-compose logs backend | grep -i supabase
```

### Nginx 502 Bad Gateway

```bash
# Check if backend is running
docker-compose ps backend

# Check if backend thinks it's healthy
curl http://localhost:8000/health

# Check nginx logs
docker-compose logs nginx

# Restart nginx
docker-compose restart nginx

# Verify nginx config
docker-compose exec nginx nginx -t
```

### High memory usage

```bash
# Check which service
docker stats

# Restart problematic service
docker-compose restart backend

# Check container logs for memory leaks
docker-compose logs backend

# Reduce Prometheus retention
# Edit docker-compose.yml and restart
```

---

## 🔐 Security Checklist

```bash
# Before production:

# 1. Change Grafana password
# Admin panel → Account → Change password

# 2. Update environment variables
nano .env
# Verify all credentials are set

# 3. Verify firewall rules (AWS)
# Security Group → Inbound Rules
# - Only allow necessary ports
# - Restrict SSH to your IP

# 4. Enable HTTPS
# Use AWS Certificate Manager or Let's Encrypt
# Update Nginx config

# 5. Backup data
docker run --rm -v supachat_prometheus-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/backup.tar.gz -C /data .

# 6. Test rollback
bash scripts/rollback.sh
```

---

## 📱 Port Reference

| Service | Port | Purpose | Access |
|---------|------|---------|--------|
| Nginx | 80 | HTTP | Public (http://ip) |
| Nginx | 443 | HTTPS | Public (https://ip) |
| Frontend | 3000 | Development | Internal (:3000) |
| Backend | 8000 | API | Internal (:8000) |
| Prometheus | 9090 | Metrics | http://ip:9090 |
| Grafana | 3001 | Dashboards | http://ip:3001 |
| Loki | 3100 | Logs | Internal (:3100) |

---

## 📚 Documentation Map

| Document | Purpose | Key Topics |
|----------|---------|-----------|
| README.md | Main guide | Quick start, all features |
| ARCHITECTURE.md | Technical design | System design, components |
| DEPLOYMENT.md | Deployment guide | Step-by-step procedures |
| MONITORING.md | Monitoring guide | Metrics, dashboards, logs |
| PROJECT_STRUCTURE.md | File organization | File locations, purposes |

---

## 🎯 Common Tasks

### My app isn't working!
1. Check services: `docker-compose ps`
2. View errors: `docker-compose logs`
3. Restart: `docker-compose restart <service>`
4. Full restart: `docker-compose down && docker-compose up -d`

### I want to deploy changes
1. Test locally: `docker-compose up -d`
2. Push to github: `git push origin main`
3. Watch CI/CD: GitHub Actions tab
4. Verify: `bash scripts/health-check.sh`

### My monitoring isn't working
1. Check Prometheus: `curl http://localhost:9090/api/v1/query?query=up`
2. Check Grafana datasource: Settings → Data Sources → Test
3. Check Loki: Explore → Select Loki → Run query

### I need to rollback
1. Stay calm
2. Run: `bash scripts/rollback.sh`
3. Select previous version
4. Verify: `bash scripts/health-check.sh`

---

## 💡 Pro Tips

✅ **Log rotation**: Automatic via systemd
✅ **Backup strategy**: Auto-backup before each deployment
✅ **Monitoring alerts**: Setup in Prometheus → Alerts
✅ **Performance**: Increase container resources in docker-compose.yml
✅ **Scaling**: Use load balancer + multiple EC2 instances
✅ **Development**: Use `--build` flag when code changes: `docker-compose up -d --build`
✅ **Debugging**: Use `docker-compose exec bash` to enter containers
✅ **Health**: Run health checks daily: `bash scripts/health-check.sh`

---

## 🔗 Useful Links

- **Supabase Docs**: https://supabase.com/docs
- **FastAPI**: https://fastapi.tiangolo.com
- **Next.js**: https://nextjs.org/docs
- **Docker**: https://docs.docker.com
- **Nginx**: https://nginx.org/en/docs
- **Prometheus**: https://prometheus.io/docs
- **Grafana**: https://grafana.com/docs/grafana

---

## 📞 Emergency Contacts

For issues:
1. **Check logs**: `docker-compose logs`
2. **Check health**: `bash scripts/health-check.sh`
3. **Check docs**: README.md → Troubleshooting
4. **Rollback**: `bash scripts/rollback.sh`
5. **Restart**: `docker-compose restart`

---

**Updated**: January 2024  
**Status**: Ready for use ✅
