# Dokumentasi Pipeline CI/CD

## Ikhtisar

Pipeline CI/CD CloudLab menggunakan GitHub Actions untuk otomasi build, test, dan deployment aplikasi.

## Struktur Pipeline

### 1. Validate (Validasi)
Memvalidasi konfigurasi sebelum build:
- Konfigurasi Docker Compose
- Konfigurasi Nginx

### 2. Build Apps (Strategi Matriks)
Build semua aplikasi menggunakan **strategi matriks** untuk skalabilitas:

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

**Keuntungan Strategi Matriks:**
- **Scalable**: Mudah menambah aplikasi baru
- **DRY (Don't Repeat Yourself)**: Tidak ada duplikasi kode
- **Parallel**: Semua aplikasi di-build secara paralel
- **Maintainable**: Satu template untuk semua aplikasi

### 3. Security Scan (Pemindaian Keamanan)
Scan kerentanan menggunakan Trivy untuk semua aplikasi.

### 4. Integration Test (Uji Integrasi)
Uji integrasi lengkap meliputi:
- Nginx reverse proxy
- Aplikasi Node.js melalui Nginx
- Python API melalui Nginx
- Metrics Prometheus
- Grafana dashboard
- Target Prometheus

### 5. Deploy (Opsional)
Deployment ke produksi (saat ini dinonaktifkan, aktifkan saat siap deploy).

## Menambah Aplikasi Baru

Untuk menambah aplikasi baru, cukup tambahkan entri di matriks `build-apps`:

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
- Duplikasi job baru
- Copy-paste langkah-langkah
- Update di banyak tempat

**Cukup:**
- Tambah 1 entri di matriks
- Semua langkah otomatis diterapkan

## Workflow Triggers

Pipeline berjalan otomatis pada:
- Push ke branch `main` atau `develop`
- Pull request ke branch `main`

## Variabel Lingkungan (Environment Variables)

```yaml
env:
  REGISTRY: ghcr.io
  NODE_APP_IMAGE: cloudlab-nodejs-app
  PYTHON_APP_IMAGE: cloudlab-python-app
```

## Strategi Cache

Setiap aplikasi memiliki cakupan cache terpisah untuk optimasi waktu build:

```yaml
cache-from: type=gha,scope=${{ matrix.app.name }}
cache-to: type=gha,mode=max,scope=${{ matrix.app.name }}
```

## Strategi Pengujian

Setiap aplikasi diuji dengan:
1. Endpoint pemeriksaan kesehatan (Health check)
2. Endpoint metrics
3. Uji integrasi melalui Nginx

## Praktik Terbaik (Best Practices)

1. **Fail-fast: false** - Lanjutkan build aplikasi lain meskipun satu gagal
2. **Scoped cache** - Cache terpisah per aplikasi untuk efisiensi
3. **Penamaan Dinamis** - Gunakan `${{ matrix.app.name }}` untuk penamaan
4. **Struktur Konsisten** - Semua aplikasi harus memiliki endpoint health & metrics

## Pemecahan Masalah (Troubleshooting)

### Build gagal untuk satu app
Karena `fail-fast: false`, aplikasi lain tetap di-build. Periksa logs untuk aplikasi yang gagal.

### Masalah Cache
Hapus cache dengan menjalankan ulang workflow atau membersihkan cache GitHub Actions.

### Timeout pada Uji Integrasi
Sesuaikan `sleep_time` di konfigurasi matriks jika aplikasi membutuhkan waktu startup lebih lama.
