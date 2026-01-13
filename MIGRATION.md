# Panduan Migrasi: Docker Compose → Kubernetes

Panduan migrasi CloudLab dari Docker Compose ke Kubernetes.

## Tinjauan Perbandingan

| Aspek | Docker Compose | Kubernetes |
|--------|---------------|------------|
| **Orkestrasi** | Single host | Multi-node cluster |
| **Penskalaan (Scaling)** | Manual (`docker-compose scale`) | Otomatis (HPA) |
| **Ketersediaan Tinggi** | Terbatas | Built-in (replika, pemulihan mandiri) |
| **Load Balancing** | Dasar | Lanjutan (Services, Ingress) |
| **Penyimpanan** | Docker volumes | PersistentVolumes |
| **Jaringan** | Bridge network | Service mesh, Network Policies |
| **Konfigurasi** | Environment variables | ConfigMaps, Secrets |
| **Deployment** | `docker-compose up` | `kubectl apply` |
| **Monitoring** | Setup manual | Integrasi native |

## Pemetaan Komponen

### Services → Deployments + Services

**Docker Compose:**
```yaml
services:
  nodejs-app:
    build: ./apps/demo-apps/nodejs-app
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
```

**Kubernetes:**
```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
spec:
  replicas: 3  # High Availability dengan multiple replicas
  template:
    spec:
      containers:
      - name: nodejs-app
        image: cloudlab-nodejs-app:latest
        env:
        - name: NODE_ENV
          value: production
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: nodejs-app
spec:
  selector:
    app: nodejs-app
  ports:
  - port: 3001
    targetPort: 3001
```

### Networks → Services & Network Policies

**Docker Compose:**
```yaml
networks:
  cloudlab-network:
    driver: bridge
```

**Kubernetes:**
- Services menyediakan penemuan layanan berbasis DNS
- Network Policies untuk kontrol lalu lintas (opsional)
- Pods dapat berkomunikasi melalui nama service

### Volumes → PersistentVolumeClaims

**Docker Compose:**
```yaml
volumes:
  prometheus-data:
    driver: local
```

**Kubernetes:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### Depends_on → Init Containers / Readiness Probes

**Docker Compose:**
```yaml
depends_on:
  - prometheus
```

**Kubernetes:**
- Readiness probes memastikan layanan siap menerima trafik
- Init containers untuk dependensi startup
- Service discovery menangani ketersediaan

## Tahapan Migrasi

### Fase 1: Persiapan

1.  **Audit Setup Saat Ini**
    ```bash
    # List running services
    docker-compose ps
    
    # Cek penggunaan resource
    docker stats
    
    # Ekspor konfigurasi
    docker-compose config > docker-compose-backup.yml
    ```

2.  **Build dan Tag Images**
    ```bash
    # Build images dengan versioning
    cd apps/demo-apps/nodejs-app
    docker build -t cloudlab-nodejs-app:1.0.0 .
    docker tag cloudlab-nodejs-app:1.0.0 cloudlab-nodejs-app:latest
    
    cd ../python-app
    docker build -t cloudlab-python-app:1.0.0 .
    docker tag cloudlab-python-app:1.0.0 cloudlab-python-app:latest
    ```

3.  **Backup Data**
    ```bash
    # Backup Grafana data
    docker cp cloudlab-grafana:/var/lib/grafana ./backup/grafana
    
    # Backup Prometheus data
    docker cp cloudlab-prometheus:/prometheus ./backup/prometheus
    ```

### Fase 2: Setup Kubernetes

1.  **Pilih Tipe Cluster**
    - Lokal: Minikube atau Kind
    - Cloud: GKE, EKS, atau AKS
    - On-premise: kubeadm atau k3s

2.  **Install Tools yang Dibutuhkan**
    ```bash
    # kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install kubectl /usr/local/bin/
    
    # Minikube (untuk lokal)
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    ```

3.  **Mulai Cluster**
    ```bash
    # Minikube
    minikube start --cpus=4 --memory=8192
    minikube addons enable ingress
    minikube addons enable metrics-server
    ```

