# CloudLab Environment

Comprehensive cloud laboratory environment dengan Docker containerization, reverse proxy, monitoring stack, dan CI/CD pipeline.

## 🏗️ Arsitektur

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                    ┌────▼────┐
                    │  Nginx  │ (Reverse Proxy + SSL)
                    │  :80    │
                    │  :443   │
                    └────┬────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
   │Node.js  │     │Python   │     │Grafana  │
   │App      │     │Flask    │     │:3000    │
   │:3001    │     │API      │     └────┬────┘
   └────┬────┘     │:5000    │          │
        │          └────┬────┘          │
        │               │               │
        └───────┬───────┴───────────────┘
                │
         ┌──────▼──────┐
         │ Prometheus  │ (Metrics Collection)
         │    :9090    │
         └─────────────┘
```

## 🚀 Quick Start

CloudLab dapat di-deploy dengan dua cara:

### Option 1: Docker Compose (Recommended untuk Development)

#### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git

#### Installation

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd cloud-lab
   ```

2. **Generate SSL certificates** (sudah otomatis dibuat)
   ```bash
   # Jika perlu regenerate:
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout nginx/ssl/key.pem \
     -out nginx/ssl/cert.pem \
     -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=localhost"
   ```

3. **Start semua services**
   ```bash
   docker-compose up -d
   ```

4. **Verify services running**
   ```bash
   docker-compose ps
   ```

## 📊 Service Endpoints

| Service | URL | Credentials |
|---------|-----|-------------|
| **Node.js App** | https://localhost/ | - |
| **Python API** | https://localhost/api | - |
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Nginx Status** | https://localhost/nginx_status | Internal only |

### Health Checks

```bash
# Node.js App
curl -k https://localhost/health

# Python API
curl -k https://localhost/api/health

# Prometheus
curl http://localhost:9090/-/healthy

# Grafana
curl http://localhost:3000/api/health
```

### Option 2: Kubernetes (Recommended untuk Production)

#### Prerequisites

- kubectl v1.28+
- Kubernetes cluster (Minikube/Kind/GKE/EKS/AKS)
- Docker Engine 20.10+
- Git

#### Quick Deploy

```bash
# 1. Clone repository
git clone <repository-url>
cd cloud-lab

# 2. Run deployment script
./k8s/scripts/deploy.sh

# 3. Access applications via port-forward
kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps
kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring
```

**� Dokumentasi Lengkap:**
- [Kubernetes Deployment Guide](k8s/README.md) - Setup dan deployment detail
- [Migration Guide](MIGRATION.md) - Migrasi dari Docker Compose ke Kubernetes

## 📊 Service Endpoints

### Docker Compose

| Service | URL | Credentials |
|---------|-----|-------------|
| **Node.js App** | https://localhost/ | - |
| **Python API** | https://localhost/api | - |
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Nginx Status** | https://localhost/nginx_status | Internal only |

### Kubernetes (via Port Forward)

| Service | Command | URL |
|---------|---------|-----|
| **Node.js App** | `kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps` | http://localhost:3001 |
| **Python API** | `kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps` | http://localhost:5000 |
| **Grafana** | `kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring` | http://localhost:3000 |
| **Prometheus** | `kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring` | http://localhost:9090 |

### Health Checks (Docker Compose)

```bash
# Node.js App
curl -k https://localhost/health

# Python API
curl -k https://localhost/api/health

# Prometheus
curl http://localhost:9090/-/healthy

# Grafana
curl http://localhost:3000/api/health
```

### Health Checks (Kubernetes)

```bash
# Check pod status
kubectl get pods -n cloudlab-apps
kubectl get pods -n cloudlab-monitoring

# Test endpoints via port-forward
kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps &
curl http://localhost:3001/health

kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps &
curl http://localhost:5000/health
```

## 🎯 Deployment Comparison

| Feature | Docker Compose | Kubernetes |
|---------|---------------|------------|
| **Setup Complexity** | ⭐ Simple | ⭐⭐⭐ Advanced |
| **Scalability** | Manual | Auto (HPA) |
| **High Availability** | Limited | Built-in |
| **Production Ready** | Development | Production |
| **Resource Usage** | ~2GB RAM | ~4GB RAM |
| **Learning Curve** | Easy | Moderate |

