# CloudLab Environment

Lingkungan laboratorium cloud komprehensif dengan kontainerisasi Docker, reverse proxy, monitoring stack, dan pipeline CI/CD.

## Arsitektur

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

## Panduan Memulai Cepat (Quick Start)

CloudLab dapat di-deploy dengan dua metode:

### Opsi 1: Docker Compose (Disarankan untuk Pengembangan)

#### Prasyarat

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git

#### Instalasi

1. **Clone repositori**
   ```bash
   git clone <repository-url>
   cd cloud-lab
   ```

2. **Generate sertifikat SSL** (sudah otomatis dibuat)
   ```bash
   # Jika perlu regenerate:
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout nginx/ssl/key.pem \
     -out nginx/ssl/cert.pem \
     -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=localhost"
   ```

3. **Jalankan semua layanan**
   ```bash
   docker-compose up -d
   ```

4. **Verifikasi layanan berjalan**
   ```bash
   docker-compose ps
   ```

## Endpoint Layanan

| Layanan | URL | Kredensial |
|---------|-----|-------------|
| **Node.js App** | https://localhost/ | - |
| **Python API** | https://localhost/api | - |
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Nginx Status** | https://localhost/nginx_status | Internal only |

### Pemeriksaan Kesehatan (Health Checks)

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

### Opsi 2: Kubernetes (Disarankan untuk Produksi)

#### Prasyarat

- kubectl v1.28+
- Kubernetes cluster (Minikube/Kind/GKE/EKS/AKS)
- Docker Engine 20.10+
- Git

#### Deployment Cepat

```bash
# 1. Clone repositori
git clone <repository-url>
cd cloud-lab

# 2. Jalankan skrip deployment
./k8s/scripts/deploy.sh

# 3. Akses aplikasi via port-forward
kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps
kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring
```

**Dokumentasi Lengkap:**
- [Panduan Deployment Kubernetes](k8s/README.md) - Setup dan deployment detail
- [Panduan Migrasi](MIGRATION.md) - Migrasi dari Docker Compose ke Kubernetes

## Endpoint Layanan

### Docker Compose

| Layanan | URL | Kredensial |
|---------|-----|-------------|
| **Node.js App** | https://localhost/ | - |
| **Python API** | https://localhost/api | - |
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Nginx Status** | https://localhost/nginx_status | Internal only |

### Kubernetes (via Port Forward)

| Layanan | Perintah | URL |
|---------|---------|-----|
| **Node.js App** | `kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps` | http://localhost:3001 |
| **Python API** | `kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps` | http://localhost:5000 |
| **Grafana** | `kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring` | http://localhost:3000 |
| **Prometheus** | `kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring` | http://localhost:9090 |

### Pemeriksaan Kesehatan (Docker Compose)

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

### Pemeriksaan Kesehatan (Kubernetes)

```bash
# Cek status pod
kubectl get pods -n cloudlab-apps
kubectl get pods -n cloudlab-monitoring

# Test endpoints via port-forward
kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps &
curl http://localhost:3001/health

kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps &
curl http://localhost:5000/health
```

## Perbandingan Deployment

| Fitur | Docker Compose | Kubernetes |
|---------|---------------|------------|
| **Kompleksitas Setup** | Sederhana | Lanjutan |
| **Skalabilitas** | Manual | Otomatis (HPA) |
| **Ketersediaan Tinggi** | Terbatas | Built-in |
| **Kesiapan Produksi** | Pengembangan | Produksi |
| **Penggunaan Sumber Daya** | ~2GB RAM | ~4GB RAM |
| **Kurva Pembelajaran** | Mudah | Menengah |

**Rekomendasi:**
- **Pengembangan**: Gunakan Docker Compose untuk pengembangan lokal yang cepat
- **Produksi**: Gunakan Kubernetes untuk deployment produksi dengan HA dan auto-scaling

## Pengembangan (Docker Compose)

### Struktur Direktori

> **Catatan Penting:** Direktori `apps/` dan `k8s/apps/` adalah **BERBEDA** dan **TIDAK duplikasi**!
> - `apps/` = Kode sumber aplikasi (untuk build Docker images)
> - `k8s/apps/` = Konfigurasi deployment Kubernetes (untuk deploy ke cluster)