### Fase 3: Deploy ke Kubernetes

1.  **Siapkan Images**
    ```bash
    # Untuk Minikube
    minikube image load cloudlab-nodejs-app:latest
    minikube image load cloudlab-python-app:latest
    
    # Untuk cluster lain, push ke registry
    # docker push your-registry/cloudlab-nodejs-app:latest
    ```

2.  **Generate Sertifikat SSL**
    ```bash
    # Generate self-signed cert
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /tmp/tls.key -out /tmp/tls.crt \
      -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=cloudlab.local"
    
    # Update secret
    TLS_CRT=$(cat /tmp/tls.crt | base64 -w 0)
    TLS_KEY=$(cat /tmp/tls.key | base64 -w 0)
    sed -i "s|tls.crt:.*|tls.crt: $TLS_CRT|" k8s/base/secrets/ssl-certs.yaml
    sed -i "s|tls.key:.*|tls.key: $TLS_KEY|" k8s/base/secrets/ssl-certs.yaml
    ```

3.  **Deploy Resources**
    ```bash
    # Deploy dengan kustomize
    kubectl apply -k k8s/
    
    # Tunggu rollout selesai
    kubectl rollout status deployment/nodejs-app -n cloudlab-apps
    kubectl rollout status deployment/python-app -n cloudlab-apps
    kubectl rollout status deployment/grafana -n cloudlab-monitoring
    kubectl rollout status statefulset/prometheus -n cloudlab-monitoring
    ```

4.  **Verifikasi Deployment**
    ```bash
    # Cek pods
    kubectl get pods -n cloudlab-apps
    kubectl get pods -n cloudlab-monitoring
    
    # Cek services
    kubectl get svc -n cloudlab-apps
    kubectl get svc -n cloudlab-monitoring
    
    # Cek ingress
    kubectl get ingress -A
    ```

### Fase 4: Migrasi Data

1.  **Restore Data Grafana**
    ```bash
    # Copy backup ke pod
    kubectl cp ./backup/grafana grafana-<pod-id>:/var/lib/grafana -n cloudlab-monitoring
    
    # Restart Grafana
    kubectl rollout restart deployment/grafana -n cloudlab-monitoring
    ```

2.  **Restore Data Prometheus**
    ```bash
    # Copy backup ke pod
    kubectl cp ./backup/prometheus prometheus-0:/prometheus -n cloudlab-monitoring
    
    # Restart Prometheus
    kubectl rollout restart statefulset/prometheus -n cloudlab-monitoring
    ```

### Fase 5: Pengujian (Testing)

1.  **Pengujian Fungsional**
    ```bash
    # Port forward untuk testing
    kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps &
    kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps &
    kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring &
    
    # Test endpoints
    curl http://localhost:3001/health
    curl http://localhost:5000/health
    curl http://localhost:3000/api/health
    ```

2.  **Pengujian Beban (Load Testing)**
    ```bash
    # Generate load
    kubectl run -it --rm load-generator --image=busybox -- /bin/sh
    while true; do wget -q -O- http://nodejs-app.cloudlab-apps.svc.cluster.local:3001; done
    
    # Watch autoscaling
    kubectl get hpa -n cloudlab-apps --watch
    ```

3.  **Pengujian Monitoring**
    ```bash
    # Cek target Prometheus
    kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring
    # Buka http://localhost:9090/targets
    
    # Cek dashboard Grafana
    # Buka http://localhost:3000
    ```

### Fase 6: Cutover

1.  **Update DNS/Hosts**
    ```bash
    # Dapatkan IP Ingress
    kubectl get ingress -n cloudlab-apps
    
    # Update /etc/hosts
    echo "$(minikube ip) cloudlab.local grafana.cloudlab.local" | sudo tee -a /etc/hosts
    ```

2.  **Hentikan Docker Compose**
    ```bash
    # Hentikan services
    docker-compose down
    
    # Simpan volumes untuk backup
    # docker-compose down -v  # Hanya jika ingin menghapus volumes
    ```

