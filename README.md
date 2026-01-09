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

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git

### Installation

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

## 🔧 Development

### Struktur Direktori

```
cloud-lab/
├── apps/
│   └── demo-apps/
│       ├── nodejs-app/          # Node.js Express application
│       │   ├── Dockerfile
│       │   ├── package.json
│       │   └── server.js
│       └── python-app/          # Python Flask API
│           ├── Dockerfile
│           ├── requirements.txt
│           └── app.py
├── ci/
│   └── github-actions.yml       # CI/CD pipeline
├── monitoring/
│   ├── prometheus.yml           # Prometheus config
│   ├── alerts.yml               # Alert rules
│   └── grafana/
│       ├── datasources.yml      # Grafana datasources
│       ├── dashboards.yml       # Dashboard provisioning
│       └── dashboards/          # Dashboard JSON files
├── nginx/
│   ├── nginx.conf               # Main Nginx config
│   ├── ssl/                     # SSL certificates
│   └── conf.d/                  # Additional configs
└── docker-compose.yml           # Orchestration
```

### Menambah Service Baru

1. Buat direktori aplikasi di `apps/`
2. Tambahkan service di `docker-compose.yml`
3. Konfigurasi reverse proxy di `nginx/nginx.conf`
4. Tambahkan scrape config di `monitoring/prometheus.yml`
5. **Tambahkan ke CI/CD pipeline** di `ci/github-actions.yml` (matrix strategy)
6. Rebuild dan restart:
   ```bash
   docker-compose up -d --build
   ```

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