```
cloud-lab/
├── apps/                                # APPLICATION SOURCE CODE
│   └── demo-apps/                       # (Digunakan untuk build Docker images)
│       ├── nodejs-app/                  # Node.js Express application
│       │   ├── Dockerfile               # ← Instruksi build
│       │   ├── package.json             # ← Dependensi
│       │   └── server.js                # ← Kode aplikasi
│       └── python-app/                  # Python Flask API
│           ├── Dockerfile               # ← Instruksi build
│           ├── requirements.txt         # ← Dependensi
│           └── app.py                   # ← Kode aplikasi
│
├── ci/                                  # CI/CD PIPELINE
│   ├── github-actions.yml               # GitHub Actions workflow
│   └── README.md                        # Dokumentasi CI/CD
│
├── monitoring/                          # MONITORING (Docker Compose)
│   ├── prometheus.yml                   # Prometheus config
│   ├── alerts.yml                       # Aturan alert
│   └── grafana/
│       ├── datasources.yml              # Grafana datasources
│       ├── dashboards.yml               # Dashboard provisioning
│       └── dashboards/                  # Dashboard JSON files
│
├── nginx/                               # REVERSE PROXY (Docker Compose)
│   ├── nginx.conf                       # Main Nginx config
│   ├── ssl/                             # Sertifikat SSL
│   └── conf.d/                          # Konfigurasi tambahan
│
├── k8s/                                 # KUBERNETES MANIFESTS
│   │                                    # (Konfigurasi deployment, BUKAN source code)
│   ├── README.md                        # Panduan deployment Kubernetes
│   ├── kustomization.yaml               # Kustomize config
│   ├── base/                            # Konfigurasi dasar
│   │   ├── namespace.yaml               # Namespaces
│   │   ├── configmaps/                  # ConfigMaps (Nginx, Prometheus)
│   │   └── secrets/                     # Secrets (SSL, credentials)
│   ├── apps/                            # APPLICATION DEPLOYMENTS
│   │   ├── nodejs-app/                  # (YAML configs, bukan source code!)
│   │   │   ├── deployment.yaml          # ← Cara deploy
│   │   │   ├── service.yaml             # ← Cara expose
│   │   │   └── hpa.yaml                 # ← Cara scale
│   │   └── python-app/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── hpa.yaml
│   ├── monitoring/                      # Monitoring stack untuk K8s
│   │   ├── prometheus/                  # Prometheus StatefulSet
│   │   └── grafana/                     # Grafana Deployment
│   ├── ingress/                         # Konfigurasi Ingress
│   │   ├── ingress.yaml                 # Aturan routing
│   │   └── cert-manager.yaml            # Otomasi SSL
│   └── scripts/                         # Skrip pembantu
│       ├── deploy.sh                    # Deployment otomatis
│       └── cleanup.sh                   # Skrip pembersihan
│
├── scripts/                             # UTILITY SCRIPTS (Docker Compose)
│   ├── setup.sh
│   └── cleanup.sh
│
├── docker-compose.yml                   # Orkestrasi Docker Compose
├── MIGRATION.md                         # Panduan migrasi
└── README.md                            # File ini
```

#### Penjelasan Struktur

**Pemisahan Tanggung Jawab (Separation of Concerns):**

| Direktori | Tujuan | Digunakan Oleh | Berisi |
|-----------|---------|---------|----------|
| `apps/` | **Source code** untuk build images | Docker Compose & Kubernetes | Dockerfile, source code, dependencies |
| `k8s/apps/` | **Deployment configs** untuk K8s | Kubernetes only | YAML manifests (deployment, service, hpa) |
| `monitoring/` | Monitoring configs | Docker Compose only | Prometheus/Grafana configs |
| `k8s/monitoring/` | Monitoring configs | Kubernetes only | K8s manifests untuk Prometheus/Grafana |

**Alur Kerja:**
```
1. Build:    apps/demo-apps/nodejs-app/  →  docker build  →  cloudlab-nodejs-app:latest
2. Deploy:   k8s/apps/nodejs-app/        →  kubectl apply →  Running pods in cluster
```

**Analogi:**
- `apps/` = Dapur (tempat masak/build)
- `k8s/apps/` = Buku menu (cara sajikan/deploy)

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

## Operasi (Kubernetes)

### Melihat Logs

```bash
# Lihat logs
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

# Cek status HPA
kubectl get hpa -n cloudlab-apps
```

### Pembersihan (Cleanup)

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

> **Tip:** Dengan strategi matriks di CI/CD, menambah aplikasi baru ke pipeline sangat mudah - cukup tambah 1 entri di matriks tanpa duplikasi kode. Lihat [`ci/README.md`](ci/README.md) untuk detail.

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

## Monitoring

### Prometheus Metrics

Setiap aplikasi mengekspos metrics di endpoint `/metrics`:
- Node.js: http://localhost:3001/metrics
- Python: http://localhost:5000/metrics

