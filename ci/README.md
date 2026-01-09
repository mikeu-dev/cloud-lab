# CI/CD Pipeline Documentation

## Overview

Pipeline CI/CD CloudLab menggunakan GitHub Actions untuk otomasi build, test, dan deployment aplikasi.

## Struktur Pipeline

### 1. Validate
Memvalidasi konfigurasi sebelum build:
- Docker Compose configuration
- Nginx configuration

### 2. Build Apps (Matrix Strategy)
Build semua aplikasi menggunakan **matrix strategy** untuk scalability:

```yaml
strategy:
  matrix:
    app:
      - name: nodejs-app
        image: cloudlab-nodejs-app
        context: ./apps/demo-apps/nodejs-app
        port: 3001
        health_endpoint: /health
        metrics_endpoint: /metrics
        sleep_time: 5
      - name: python-app
        image: cloudlab-python-app
        context: ./apps/demo-apps/python-app
        port: 5000
        health_endpoint: /api/health
        metrics_endpoint: /metrics
        sleep_time: 10
  fail-fast: false
```

**Keuntungan Matrix Strategy:**
- ✅ **Scalable**: Mudah menambah aplikasi baru
- ✅ **DRY**: Tidak ada duplikasi kode
- ✅ **Parallel**: Semua apps di-build secara parallel
- ✅ **Maintainable**: Satu template untuk semua apps

### 3. Security Scan
Scan vulnerabilities menggunakan Trivy untuk semua aplikasi.

### 4. Integration Test
Test integrasi lengkap:
- Nginx reverse proxy
- Node.js app melalui Nginx
- Python API melalui Nginx
- Prometheus metrics
- Grafana dashboard
- Prometheus targets

### 5. Deploy (Optional)
Deployment ke production (saat ini di-comment, uncomment saat siap deploy).

## Menambah Aplikasi Baru

Untuk menambah aplikasi baru, cukup tambahkan entry di matrix `build-apps`:

```yaml
build-apps:
  strategy:
    matrix:
      app:
        - name: nodejs-app
          # ... existing config ...
        - name: python-app
          # ... existing config ...
        # Tambahkan aplikasi baru di sini:
        - name: golang-app
          image: cloudlab-golang-app
          context: ./apps/demo-apps/golang-app
          port: 8080
          health_endpoint: /health
          metrics_endpoint: /metrics
          sleep_time: 5
```

**Tidak perlu:**
- ❌ Duplikasi job baru
- ❌ Copy-paste steps
- ❌ Update multiple places

**Cukup:**
- ✅ Tambah 1 entry di matrix
- ✅ Semua steps otomatis apply

## Workflow Triggers

Pipeline berjalan otomatis pada:
- Push ke branch `main` atau `develop`
- Pull request ke branch `main`

## Environment Variables

```yaml
env:
  REGISTRY: ghcr.io
  NODE_APP_IMAGE: cloudlab-nodejs-app
  PYTHON_APP_IMAGE: cloudlab-python-app
```

## Cache Strategy

Setiap aplikasi memiliki cache scope terpisah untuk optimasi build time:

```yaml
cache-from: type=gha,scope=${{ matrix.app.name }}
cache-to: type=gha,mode=max,scope=${{ matrix.app.name }}
```

## Testing Strategy

Setiap aplikasi di-test dengan:
1. Health check endpoint
2. Metrics endpoint
3. Integration test melalui Nginx

## Best Practices

1. **Fail-fast: false** - Lanjutkan build apps lain meskipun satu gagal
2. **Scoped cache** - Cache terpisah per aplikasi untuk efisiensi
3. **Dynamic naming** - Gunakan `${{ matrix.app.name }}` untuk naming
4. **Consistent structure** - Semua apps harus punya health & metrics endpoint

## Troubleshooting

### Build gagal untuk satu app
Karena `fail-fast: false`, apps lain tetap di-build. Check logs untuk app yang gagal.

### Cache issues
Hapus cache dengan re-run workflow atau clear GitHub Actions cache.

### Integration test timeout
Sesuaikan `sleep_time` di matrix config jika aplikasi butuh waktu startup lebih lama.
