# SupaChat - Getting Started Guide

## ✅ WHAT YOU NOW HAVE

A **production-ready DevOps full-stack application** with:

### ✨ Complete Application
- **Frontend**: React/Next.js with chatbot UI, query history, charts
- **Backend**: FastAPI with NL→SQL translation, API endpoints  
- **Database**: Supabase PostgreSQL integration
- **Monitoring**: Prometheus + Grafana + Loki

### 🚀 Production Deployment
- **Docker**: Multi-stage builds, docker-compose orchestration
- **AWS EC2**: Fully automated setup & deployment scripts
- **Nginx**: Reverse proxy with compression, caching, rate limiting
- **CI/CD**: GitHub Actions with automated build & deploy
- **Monitoring**: Complete observability stack

### 📚 Comprehensive Documentation
- README.md - Complete guide
- ARCHITECTURE.md - Technical design
- DEPLOYMENT.md - Step-by-step procedures
- MONITORING.md - Monitoring setup
- QUICK_REFERENCE.md - Common commands
- PROJECT_STRUCTURE.md - File organization

---

## 🎯 NEXT STEPS

### Step 1️⃣ - Prepare Your Environment (5 min)

**You need:**
- Supabase account (free tier is fine)
- AWS account (free tier available)
- GitHub account with repository access

**Create Supabase Project:**
1. Go to https://supabase.com
2. Create new project
3. Go to SQL Editor
4. Run this SQL:
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

5. Get your credentials:
   - Go to Settings → API
   - Copy: `Project URL` → `SUPABASE_URL`
   - Copy: `Anon Key` → `SUPABASE_KEY`
   - Copy: `Service Role Key` → `SUPABASE_SERVICE_KEY`

### Step 2️⃣ - Test Locally (10 min)

**On your computer:**
```bash
# 1. Navigate to project
cd supachat

# 2. Create .env file
cp .env.example .env

# 3. Edit with your credentials
nano .env
# Paste the three Supabase values

# 4. Start application
docker-compose up -d

# 5. Wait 30 seconds...

# 6. Access in browser:
# Frontend: http://localhost:3000
# Backend API: http://localhost:8000
# Grafana: http://localhost:3001 (admin/admin)
```

**Test it works:**
- Open http://localhost:3000
- Type: "Show top articles"
- Click Send
- You should see results!

### Step 3️⃣ - Deploy to AWS (15 min)

**1. Launch EC2 Instance:**
- Go to AWS Console
- EC2 → Instances → Launch Instance
- Select: Ubuntu 20.04 LTS
- Instance Type: t3.medium (minimum)
- Storage: 20GB
- Security Group:
  - Port 22 (SSH) - Your IP
  - Port 80 (HTTP) - 0.0.0.0/0
  - Port 443 (HTTPS) - 0.0.0.0/0
- Launch & wait 2 minutes

**2. SSH into instance:**
```bash
chmod 600 your-key.pem
ssh -i your-key.pem ubuntu@YOUR_EC2_IP
```

**3. Automated setup (all-in-one):**
```bash
curl -O https://raw.githubusercontent.com/your-org/supachat/main/scripts/setup-ec2.sh
chmod +x setup-ec2.sh
./setup-ec2.sh https://github.com/your-org/supachat.git
```

This will:
- ✅ Install Docker
- ✅ Clone your repository
- ✅ Setup environment
- ✅ Configure firewall
- ✅ Start services

**4. Configure credentials:**
```bash
cd ~/supachat
nano .env
# Paste your Supabase credentials (same as Step 1)
```

**5. Start services:**
```bash
docker-compose up -d
sleep 30  # Wait for startup
bash scripts/health-check.sh
```

**6. Access your app:**
```
http://YOUR_EC2_IP/
```

### Step 4️⃣ - Setup CI/CD (10 min)

**1. Add GitHub Secrets:**
- Go to GitHub Repo Settings → Secrets
- Add these 6 secrets:
```
EC2_HOST = YOUR_EC2_IP
EC2_USER = ubuntu
EC2_KEY = (contents of your-key.pem file)
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_KEY = your-anon-key
SUPABASE_SERVICE_KEY = your-service-key
```

**2. Deploy:**
```bash
# Make a change locally
echo "# Updated" >> README.md

# Push to main
git add .
git commit -m "Deploy update"
git push origin main

# Monitor in GitHub
# Repo → Actions → watch the deployment
```

**3. Done!** Your app auto-deploys on every push

### Step 5️⃣ - Setup Monitoring (5 min)

**1. Open Grafana:**
```
http://YOUR_EC2_IP:3001
Login: admin / admin
```

**2. Change admin password:**
- Click profile → Account
- Change password

**3. Create custom dashboard:**
- Click **+** → Dashboard
- Add Panel
- Select Prometheus
- Query: `rate(supachat_requests_total[5m])`
- Visualize & save

**4. View logs:**
- Go to Explore
- Select Loki
- Query: `{container_name="supachat-backend"}`
- See live logs

---

## 🏗️ PROJECT STRUCTURE AT A GLANCE

