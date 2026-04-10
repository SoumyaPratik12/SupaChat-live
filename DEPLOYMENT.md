# SupaChat - Deployment Guide

## Step-by-Step Deployment Instructions

### Prerequisites
- AWS account with EC2 access
- SSH client (OpenSSH or PuTTY)
- GitHub account with repository access
- Supabase account with PostgreSQL database

---

## Local Testing (BEFORE Production)

### 1. Clone & Setup
```bash
git clone https://github.com/your-org/supachat.git
cd supachat
cp .env.example .env
```

### 2. Configure Environment
```bash
# Edit with your Supabase credentials
nano .env

# Required:
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key
```

### 3. Build & Test Locally
```bash
# Build images
docker-compose build

# Start services
docker-compose up -d

# Run health checks
bash scripts/health-check.sh localhost

# View logs
docker-compose logs -f
```

### 4. Verify Functionality
- Open http://localhost:80
- Test sample queries
- Check Grafana at http://localhost:3001
- Verify API at http://localhost:8000/docs

### 5. Cleanup (if testing)
```bash
docker-compose down
docker system prune -a
```

---

## AWS EC2 Deployment

### Phase 1: Launch EC2 Instance

#### 1.1 Create Instance via AWS Console

1. Go to **EC2 Dashboard** → **Instances** → **Launch Instance**
2. Select **Ubuntu 20.04 LTS** (HVM, SSD)
3. Choose instance type: **t3.medium** or **t3.large**
4. **Storage**: 20GB (General Purpose SSD)
5. **Security Group**:
   ```
   Inbound Rules:
   • SSH (22) from YOUR_IP
   • HTTP (80) from 0.0.0.0/0
   • HTTPS (443) from 0.0.0.0/0
   • Grafana (3001) from YOUR_IP (optional)
   • Prometheus (9090) from YOUR_IP (optional)
   
   Outbound Rules:
   • All (for Docker downloads & updates)
   ```
6. **Key Pair**: Create or select existing
7. Launch instance & wait for "running" state

#### 1.2 Get Instance Details
```bash
# You should have:
PUBLIC_IP=<ec2-public-ip>
KEY_FILE=<path-to-key.pem>

# Note the EC2 hostname/IP for later use
```

### Phase 2: SSH Access & System Setup

#### 2.1 Connect via SSH
```bash
chmod 600 /path/to/key.pem
ssh -i /path/to/key.pem ubuntu@YOUR_EC2_IP

# Verify connection
echo "✅ SSH Connection successful"
```

#### 2.2 Run Setup Script (AUTOMATED)
```bash
# From EC2 instance:
curl -O https://raw.githubusercontent.com/your-org/supachat/main/scripts/setup-ec2.sh
chmod +x setup-ec2.sh
./setup-ec2.sh https://github.com/your-org/supachat.git

# This installs:
# • Docker & Docker Compose
# • Git
# • Clones repository
# • Configures firewall
# • Sets up systemd service
# • Creates .env file
```

#### 2.3 Manual Setup (if needed)
```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

### Phase 3: Configure Application

#### 3.1 Clone Repository
```bash
cd ~
git clone https://github.com/your-org/supachat.git
cd supachat
```

#### 3.2 Create Environment File
```bash
cp .env.example .env
nano .env

# Update with your credentials:
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key
NEXT_PUBLIC_API_URL=http://YOUR_EC2_IP:8000
```

#### 3.3 Verify Configuration
```bash
# Check .env syntax
cat .env

# Verify docker-compose file
docker-compose config

# If no errors, continue to next step
```

### Phase 4: Start Services

#### 4.1 Build Images
```bash
cd ~/supachat
docker-compose build

# This may take 5-10 minutes for first build
# Subsequent builds will use cache
```

#### 4.2 Start Services
```bash
docker-compose up -d

# Wait for services to be ready
sleep 20

# Check status
docker-compose ps

# Expected output:
# supachat-backend   | UP
# supachat-frontend  | UP
# supachat-nginx     | UP
# supachat-prometheus| UP
# supachat-grafana   | UP
# supachat-loki      | UP
```

#### 4.3 View Logs
```bash
# All services
docker-compose logs

# Specific service
docker-compose logs backend

# Follow logs
docker-compose logs -f backend
```

### Phase 5: Verify Deployment

#### 5.1 Run Health Checks
```bash
bash scripts/health-check.sh YOUR_EC2_IP

# Should show all services as ✓ Running
```

#### 5.2 Access Application
```
Frontend:   http://YOUR_EC2_IP/
API:        http://YOUR_EC2_IP/api/health
Grafana:    http://YOUR_EC2_IP:3001 (admin/admin)
Prometheus: http://YOUR_EC2_IP:9090
```

#### 5.3 Test Query
```bash
# From your local machine:
curl -X POST http://YOUR_EC2_IP/api/query \
  -H "Content-Type: application/json" \
  -d '{"query": "Show top trending topics"}'