**Rekomendasi:**
- 🔧 **Development**: Gunakan Docker Compose untuk development lokal yang cepat
- 🚀 **Production**: Gunakan Kubernetes untuk production deployment dengan HA dan auto-scaling

## 🔧 Development (Docker Compose)

### Struktur Direktori

> **💡 Catatan Penting:** Folder `apps/` dan `k8s/apps/` adalah **BERBEDA** dan **TIDAK duplikasi**!
> - `apps/` = Source code aplikasi (untuk build Docker images)
> - `k8s/apps/` = Kubernetes deployment configs (untuk deploy ke cluster)

```
cloud-lab/
├── apps/                                # 📦 APPLICATION SOURCE CODE
│   └── demo-apps/                       # (Digunakan untuk build Docker images)
│       ├── nodejs-app/                  # Node.js Express application
│       │   ├── Dockerfile               # ← Build instructions
│       │   ├── package.json             # ← Dependencies
│       │   └── server.js                # ← Application code
│       └── python-app/                  # Python Flask API
│           ├── Dockerfile               # ← Build instructions
│           ├── requirements.txt         # ← Dependencies
│           └── app.py                   # ← Application code
│
├── ci/                                  # 🔄 CI/CD PIPELINE
│   ├── github-actions.yml               # GitHub Actions workflow
│   └── README.md                        # CI/CD documentation
│
├── monitoring/                          # 📊 MONITORING (Docker Compose)
│   ├── prometheus.yml                   # Prometheus config
│   ├── alerts.yml                       # Alert rules
│   └── grafana/
│       ├── datasources.yml              # Grafana datasources
│       ├── dashboards.yml               # Dashboard provisioning
│       └── dashboards/                  # Dashboard JSON files
│
├── nginx/                               # 🌐 REVERSE PROXY (Docker Compose)
│   ├── nginx.conf                       # Main Nginx config
│   ├── ssl/                             # SSL certificates
│   └── conf.d/                          # Additional configs
│
├── k8s/                                 # ☸️ KUBERNETES MANIFESTS
│   │                                    # (Deployment configurations, BUKAN source code)
│   ├── README.md                        # Kubernetes deployment guide
│   ├── kustomization.yaml               # Kustomize config
│   ├── base/                            # Base configurations
│   │   ├── namespace.yaml               # Namespaces
│   │   ├── configmaps/                  # ConfigMaps (Nginx, Prometheus)
│   │   └── secrets/                     # Secrets (SSL, credentials)
│   ├── apps/                            # 🚀 APPLICATION DEPLOYMENTS
│   │   ├── nodejs-app/                  # (YAML configs, bukan source code!)
│   │   │   ├── deployment.yaml          # ← How to deploy
│   │   │   ├── service.yaml             # ← How to expose
│   │   │   └── hpa.yaml                 # ← How to scale
│   │   └── python-app/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── hpa.yaml
│   ├── monitoring/                      # Monitoring stack for K8s
│   │   ├── prometheus/                  # Prometheus StatefulSet
│   │   └── grafana/                     # Grafana Deployment
│   ├── ingress/                         # Ingress configs
│   │   ├── ingress.yaml                 # Routing rules
│   │   └── cert-manager.yaml            # SSL automation
│   └── scripts/                         # Helper scripts
│       ├── deploy.sh                    # Automated deployment
│       └── cleanup.sh                   # Cleanup script
│
├── scripts/                             # 🛠️ UTILITY SCRIPTS (Docker Compose)
│   ├── setup.sh
│   └── cleanup.sh
│
├── docker-compose.yml                   # 🐳 Docker Compose orchestration
├── MIGRATION.md                         # 📖 Migration guide
└── README.md                            # This file
```

#### Penjelasan Struktur

**Separation of Concerns:**