3.  **Verifikasi Trafik Produksi**
    ```bash
    # Test via Ingress
    curl https://cloudlab.local
    curl https://grafana.cloudlab.local
    ```

## Prosedur Rollback

Jika terjadi masalah, rollback kembali ke Docker Compose:

```bash
# 1. Hapus deployment Kubernetes
kubectl delete -k k8s/

# 2. Jalankan Docker Compose
docker-compose up -d

# 3. Verifikasi services
docker-compose ps
```

## Masalah Umum (Common Issues)

### Masalah 1: ImagePullBackOff

**Masalah:** Kubernetes tidak bisa mengambil image.

**Solusi:**
```bash
# Untuk Minikube, load image langsung
minikube image load cloudlab-nodejs-app:latest

# Untuk cluster lain, push ke registry
docker tag cloudlab-nodejs-app:latest your-registry/cloudlab-nodejs-app:latest
docker push your-registry/cloudlab-nodejs-app:latest

# Update kustomization.yaml dengan registry URL
```

### Masalah 2: Pods Pending

**Masalah:** Pods tertahan di status Pending.

**Solusi:**
```bash
# Cek resource node
kubectl top nodes

# Cek event pod
kubectl describe pod <pod-name> -n cloudlab-apps

# Scale down jika resource tidak cukup
kubectl scale deployment nodejs-app --replicas=1 -n cloudlab-apps
```

### Masalah 3: Ingress Not Working

**Masalah:** Tidak bisa akses via Ingress.

**Solusi:**
```bash
# Cek Ingress controller
kubectl get pods -n ingress-nginx

# Untuk Minikube, enable ingress addon
minikube addons enable ingress

# Untuk Minikube, jalankan tunnel
minikube tunnel
```

### Masalah 4: PVC Pending

**Masalah:** PersistentVolumeClaim tertahan di status Pending.

**Solusi:**
```bash
# Cek storage class
kubectl get storageclass

# Untuk Minikube, enable storage provisioner
minikube addons enable storage-provisioner

# Cek event PVC
kubectl describe pvc grafana-storage -n cloudlab-monitoring
```

## Perbandingan Performa

### Penggunaan Sumber Daya

| Metrik | Docker Compose | Kubernetes (3 replika) |
|--------|---------------|------------------------|
| **Memori** | ~2GB | ~4GB |
| **CPU** | ~1 core | ~2 cores |
| **Waktu Startup** | ~30s | ~60s |
| **Skalabilitas** | Manual | Otomatis (HPA) |

### Manfaat

-   **High Availability**: Multiple replicas dengan pemulihan mandiri
-   **Auto-scaling**: HPA berdasarkan CPU/memory
-   **Rolling Updates**: Deployment tanpa downtime
-   **Monitoring Lebih Baik**: Integrasi native Prometheus
-   **Portabilitas Cloud**: Deploy di mana saja
-   **Kesiapan Produksi**: Orkestrasi kelas enterprise

## Langkah Selanjutnya

1.  **Setup CI/CD**: Update GitHub Actions untuk deployment Kubernetes
2.  **Implementasi GitOps**: ArgoCD atau FluxCD untuk sinkronisasi otomatis
3.  **Tambah Monitoring**: Prometheus Operator, dashboard Grafana
4.  **Penguatan Keamanan**: Network Policies, RBAC, Pod Security
5.  **Strategi Backup**: Velero untuk backup cluster
6.  **Service Mesh**: Istio atau Linkerd untuk manajemen trafik tingkat lanjut

## Referensi

-   [Dokumentasi Kubernetes](https://kubernetes.io/docs/)
-   [Docker Compose ke Kubernetes](https://kubernetes.io/docs/tasks/configure-pod-container/translate-compose-kubernetes/)
-   [Kompose Tool](https://kompose.io/) - Konversi otomatis Compose ke K8s
-   [Kustomize](https://kustomize.io/)

---

**Migrasi Selesai! Selamat Datang di Kubernetes!**