# Should return JSON with results
```

---

## CI/CD Pipeline Setup

### Phase 6: GitHub Actions Configuration

#### 6.1 Add GitHub Secrets

Go to **GitHub Repo** → **Settings** → **Secrets** → **New repository secret**

Add these secrets:
```
EC2_HOST = YOUR_EC2_IP
EC2_USER = ubuntu
EC2_KEY = (content of your private key)
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_KEY = your-anon-key
SUPABASE_SERVICE_KEY = your-service-key
```

To get private key content:
```bash
cat /path/to/key.pem
# Copy entire output and paste into GitHub secret
```

#### 6.2 Verify Workflow File

Check `.github/workflows/deploy.yml` exists and is properly formatted:
```bash
git show .github/workflows/deploy.yml | head -30
```

#### 6.3 Test Deployment

Push to main branch to trigger CI/CD:
```bash
cd /path/to/local/repo
git add .
git commit -m "Test deployment"
git push origin main
```

Monitor deployment:
1. Go to GitHub → **Actions** tab
2. Click on workflow run
3. View build logs
4. Wait for deployment to complete

---

## Monitoring Setup

### Phase 7: Configure Monitoring Stack

#### 7.1 Grafana Initial Setup
1. Access http://YOUR_EC2_IP:3001
2. Login: admin / admin
3. Change password (security)
4. **Configuration** → **Data Sources**
   - Prometheus should be pre-configured
   - Loki should be pre-configured
5. **Dashboards** → Import pre-built dashboards

#### 7.2 Create Custom Dashboard

**Node Exporter Metrics:**
1. **New Dashboard** → **Add Panel**
2. **Query**: `rate(container_cpu_usage_seconds_total[5m])`
3. **Legend**: `{{container_name}}`
4. **Save Panel**

**Request Rate:**
1. **Add Panel**
2. **Query**: `rate(supachat_requests_total[1m])`
3. **Group by**: `endpoint, status`
4. **Save Panel**

**Query Duration:**
1. **Add Panel**
2. **Query**: `histogram_quantile(0.95, supachat_query_duration_seconds_bucket)`
3. **Legend**: `p95 latency`

#### 7.3 Setup Alerts

In Prometheus:
1. Access http://YOUR_EC2_IP:9090
2. **Alerts** → Create alert rules
3. Example:
   ```
   High Error Rate:
   rate(supachat_requests_total{status=~"5.."}[5m]) > 0.05
   
   High Latency:
   histogram_quantile(0.95, supachat_query_duration_seconds) > 2
   ```

---

## Maintenance Operations

### Regular Maintenance

#### Daily
```bash
# Check service health
bash scripts/health-check.sh YOUR_EC2_IP

# View recent logs
docker-compose logs --tail=100 backend
```

#### Weekly
```bash
# Check disk usage
df -h

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Prune old Docker images
docker image prune -f --filter "until=72h"
```

#### Monthly
```bash
# Backup volumes
docker run --rm -v supachat_prometheus-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

# Review & rotate logs
sudo logrotate -f /etc/logrotate.d/supachat

# Test rollback procedure
bash scripts/rollback.sh
```

### Troubleshooting

#### Service Health Monitoring
```bash
# Check all containers
docker ps -a

# Check specific service
docker-compose logs backend

# Check resource usage
docker stats

# Force restart
docker-compose restart backend
```

#### Database Connectivity
```bash
# Test Supabase connection
curl -X POST http://YOUR_EC2_IP/api/query \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'

# Check environment variables
docker-compose exec backend env | grep SUPABASE
```

#### Log Analysis
```bash
# Backend errors
docker-compose logs backend | grep -i error

# Nginx errors
docker-compose logs nginx | grep error

# Check all error logs
docker-compose logs | grep -i error
```

---

## Scaling (if Needed)

### Horizontal Scaling
1. **Create AMI** from current EC2 instance
2. **Launch Load Balancer** (AWS ALB)
3. **Create Auto-Scaling Group** with AMI
4. **Point Route53** to load balancer

### Vertical Scaling
1. **Stop instance**: `sudo shutdown -h now`
2. **Create snapshot** (backup)
3. **Change instance type**: Stop → Right-click → Instance Settings → Change Instance Type
4. **Select larger type** (t3.large, t3.xlarge)
5. **Start instance**
6. Verify services: `docker-compose ps`

---

## Rollback Procedure

### If Deployment Fails

#### Automated Rollback
```bash
cd ~/supachat
bash scripts/rollback.sh

# Select previous backup
# Services will be restored and restarted
```

#### Manual Rollback
```bash
# Stop current deployment
docker-compose down

# View backup
ls -la backups/

# Restore specific backup
cp backups/docker-compose_TIMESTAMP.yml docker-compose.yml
cp backups/.env_TIMESTAMP .env

# Restart services
docker-compose up -d

# Verify
bash scripts/health-check.sh
```

---

## Security Checklist

Before Production:

- [ ] **SSH Key**: Restrict permissions `chmod 600 key.pem`
- [ ] **Security Groups**: Only open required ports
- [ ] **Firewall**: Configure `ufw` rules
- [ ] **SSL/TLS**: Setup HTTPS with Let's Encrypt
- [ ] **Credentials**: Never commit `.env` to git
- [ ] **Secrets**: Use GitHub Actions secrets
- [ ] **Updates**: Regular security patches
- [ ] **Monitoring**: Grafana alerts configured
- [ ] **Backups**: Test restore procedure
- [ ] **Logging**: Verify log retention

---

## Cost Optimization

### Reduce Monthly Bill

```
Current Estimate (t3.medium): $37/month
├── EC2 t3.medium: $30.51
├── EBS 20GB: $2.00
├── Network: $4.49

Optimization Options:
-  Use t3.micro for dev: $8.41/month
- Use On-Demand + Spot Mix: Save 30%
- Use Reserved Instances: Save 40%
- Use Supabase Free Tier: Save $50+

Estimated Optimized: $15-20/month
```

---

## References

- **AWS EC2 Docs**: https://docs.aws.amazon.com/ec2/
- **Docker Docs**: https://docs.docker.com
- **GitHub Actions**: https://docs.github.com/en/actions
- **Let's Encrypt**: https://letsencrypt.org
- **Supabase**: https://supabase.com/docs

---

**Deployment Guide Version**: 1.0  
**Last Updated**: January 2024  
**Status**: Ready for Production ✅