### Grafana Dashboards

1. Login ke Grafana: http://localhost:3000
2. Kredensial: `admin` / `admin123`
3. Prometheus datasource sudah dikonfigurasi otomatis
4. Dashboard yang tersedia:
   - **CloudLab Overview** - Monitoring semua services (request rate, response time, error rate, CPU, memory, status)
   - **Node.js Application** - Metrics khusus Node.js (event loop lag, heap memory)
   - **Python API** - Metrics khusus Flask API (endpoint performance, resource usage)

Dashboard akan otomatis dimuat saat Grafana dimulai.

### Aturan Alert

Aturan alert didefinisikan di `monitoring/alerts.yml`:
- Deteksi layanan down
- Penggunaan CPU tinggi
- Penggunaan memori tinggi
- Monitoring tingkat error HTTP

## Keamanan

### SSL/TLS

- Self-signed certificates untuk pengembangan
- Untuk produksi, gunakan Let's Encrypt:
  ```bash
  # Install certbot
  sudo apt-get install certbot
  
  # Generate certificate
  sudo certbot certonly --standalone -d yourdomain.com
  
  # Update nginx/nginx.conf dengan path certificate baru
  ```

### Header Keamanan

Nginx sudah dikonfigurasi dengan header keamanan:
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection

## Pengujian (Testing)

### Pengujian Manual

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

### Pengujian Otomatis (CI/CD)

Pipeline CI/CD menggunakan **GitHub Actions** dengan **strategi matriks** untuk skalabilitas:

**Tahapan Pipeline:**
1. **Validate** - Validasi Docker Compose dan konfigurasi Nginx
2. **Build Apps** - Build semua aplikasi secara paralel menggunakan matriks
3. **Security Scan** - Pemindaian kerentanan dengan Trivy
4. **Integration Tests** - Tes lengkap semua layanan

**Strategi Matriks untuk Build:**
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
- **Scalable** - Mudah menambah aplikasi baru
- **Parallel** - Semua apps di-build bersamaan
- **DRY** - Tidak ada duplikasi kode
- **Maintainable** - Satu template untuk semua apps

**Menambah Aplikasi ke CI/CD:**

Cukup tambahkan entri baru di matriks di file `ci/github-actions.yml`:
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

## Deployment

### Pengembangan

```bash
docker-compose up -d
```

### Produksi

1. Update variabel lingkungan
2. Ganti sertifikat SSL dengan sertifikat produksi
3. Update password admin Grafana
4. Deploy dengan:
   ```bash
   docker-compose -f docker-compose.yml up -d
   ```

## Pemecahan Masalah (Troubleshooting)

### Port sudah digunakan

```bash
# Cek penggunaan port
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :3000
sudo lsof -i :9090

# Hentikan layanan yang konflik atau ubah port di docker-compose.yml
```

### Container tidak mulai

```bash
# Cek logs
docker-compose logs <service-name>

# Rebuild container
docker-compose up -d --build --force-recreate <service-name>
```

### Error Sertifikat SSL

```bash
# Regenerate certificates
cd nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=localhost"
```

### Prometheus tidak mengambil metrics

1. Cek target Prometheus: http://localhost:9090/targets
2. Verifikasi service mengekspos endpoint `/metrics`
3. Cek konektivitas jaringan antar container
4. Review konfigurasi `monitoring/prometheus.yml`

### Grafana tidak bisa terhubung ke Prometheus

1. Cek Prometheus berjalan: `docker-compose ps prometheus`
2. Verifikasi config datasource di `monitoring/grafana/datasources.yml`
3. Test koneksi dari Grafana UI: Configuration → Data Sources

## Pemeliharaan (Maintenance)

### Backup Data

```bash
# Backup Grafana data
docker cp cloudlab-grafana:/var/lib/grafana ./backup/grafana

# Backup Prometheus data
docker cp cloudlab-prometheus:/prometheus ./backup/prometheus
```

### Update Images

```bash
# Pull images terbaru
docker-compose pull

# Recreate containers
docker-compose up -d --force-recreate
```

### Pembersihan

```bash
# Hentikan semua layanan
docker-compose down

# Hapus volumes (PERINGATAN: akan menghapus data)
docker-compose down -v

# Hapus images yang tidak digunakan
docker image prune -a
```

## Kontribusi

1. Fork repositori
2. Buat feature branch
3. Commit perubahan
4. Push ke branch
5. Buat Pull Request

## Lisensi

MIT License

## Dukungan

Untuk masalah atau pertanyaan, silakan buat issue di repository.

---

**Dibuat untuk CloudLab**
