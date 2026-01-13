# Dashboard Grafana - CloudLab

## Dashboard Tersedia

### 1. CloudLab Overview
**UID**: `cloudlab-overview`

Dashboard utama untuk memantau semua layanan dalam lingkungan CloudLab.

**Panel**:
- HTTP Request Rate - Permintaan per detik untuk semua layanan
- HTTP Response Time - Persentil p50 dan p95
- Error Rate (5xx) - Gauge untuk memantau tingkat kesalahan
- CPU Usage - Penggunaan CPU per layanan
- Memory Usage - Konsumsi memori per layanan
- Service Status - Status Up/Down untuk semua layanan

**Refresh**: 5 detik
**Rentang Waktu**: 15 menit terakhir

---

### 2. Node.js Application
**UID**: `cloudlab-nodejs`

Dashboard khusus untuk memantau aplikasi Node.js Express.

**Panel**:
- Request Rate by Endpoint - Rincian tingkat permintaan per endpoint
- Response Time Percentiles - p50 dan p95 per rute
- Event Loop Lag - Performa event loop Node.js
- Heap Memory Usage - Heap digunakan vs heap total

**Refresh**: 5 detik
**Rentang Waktu**: 15 menit terakhir

**Metrics**:
- `http_requests_total` - Total permintaan HTTP
- `http_request_duration_seconds` - Histogram durasi permintaan
- `nodejs_eventloop_lag_seconds` - Lag event loop
- `nodejs_heap_size_used_bytes` - Memori heap yang digunakan
- `nodejs_heap_size_total_bytes` - Total ukuran heap

---

### 3. Python API
**UID**: `cloudlab-python`

Dashboard khusus untuk memantau Python Flask API.

**Panel**:
- API Request Rate - Permintaan per detik per endpoint
- API Response Time - Persentil p50 dan p95
- CPU Usage - Penggunaan CPU proses
- Memory Usage - Konsumsi memori proses
- Error Rate - Gauge tingkat kesalahan

**Refresh**: 5 detik
**Rentang Waktu**: 15 menit terakhir

**Metrics**:
- `http_requests_total` - Total permintaan HTTP
- `http_request_duration_seconds` - Histogram durasi permintaan
- `process_cpu_seconds_total` - Waktu CPU
- `process_resident_memory_bytes` - Penggunaan memori

---

## Mengakses Dashboard

1. Mulai layanan CloudLab:
   ```bash
   docker-compose up -d
   ```

2. Buka Grafana:
   ```
   http://localhost:3000
   ```

3. Login dengan kredensial:
   - Username: `admin`
   - Password: `admin123`

4. Dashboard akan otomatis tersedia di:
   - Home → Dashboards → CloudLab Overview
   - Home → Dashboards → CloudLab - Node.js Application
   - Home → Dashboards → CloudLab - Python API

## Kustomisasi

Untuk menambah atau memodifikasi dashboard:

1. Edit file JSON di `monitoring/grafana/dashboards/`
2. Atau buat dashboard baru via Grafana UI
3. Ekspor dashboard sebagai JSON
4. Simpan ke `monitoring/grafana/dashboards/`
5. Restart Grafana: `docker-compose restart grafana`

## Pemecahan Masalah (Troubleshooting)

### Dashboard tidak muncul
- Cek logs Grafana: `docker-compose logs grafana`
- Verifikasi konfigurasi provisioning: `monitoring/grafana/dashboards.yml`
- Pastikan file JSON valid

### Tidak ada data di panel
- Cek target Prometheus: http://localhost:9090/targets
- Verifikasi aplikasi mengekspos endpoint `/metrics`
- Cek koneksi datasource Prometheus di Grafana

### Metrics tidak sesuai
- Verifikasi nama metric di Prometheus: http://localhost:9090/graph
- Cek query PromQL di panel dashboard
- Pastikan label selector cocok dengan layanan Anda