```
supachat/
├─ 📖 README.md                    ← Start here!
├─ 🚀 DEPLOYMENT.md                ← How to deploy
├─ 🏗️ ARCHITECTURE.md              ← System design
├─ 📊 MONITORING.md                ← Monitoring guide
├─ ⚡ QUICK_REFERENCE.md           ← Common commands
│
├─ ⚛️ frontend/                     ← React/Next.js
│  ├─ app/page.tsx                ← Main chat interface
│  └─ components/                 ← UI components
│
├─ 🐍 backend/                     ← FastAPI
│  └─ main.py                     ← API server
│
├─ 🐳 docker-compose.yml           ← 6 services
├─ Dockerfile.*                    ← Container images
├─ nginx/nginx.conf                ← Reverse proxy
│
├─ monitoring/                     ← Prometheus, Grafana, Loki
├─ scripts/                        ← Automation scripts
│  ├─ setup-ec2.sh
│  ├─ deploy.sh
│  └─ health-check.sh
│
└─ .github/workflows/deploy.yml    ← CI/CD pipeline
```

---

## 🔄 TYPICAL WORKFLOW

### As a Developer:
```bash
# Code locally
code frontend/  # Make changes

# Test
docker-compose up -d --build
# Open http://localhost:3000

# Deploy
git add .
git commit -m "Feature: ..."
git push origin main

# GitHub Actions auto-deploys!
```

### As an Operator:
```bash
# Check health
bash scripts/health-check.sh YOUR_EC2_IP

# View dashboards
# Open http://YOUR_EC2_IP:3001 (Grafana)

# Check logs
# Open http://YOUR_EC2_IP:3001 → Explore → Loki

# If something breaks:
bash scripts/rollback.sh  # Instant rollback!
```

---

## ⚡ KEY FEATURES READY TO USE

✅ **Build**
- FastAPI backend with NL→SQL MCP integration
- React/Next.js frontend with Recharts charts
- Supabase PostgreSQL database

✅ **Dockerize**
- Multi-stage Dockerfiles (optimized images)
- docker-compose with 6 services
- Health checks on all services

✅ **Deploy**
- Automated EC2 setup script
- Automated deployment script
- Zero-downtime updates

✅ **Reverse Proxy**
- Nginx with gzip compression
- Static asset caching
- Rate limiting
- Security headers

✅ **CI/CD**
- GitHub Actions pipeline
- Automated build & test
- Automated deployment
- Auto-rollback support

✅ **Monitoring**
- Prometheus metrics
- Grafana dashboards
- Loki log aggregation
- Health checks
- Alert support

✅ **Documentation**
- Complete README
- Architecture guide
- Deployment guide
- Monitoring guide
- Quick reference
- This getting started!

---

## 📈 WHAT'S NEXT?

### Short Term (Next Week)
1. ✅ Test locally
2. ✅ Deploy to AWS EC2
3. ✅ Verify everything works
4. 📝 Customize to your needs (colors, queries, etc.)

### Medium Term (Next Month)
1. 🔐 Enable HTTPS/SSL
2. 📧 Setup alerts in Grafana
3. 📱 Add more NL query templates
4. 🎨 Customize dashboard

### Long Term (Scaling)
1. 🚀 Add authentication
2. 📊 Add more data sources
3. 🔄 Multi-region deployment
4. 🎯 Kubernetes migration

---

## 🆘 TROUBLESHOOTING

### App won't start?
```bash
# View logs
docker-compose logs

# Restart
docker-compose down
docker-compose up -d
```

### Can't connect to Supabase?
```bash
# Check credentials in .env
cat .env | grep SUPABASE

# Verify in Supabase console
# Settings → API → Copy exact values
```

### GitHub Actions failing?
```bash
# Check secrets are set correctly
# Repo → Settings → Secrets

# Check EC2 instance security group
# Allow port 22 (SSH) from GitHub
```

### Monitoring not working?
```bash
# Check Prometheus
curl http://localhost:9090

# Check Grafana
http://localhost:3001

# Check logs
docker-compose logs prometheus
```

---

## 📚 DOCUMENTATION

| Document | Best For |
|----------|----------|
| README.md | Overall guide |
| QUICK_REFERENCE.md | Common commands |
| DEPLOYMENT.md | Detailed setup |
| ARCHITECTURE.md | Understanding design |
| MONITORING.md | Setup monitoring |
| This file | Getting started |

---

## 🎓 LEARNING RESOURCES

- **Supabase**: https://supabase.com/docs
- **FastAPI**: https://fastapi.tiangolo.com
- **React/Next.js**: https://nextjs.org/docs
- **Docker**: https://docs.docker.com
- **Nginx**: https://nginx.org/en/docs
- **GitHub Actions**: https://docs.github.com/en/actions
- **Prometheus**: https://prometheus.io/docs
- **Grafana**: https://grafana.com/docs/grafana

---

## 💬 COMMON QUESTIONS

**Q: Do I need AWS to test?**  
A: No! Test locally first with `docker-compose up -d`

**Q: How much will it cost?**  
A: ~$30-40/month for t3.medium EC2. Use cheaper instances to reduce.

**Q: Can I modify the queries?**  
A: Yes! Edit `backend/main.py` in `translate_nl_to_sql()` function

**Q: Is it production ready?**  
A: Yes! With proper setup, monitoring, and HTTPS

**Q: Can I scale it?**  
A: Yes! Use load balancers + multiple EC2 instances

**Q: What if something breaks?**  
A: Run `bash scripts/rollback.sh` instantly restore previous version

---

## ✨ YOU'RE READY!

Everything is set up and ready to go. Start with **Step 1** above and follow through.

**Total time to production**: ~30-45 minutes

Questions? Check the documentation or rerun health checks:
```bash
bash scripts/health-check.sh
```

---

**Happy deploying! 🚀**

**Project Version**: 1.0.0  
**Status**: Production Ready ✅  
**Last Updated**: January 2024