| Directory | Purpose | Used By | Contains |
|-----------|---------|---------|----------|
| `apps/` | **Source code** untuk build images | Docker Compose & Kubernetes | Dockerfile, source code, dependencies |
| `k8s/apps/` | **Deployment configs** untuk K8s | Kubernetes only | YAML manifests (deployment, service, hpa) |
| `monitoring/` | Monitoring configs | Docker Compose only | Prometheus/Grafana configs |
| `k8s/monitoring/` | Monitoring configs | Kubernetes only | K8s manifests untuk Prometheus/Grafana |

**Workflow:**
```
1. Build:    apps/demo-apps/nodejs-app/  →  docker build  →  cloudlab-nodejs-app:latest
2. Deploy:   k8s/apps/nodejs-app/        →  kubectl apply →  Running pods in cluster
```

**Analogi:**
- `apps/` = Dapur (tempat masak/build)
- `k8s/apps/` = Buku menu (cara sajikan/deploy)
```

### Melihat Logs (Docker Compose)

```bash
# Semua services
docker-compose logs -f

# Service tertentu
docker-compose logs -f nodejs-app
docker-compose logs -f python-app
docker-compose logs -f nginx
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## �🔧 Operations (Kubernetes)

### Melihat Logs

```bash
# View logs
kubectl logs -f deployment/nodejs-app -n cloudlab-apps
kubectl logs -f deployment/python-app -n cloudlab-apps
kubectl logs -f statefulset/prometheus -n cloudlab-monitoring

# Logs dari semua pods
kubectl logs -l app=nodejs-app -n cloudlab-apps --tail=100
```

### Scaling

```bash
# Manual scaling
kubectl scale deployment nodejs-app --replicas=5 -n cloudlab-apps

# Check HPA status
kubectl get hpa -n cloudlab-apps
```

### Cleanup

```bash
# Docker Compose
docker-compose down

# Kubernetes
./k8s/scripts/cleanup.sh
# atau
kubectl delete -k k8s/
```

### Menambah Service Baru

**Docker Compose:**
1. Buat direktori aplikasi di `apps/`
2. Tambahkan service di `docker-compose.yml`
3. Konfigurasi reverse proxy di `nginx/nginx.conf`
4. Tambahkan scrape config di `monitoring/prometheus.yml`
5. Tambahkan ke CI/CD pipeline di `ci/github-actions.yml` (matrix strategy)
6. Rebuild: `docker-compose up -d --build`

**Kubernetes:**
1. Buat direktori di `k8s/apps/<app-name>/`
2. Buat `deployment.yaml`, `service.yaml`, `hpa.yaml`
3. Update `k8s/kustomization.yaml` untuk include resources baru
4. Deploy: `kubectl apply -k k8s/`

> **💡 Tip:** Dengan matrix strategy di CI/CD, menambah aplikasi baru ke pipeline sangat mudah - cukup tambah 1 entry di matrix tanpa duplikasi kode. Lihat [`ci/README.md`](ci/README.md) untuk detail.

### Melihat Logs

```bash
# Semua services
docker-compose logs -f

# Service tertentu
docker-compose logs -f nodejs-app
docker-compose logs -f python-app
docker-compose logs -f nginx
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## 📈 Monitoring

### Prometheus Metrics

Setiap aplikasi expose metrics di endpoint `/metrics`:
- Node.js: http://localhost:3001/metrics
- Python: http://localhost:5000/metrics

### Grafana Dashboards

1. Login ke Grafana: http://localhost:3000
2. Credentials: `admin` / `admin123`
3. Prometheus datasource sudah auto-configured
4. Dashboards yang tersedia:
   - **CloudLab Overview** - Monitoring semua services (request rate, response time, error rate, CPU, memory, status)
   - **Node.js Application** - Metrics khusus Node.js (event loop lag, heap memory)
   - **Python API** - Metrics khusus Flask API (endpoint performance, resource usage)

Dashboards akan otomatis ter-load saat Grafana start.

### Alert Rules

Alert rules didefinisikan di `monitoring/alerts.yml`:
- Service down detection
- High CPU usage
- High memory usage
- HTTP error rate monitoring

## 🔒 Security

### SSL/TLS

- Self-signed certificates untuk development
- Untuk production, gunakan Let's Encrypt:
  ```bash
  # Install certbot
  sudo apt-get install certbot
  
  # Generate certificate
  sudo certbot certonly --standalone -d yourdomain.com
  
  # Update nginx/nginx.conf dengan path certificate baru
  ```

### Security Headers

Nginx sudah dikonfigurasi dengan security headers:
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection

## 🧪 Testing

### Manual Testing

```bash
# Test Node.js endpoints
curl -k https://localhost/
curl -k https://localhost/users
curl -k https://localhost/info

