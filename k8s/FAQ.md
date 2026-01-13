# FAQ - Pertanyaan yang Sering Diajukan

## Pertanyaan Umum

### 1. Mengapa ada folder `apps/` dan `k8s/apps/`? Apakah duplikasi?

**TIDAK!** Ini bukan duplikasi. Mereka memiliki fungsi yang berbeda:

| Folder | Fungsi | Berisi | Digunakan Untuk |
|--------|--------|--------|-----------------|
| `apps/` | Source code aplikasi | Dockerfile, source code, dependencies | Build Docker images |
| `k8s/apps/` | Konfigurasi Deployment | YAML manifests (deployment, service, hpa) | Deploy ke Kubernetes |

**Analogi:**
- `apps/` = Dapur (tempat masak/build aplikasi)
- `k8s/apps/` = Buku menu (cara sajikan/deploy aplikasi)

**Alur Kerja:**
```
apps/demo-apps/nodejs-app/
  ├── Dockerfile          ─┐
  ├── package.json         ├─→ docker build → cloudlab-nodejs-app:latest
  └── server.js           ─┘
                           
k8s/apps/nodejs-app/
  ├── deployment.yaml     ─┐
  ├── service.yaml         ├─→ kubectl apply → Running pods in cluster
  └── hpa.yaml            ─┘
```

### 2. Apakah saya perlu mengubah source code di `apps/` untuk Kubernetes?

**TIDAK!** Source code di `apps/` tetap sama untuk Docker Compose dan Kubernetes. Yang berbeda hanya cara deployment-nya:
- Docker Compose: menggunakan `docker-compose.yml`
- Kubernetes: menggunakan manifests di `k8s/`

### 3. Kenapa ada `monitoring/` dan `k8s/monitoring/`?

Sama seperti `apps/`, ini juga pemisahan tanggung jawab (separation of concerns):

| Folder | Untuk | Berisi |
|--------|-------|--------|
| `monitoring/` | Docker Compose | Prometheus/Grafana configs untuk Docker Compose |
| `k8s/monitoring/` | Kubernetes | Kubernetes manifests untuk Prometheus/Grafana |

### 4. Apakah saya bisa menggunakan Docker Compose dan Kubernetes bersamaan?

**TIDAK direkomendasikan** untuk produksi. Pilih salah satu:
- **Pengembangan**: Docker Compose (lebih sederhana)
- **Produksi**: Kubernetes (lebih kuat, dapat diskalakan)

Tapi untuk pengujian, Anda bisa menjalankan keduanya di environment berbeda.

### 5. Bagaimana cara menambah aplikasi baru?

**Untuk Docker Compose:**
1. Buat direktori di `apps/demo-apps/<app-name>/`
2. Tambahkan Dockerfile dan source code
3. Update `docker-compose.yml`
4. Update `nginx/nginx.conf` untuk routing

**Untuk Kubernetes:**
1. Buat direktori di `apps/demo-apps/<app-name>/` (sama seperti di atas)
2. Buat direktori di `k8s/apps/<app-name>/`
3. Buat `deployment.yaml`, `service.yaml`, `hpa.yaml`
4. Update `k8s/kustomization.yaml`
5. Update `k8s/ingress/ingress.yaml` untuk routing

### 6. Mengapa image tidak bisa di-pull di Kubernetes?

**Penyebab umum:**
- Image hanya ada di local Docker, belum di-load ke Minikube
- Image belum di-push ke container registry

**Solusi:**

**Untuk Minikube:**
```bash
minikube image load cloudlab-nodejs-app:latest
```

**Untuk cluster lain:**
```bash
# Push ke registry
docker tag cloudlab-nodejs-app:latest your-registry/cloudlab-nodejs-app:latest
docker push your-registry/cloudlab-nodejs-app:latest

# Update kustomization.yaml
images:
  - name: cloudlab-nodejs-app
    newName: your-registry/cloudlab-nodejs-app
    newTag: latest
```

### 7. Bagaimana cara update aplikasi yang sudah running?

**Opsi 1: Rebuild image dan redeploy**
```bash
# 1. Rebuild image
cd apps/demo-apps/nodejs-app
docker build -t cloudlab-nodejs-app:v2 .

# 2. Load ke Minikube (atau push ke registry)
minikube image load cloudlab-nodejs-app:v2

# 3. Update deployment
kubectl set image deployment/nodejs-app nodejs-app=cloudlab-nodejs-app:v2 -n cloudlab-apps

# 4. Watch rollout
kubectl rollout status deployment/nodejs-app -n cloudlab-apps
```

**Opsi 2: Update kode dan apply**
```bash
# 1. Edit source code di apps/
# 2. Rebuild dan load image
# 3. Restart deployment
kubectl rollout restart deployment/nodejs-app -n cloudlab-apps
```

### 8. Pods tertahan di status "Pending", kenapa?

**Penyebab umum:**
- Tidak cukup resources (CPU/memory) di cluster
- PersistentVolume tidak tersedia
- Node selector tidak cocok

**Debugging:**
```bash
# Cek event pod
kubectl describe pod <pod-name> -n cloudlab-apps

# Cek resource node
kubectl top nodes

# Cek status PVC
kubectl get pvc -n cloudlab-monitoring
```

