# Grafana Dashboards - CloudLab

## Available Dashboards

### 1. CloudLab Overview
**UID**: `cloudlab-overview`

Dashboard utama untuk monitoring semua services dalam CloudLab environment.

**Panels**:
- HTTP Request Rate - Request per second untuk semua services
- HTTP Response Time - p50 dan p95 percentiles
- Error Rate (5xx) - Gauge untuk monitoring error rate
- CPU Usage - CPU usage per service
- Memory Usage - Memory consumption per service
- Service Status - Up/Down status untuk semua services

**Refresh**: 5 seconds
**Time Range**: Last 15 minutes

---

### 2. Node.js Application
**UID**: `cloudlab-nodejs`

Dashboard khusus untuk monitoring Node.js Express application.

**Panels**:
- Request Rate by Endpoint - Breakdown request rate per endpoint
- Response Time Percentiles - p50 dan p95 per route
- Event Loop Lag - Node.js event loop performance
- Heap Memory Usage - Heap used vs heap total

**Refresh**: 5 seconds
**Time Range**: Last 15 minutes

**Metrics**:
- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request duration histogram
- `nodejs_eventloop_lag_seconds` - Event loop lag
- `nodejs_heap_size_used_bytes` - Heap memory used
- `nodejs_heap_size_total_bytes` - Total heap size

---

### 3. Python API
**UID**: `cloudlab-python`

Dashboard khusus untuk monitoring Python Flask API.

**Panels**:
- API Request Rate - Request per second per endpoint
- API Response Time - p50 dan p95 percentiles
- CPU Usage - Process CPU usage
- Memory Usage - Process memory consumption
- Error Rate - Error rate gauge

**Refresh**: 5 seconds
**Time Range**: Last 15 minutes

**Metrics**:
- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request duration histogram
- `process_cpu_seconds_total` - CPU time
- `process_resident_memory_bytes` - Memory usage

---

## Accessing Dashboards

1. Start CloudLab services:
   ```bash
   docker-compose up -d
   ```

2. Open Grafana:
   ```
   http://localhost:3000
   ```

3. Login dengan credentials:
   - Username: `admin`
   - Password: `admin123`

4. Dashboards akan otomatis tersedia di:
   - Home → Dashboards → CloudLab Overview
   - Home → Dashboards → CloudLab - Node.js Application
   - Home → Dashboards → CloudLab - Python API

## Customization

Untuk menambah atau memodifikasi dashboards:

1. Edit JSON files di `monitoring/grafana/dashboards/`
2. Atau buat dashboard baru via Grafana UI
3. Export dashboard sebagai JSON
4. Save ke `monitoring/grafana/dashboards/`
5. Restart Grafana: `docker-compose restart grafana`

## Troubleshooting

### Dashboard tidak muncul
- Check Grafana logs: `docker-compose logs grafana`
- Verify provisioning config: `monitoring/grafana/dashboards.yml`
- Ensure JSON files valid

### No data in panels
- Check Prometheus targets: http://localhost:9090/targets
- Verify applications expose `/metrics` endpoint
- Check Prometheus datasource connection in Grafana

### Metrics tidak sesuai
- Verify metric names di Prometheus: http://localhost:9090/graph
- Check PromQL queries di dashboard panels
- Ensure label selectors match your services
