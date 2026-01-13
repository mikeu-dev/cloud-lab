# FAQ - Frequently Asked Questions

## ❓ Pertanyaan Umum

### 1. Mengapa ada folder `apps/` dan `k8s/apps/`? Apakah duplikasi?

**TIDAK!** Ini bukan duplikasi. Mereka memiliki fungsi yang berbeda:

| Folder | Fungsi | Berisi | Digunakan Untuk |
|--------|--------|--------|-----------------|
| `apps/` | Source code aplikasi | Dockerfile, source code, dependencies | Build Docker images |
| `k8s/apps/` | Deployment configuration | YAML manifests (deployment, service, hpa) | Deploy ke Kubernetes |

**Analogi:**
- `apps/` = Dapur (tempat masak/build aplikasi)
- `k8s/apps/` = Buku menu (cara sajikan/deploy aplikasi)

**Workflow:**
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

Sama seperti `apps/`, ini juga separation of concerns:

| Folder | Untuk | Berisi |
|--------|-------|--------|
| `monitoring/` | Docker Compose | Prometheus/Grafana configs untuk Docker Compose |
| `k8s/monitoring/` | Kubernetes | Kubernetes manifests untuk Prometheus/Grafana |

### 4. Apakah saya bisa menggunakan Docker Compose dan Kubernetes bersamaan?

**TIDAK direkomendasikan** untuk production. Pilih salah satu:
- **Development**: Docker Compose (lebih simple)
- **Production**: Kubernetes (lebih robust, scalable)

Tapi untuk testing, Anda bisa run keduanya di environment berbeda.

### 5. Bagaimana cara menambah aplikasi baru?

**Untuk Docker Compose:**
1. Buat folder di `apps/demo-apps/<app-name>/`
2. Tambahkan Dockerfile dan source code
3. Update `docker-compose.yml`
4. Update `nginx/nginx.conf` untuk routing

**Untuk Kubernetes:**
1. Buat folder di `apps/demo-apps/<app-name>/` (sama seperti di atas)
2. Buat folder di `k8s/apps/<app-name>/`
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

**Option 1: Rebuild image dan redeploy**
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

**Option 2: Update code dan apply**
```bash
# 1. Edit source code di apps/
# 2. Rebuild dan load image
# 3. Restart deployment
kubectl rollout restart deployment/nodejs-app -n cloudlab-apps
```

### 8. Pods stuck di "Pending" status, kenapa?

**Penyebab umum:**
- Tidak cukup resources (CPU/memory) di cluster
- PersistentVolume tidak tersedia
- Node selector tidak match

**Debugging:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n cloudlab-apps

# Check node resources
kubectl top nodes

# Check PVC status
kubectl get pvc -n cloudlab-monitoring
```

**Solusi:**
- Scale down replicas jika resource terbatas
- Enable storage provisioner untuk Minikube
- Adjust resource requests/limits

### 9. Bagaimana cara melihat logs dari semua pods?

```bash
# Logs dari semua pods dengan label app=nodejs-app
kubectl logs -l app=nodejs-app -n cloudlab-apps --tail=100 -f

# Atau gunakan stern (perlu install)
stern nodejs-app -n cloudlab-apps
```

### 10. Apakah HPA (autoscaling) langsung bekerja?

**TIDAK otomatis.** HPA membutuhkan:
1. **Metrics Server** harus installed
   ```bash
   # Untuk Minikube
   minikube addons enable metrics-server
   
   # Verify
   kubectl top nodes
   kubectl top pods -n cloudlab-apps
   ```

2. **Load** yang cukup untuk trigger scaling
   ```bash
   # Generate load
   kubectl run -it --rm load-generator --image=busybox -- /bin/sh
   while true; do wget -q -O- http://nodejs-app.cloudlab-apps.svc.cluster.local:3001; done
   
   # Watch HPA
   kubectl get hpa -n cloudlab-apps --watch
   ```

### 11. SSL certificates tidak bekerja, kenapa?

**Penyebab:**
- Secret `cloudlab-tls` masih menggunakan placeholder values

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

**Untuk production:**
Install cert-manager dan gunakan Let's Encrypt:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl apply -f k8s/ingress/cert-manager.yaml
```

### 12. Bagaimana cara cleanup semua resources?

**Option 1: Menggunakan script**
```bash
./k8s/scripts/cleanup.sh
```

**Option 2: Manual**
```bash
# Delete via kustomization
kubectl delete -k k8s/

# Atau delete namespaces (cascade delete semua resources)
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

### 14. Bagaimana cara access Grafana/Prometheus dari luar cluster?

**Option 1: Port Forward (Development)**
```bash
kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring
# Access: http://localhost:3000
```

**Option 2: Ingress (Production)**
```bash
# Sudah configured di k8s/ingress/ingress.yaml
# Access: https://grafana.cloudlab.local (setelah update /etc/hosts)
```

**Option 3: NodePort (Testing)**
```bash
# Edit service type
kubectl patch svc grafana -n cloudlab-monitoring -p '{"spec":{"type":"NodePort"}}'

# Get NodePort
kubectl get svc grafana -n cloudlab-monitoring

# Access via Minikube IP
minikube ip
# http://<minikube-ip>:<nodeport>
```

### 15. Dimana saya bisa belajar lebih lanjut tentang Kubernetes?

**Official Resources:**
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Tutorials](https://kubernetes.io/docs/tutorials/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

**Interactive Learning:**
- [Katacoda Kubernetes Scenarios](https://www.katacoda.com/courses/kubernetes)
- [Play with Kubernetes](https://labs.play-with-k8s.com/)

**Books:**
- "Kubernetes Up & Running" by Kelsey Hightower
- "The Kubernetes Book" by Nigel Poulton

**YouTube Channels:**
- TechWorld with Nana
- Just me and Opensource
- KodeKloud

---

## 🆘 Masih Ada Pertanyaan?

Jika pertanyaan Anda tidak terjawab di sini:
1. Check [main README](../README.md)
2. Check [k8s/README.md](README.md)
3. Check [MIGRATION.md](../MIGRATION.md)
4. Buat issue di repository

**Happy Learning! 🚀**