**Solusi:**
- Kurangi jumlah replika (Scale down) jika resource terbatas
- Aktifkan storage provisioner untuk Minikube
- Sesuaikan permintaan/limit resource

### 9. Bagaimana cara melihat logs dari semua pods?

```bash
# Logs dari semua pods dengan label app=nodejs-app
kubectl logs -l app=nodejs-app -n cloudlab-apps --tail=100 -f

# Atau gunakan stern (perlu install)
stern nodejs-app -n cloudlab-apps
```

### 10. Apakah HPA (autoscaling) langsung bekerja?

**TIDAK otomatis.** HPA membutuhkan:
1. **Metrics Server** harus terinstal
   ```bash
   # Untuk Minikube
   minikube addons enable metrics-server
   
   # Verifikasi
   kubectl top nodes
   kubectl top pods -n cloudlab-apps
   ```

2. **Beban (Load)** yang cukup untuk memicu scaling
   ```bash
   # Generate load
   kubectl run -it --rm load-generator --image=busybox -- /bin/sh
   while true; do wget -q -O- http://nodejs-app.cloudlab-apps.svc.cluster.local:3001; done
   
   # Watch HPA
   kubectl get hpa -n cloudlab-apps --watch
   ```

### 11. Sertifikat SSL tidak bekerja, kenapa?

**Penyebab:**
- Secret `cloudlab-tls` masih menggunakan nilai placeholder

**Solusi:**
```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=cloudlab.local"

# Encode dan update
TLS_CRT=$(cat /tmp/tls.crt | base64 -w 0)
TLS_KEY=$(cat /tmp/tls.key | base64 -w 0)
sed -i "s|tls.crt:.*|tls.crt: $TLS_CRT|" k8s/base/secrets/ssl-certs.yaml
sed -i "s|tls.key:.*|tls.key: $TLS_KEY|" k8s/base/secrets/ssl-certs.yaml

# Reapply
kubectl delete secret cloudlab-tls -n cloudlab-apps
kubectl apply -f k8s/base/secrets/ssl-certs.yaml
```

**Untuk produksi:**
Install cert-manager dan gunakan Let's Encrypt:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl apply -f k8s/ingress/cert-manager.yaml
```

### 12. Bagaimana cara membersihkan (cleanup) semua resources?

**Opsi 1: Menggunakan skrip**
```bash
./k8s/scripts/cleanup.sh
```

**Opsi 2: Manual**
```bash
# Hapus via kustomization
kubectl delete -k k8s/

# Atau hapus namespaces (cascade delete semua resources)
kubectl delete namespace cloudlab-apps
kubectl delete namespace cloudlab-monitoring
```

### 13. Apakah data Prometheus/Grafana hilang saat pod restart?

**TIDAK**, karena menggunakan PersistentVolume. Data akan tetap ada selama PVC tidak dihapus.

**Backup data:**
```bash
# Backup Grafana
kubectl cp grafana-<pod-id>:/var/lib/grafana ./backup/grafana -n cloudlab-monitoring

# Backup Prometheus
kubectl cp prometheus-0:/prometheus ./backup/prometheus -n cloudlab-monitoring
```

### 14. Bagaimana cara akses Grafana/Prometheus dari luar cluster?

**Opsi 1: Port Forward (Pengembangan)**
```bash
kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring
# Akses: http://localhost:3000
```

**Opsi 2: Ingress (Produksi)**
```bash
# Sudah dikonfigurasi di k8s/ingress/ingress.yaml
# Akses: https://grafana.cloudlab.local (setelah update /etc/hosts)
```

**Opsi 3: NodePort (Pengujian)**
```bash
# Edit tipe service
kubectl patch svc grafana -n cloudlab-monitoring -p '{"spec":{"type":"NodePort"}}'

# Dapatkan NodePort
kubectl get svc grafana -n cloudlab-monitoring

# Akses via IP Minikube
minikube ip
# http://<minikube-ip>:<nodeport>
```

### 15. Dimana saya bisa belajar lebih lanjut tentang Kubernetes?

**Sumber Daya Resmi:**
- [Dokumentasi Kubernetes](https://kubernetes.io/docs/)
- [Tutorial Kubernetes](https://kubernetes.io/docs/tutorials/)
- [Cheat Sheet kubectl](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

**Pembelajaran Interaktif:**
- [Skenario Katacoda Kubernetes](https://www.katacoda.com/courses/kubernetes)
- [Play with Kubernetes](https://labs.play-with-k8s.com/)

**Buku:**
- "Kubernetes Up & Running" oleh Kelsey Hightower
- "The Kubernetes Book" oleh Nigel Poulton

**Saluran YouTube:**
- TechWorld with Nana
- Just me and Opensource
- KodeKloud

---

## Masih Ada Pertanyaan?

Jika pertanyaan Anda tidak terjawab di sini:
1. Cek [README utama](../README.md)
2. Cek [k8s/README.md](README.md)
3. Cek [MIGRATION.md](../MIGRATION.md)
4. Buat issue di repository

**Selamat Belajar!**