# Test Python API endpoints
curl -k https://localhost/api
curl -k https://localhost/api/products
curl -k https://localhost/api/products/1

# Test metrics collection
curl http://localhost:9090/api/v1/targets
```

### Automated Testing (CI/CD)

Pipeline CI/CD menggunakan **GitHub Actions** dengan **matrix strategy** untuk scalability:

**Pipeline Stages:**
1. **Validate** - Validasi Docker Compose dan Nginx config
2. **Build Apps** - Build semua aplikasi secara parallel menggunakan matrix
3. **Security Scan** - Vulnerability scanning dengan Trivy
4. **Integration Tests** - Test lengkap semua services

**Matrix Strategy untuk Build:**
```yaml
strategy:
  matrix:
    app:
      - name: nodejs-app
        context: ./apps/demo-apps/nodejs-app
        port: 3001
      - name: python-app
        context: ./apps/demo-apps/python-app
        port: 5000
```

**Keuntungan:**
- ✅ **Scalable** - Mudah menambah aplikasi baru
- ✅ **Parallel** - Semua apps di-build bersamaan
- ✅ **DRY** - Tidak ada duplikasi kode
- ✅ **Maintainable** - Satu template untuk semua apps

**Menambah Aplikasi ke CI/CD:**

Cukup tambahkan entry baru di matrix di file `ci/github-actions.yml`:
```yaml
- name: golang-app
  image: cloudlab-golang-app
  context: ./apps/demo-apps/golang-app
  port: 8080
  health_endpoint: /health
  metrics_endpoint: /metrics
  sleep_time: 5
```

Lihat dokumentasi lengkap di [`ci/README.md`](ci/README.md)

## 🚢 Deployment

### Development

```bash
docker-compose up -d
```

### Production

1. Update environment variables
2. Replace SSL certificates dengan production certs
3. Update Grafana admin password
4. Deploy dengan:
   ```bash
   docker-compose -f docker-compose.yml up -d
   ```

## 🛠️ Troubleshooting

### Port sudah digunakan

```bash
# Check port usage
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :3000
sudo lsof -i :9090

# Stop conflicting services atau ubah port di docker-compose.yml
```

### Container tidak start

```bash
# Check logs
docker-compose logs <service-name>

# Rebuild container
docker-compose up -d --build --force-recreate <service-name>
```

### SSL Certificate Error

```bash
# Regenerate certificates
cd nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=localhost"
```

### Prometheus tidak scrape metrics

1. Check Prometheus targets: http://localhost:9090/targets
2. Verify service expose `/metrics` endpoint
3. Check network connectivity antar containers
4. Review `monitoring/prometheus.yml` configuration

### Grafana tidak bisa connect ke Prometheus

1. Check Prometheus running: `docker-compose ps prometheus`
2. Verify datasource config di `monitoring/grafana/datasources.yml`
3. Test connection dari Grafana UI: Configuration → Data Sources

## 📝 Maintenance

### Backup Data

```bash
# Backup Grafana data
docker cp cloudlab-grafana:/var/lib/grafana ./backup/grafana

# Backup Prometheus data
docker cp cloudlab-prometheus:/prometheus ./backup/prometheus
```

### Update Images

```bash
# Pull latest images
docker-compose pull

# Recreate containers
docker-compose up -d --force-recreate
```

### Cleanup

```bash
# Stop semua services
docker-compose down

# Remove volumes (WARNING: akan hapus data)
docker-compose down -v

# Remove unused images
docker image prune -a
```

## 🤝 Contributing

1. Fork repository
2. Create feature branch
3. Commit changes
4. Push ke branch
5. Create Pull Request

## 📄 License

MIT License

## 📞 Support

Untuk issues atau questions, silakan buat issue di repository.

---

**Built with ❤️ for CloudLab**
