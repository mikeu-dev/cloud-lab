# Panduan Deployment Kubernetes

Panduan lengkap untuk deploy CloudLab ke Kubernetes cluster.

## Prasyarat

### Alat yang Dibutuhkan
- **kubectl** v1.28+ - Kubernetes CLI
- **Docker** v20.10+ - Container runtime
- **Cluster Kubernetes** - Salah satu dari:
  - Minikube (pengembangan lokal)
  - Kind (Kubernetes in Docker)
  - GKE/EKS/AKS (managed cloud)
  - kubeadm/k3s (self-managed)

### Alat Opsional
- **Helm** v3.0+ - Package manager
- **k9s** - Terminal UI untuk Kubernetes
- **kubectx/kubens** - Context dan namespace switching
- **kustomize** - Configuration management (built-in kubectl)

## Memahami Struktur Direktori

> **PENTING:** Jangan bingung antara direktori `apps/` dan `k8s/apps/` - keduanya **BERBEDA**.

```
cloud-lab/
├── apps/                    # SOURCE CODE (untuk build images)
│   └── demo-apps/
│       ├── nodejs-app/      # ← Dockerfile, package.json, server.js
│       └── python-app/      # ← Dockerfile, requirements.txt, app.py
│
└── k8s/                     # KUBERNETES CONFIGS (untuk deploy)
    └── apps/                # DEPLOYMENT MANIFESTS
        ├── nodejs-app/      # ← deployment.yaml, service.yaml, hpa.yaml
        └── python-app/      # ← deployment.yaml, service.yaml, hpa.yaml
```

**Alur Kerja:**
1. **Build** dari `apps/` → Docker image
2. **Deploy** dengan `k8s/apps/` → Running pods

**Analogi:**
- `apps/` = Resep masakan (cara buat)
- `k8s/apps/` = Menu restoran (cara sajikan)

Lihat [README utama](../README.md#struktur-direktori) untuk penjelasan lengkap.

## Panduan Memulai Cepat (Quick Start)

### 1. Setup Cluster Kubernetes

#### Opsi A: Minikube (Disarankan untuk Pengembangan)

```bash
# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Mulai cluster dengan resources yang cukup
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Verifikasi cluster
kubectl cluster-info
kubectl get nodes
```

#### Opsi B: Kind (Kubernetes in Docker)

```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Buat cluster dengan konfigurasi
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

# Install Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

#### Opsi C: Cloud Managed (GKE/EKS/AKS)

Silakan ikuti dokumentasi penyedia layanan cloud masing-masing.

### 2. Build dan Push Docker Images

```bash
# Build images
cd apps/demo-apps/nodejs-app
docker build -t cloudlab-nodejs-app:latest .

cd ../python-app
docker build -t cloudlab-python-app:latest .

# Untuk Minikube, load images langsung
minikube image load cloudlab-nodejs-app:latest
minikube image load cloudlab-python-app:latest

# Untuk cluster lain, push ke registry
# docker tag cloudlab-nodejs-app:latest your-registry/cloudlab-nodejs-app:latest
# docker push your-registry/cloudlab-nodejs-app:latest
```

### 3. Generate Sertifikat SSL

```bash
# Generate self-signed certificate untuk pengembangan
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=cloudlab.local"

# Encode ke base64
TLS_CRT=$(cat /tmp/tls.crt | base64 -w 0)
TLS_KEY=$(cat /tmp/tls.key | base64 -w 0)

# Update k8s/base/secrets/ssl-certs.yaml dengan values
sed -i "s|tls.crt:.*|tls.crt: $TLS_CRT|" k8s/base/secrets/ssl-certs.yaml
sed -i "s|tls.key:.*|tls.key: $TLS_KEY|" k8s/base/secrets/ssl-certs.yaml
```

### 4. Deploy ke Kubernetes

```bash
# Deploy semua resources dengan kustomize
kubectl apply -k k8s/

# Atau deploy secara manual per komponen
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/configmaps/
kubectl apply -f k8s/base/secrets/
kubectl apply -f k8s/apps/
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/ingress/
```

### 5. Verifikasi Deployment

```bash
# Cek namespaces
kubectl get namespaces

# Cek pods
kubectl get pods -n cloudlab-apps
kubectl get pods -n cloudlab-monitoring

# Cek services
kubectl get svc -n cloudlab-apps
kubectl get svc -n cloudlab-monitoring

# Cek ingress
kubectl get ingress -n cloudlab-apps
kubectl get ingress -n cloudlab-monitoring

# Tunggu rollout selesai
kubectl rollout status deployment/nodejs-app -n cloudlab-apps
kubectl rollout status deployment/python-app -n cloudlab-apps
kubectl rollout status deployment/grafana -n cloudlab-monitoring
kubectl rollout status statefulset/prometheus -n cloudlab-monitoring
```

### 6. Akses Aplikasi

#### Opsi A: Port Forwarding (Disarankan untuk Pengembangan)

```bash
# Node.js app
kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps

# Python app
kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps

# Grafana
kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring

# Akses:
# http://localhost:3001 - Node.js app
# http://localhost:5000 - Python app
# http://localhost:3000 - Grafana (admin/admin123)
# http://localhost:9090 - Prometheus
```

#### Opsi B: Ingress (Produksi)

```bash
# Dapatkan Ingress IP/hostname
kubectl get ingress -n cloudlab-apps

# Untuk Minikube
minikube ip  # Catat alamat IP

# Tambahkan ke /etc/hosts
echo "$(minikube ip) cloudlab.local grafana.cloudlab.local prometheus.cloudlab.local" | sudo tee -a /etc/hosts

# Akses:
# https://cloudlab.local - Main app
# https://grafana.cloudlab.local - Grafana
# https://prometheus.cloudlab.local - Prometheus
```

## Monitoring

### Prometheus

```bash
# Akses Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring

# Cek targets
curl http://localhost:9090/api/v1/targets | jq

# Query metrics
curl 'http://localhost:9090/api/v1/query?query=up'
```

### Grafana

```bash
# Akses Grafana
kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring

# Login: admin / admin123
# Datasource sudah dikonfigurasi otomatis ke Prometheus
```

## Operasi

### Penskalaan (Scaling)

```bash
# Manual scaling
kubectl scale deployment nodejs-app --replicas=5 -n cloudlab-apps

# Cek status HPA
kubectl get hpa -n cloudlab-apps

# Deskripsikan HPA
kubectl describe hpa nodejs-app-hpa -n cloudlab-apps
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/nodejs-app nodejs-app=cloudlab-nodejs-app:v2 -n cloudlab-apps

# Cek status rollout
kubectl rollout status deployment/nodejs-app -n cloudlab-apps

# Rollback jika ada masalah
kubectl rollout undo deployment/nodejs-app -n cloudlab-apps

# Cek histori rollout
kubectl rollout history deployment/nodejs-app -n cloudlab-apps
```

### Logs

```bash
# Lihat logs
kubectl logs -f deployment/nodejs-app -n cloudlab-apps
kubectl logs -f deployment/python-app -n cloudlab-apps
kubectl logs -f statefulset/prometheus -n cloudlab-monitoring

# Logs dari semua pods
kubectl logs -l app=nodejs-app -n cloudlab-apps --tail=100

# Logs dengan stern (multi-pod)
stern nodejs-app -n cloudlab-apps
```

### Debugging

```bash
# Deskripsikan pod
kubectl describe pod <pod-name> -n cloudlab-apps

# Eksekusi perintah di pod
kubectl exec -it <pod-name> -n cloudlab-apps -- /bin/sh

# Cek events
kubectl get events -n cloudlab-apps --sort-by='.lastTimestamp'

# Cek penggunaan resource
kubectl top nodes
kubectl top pods -n cloudlab-apps
```

## Pengujian (Testing)

### Pemeriksaan Kesehatan (Health Checks)

```bash
# Test health endpoints via port-forward
kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps &
curl http://localhost:3001/health

kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps &
curl http://localhost:5000/health
```

### Pengujian Beban (Load Testing)

```bash
# Generate load untuk test autoscaling
kubectl run -it --rm load-generator --image=busybox --restart=Never -- /bin/sh

# Di dalam container
while true; do wget -q -O- http://nodejs-app.cloudlab-apps.svc.cluster.local:3001; done

# Watch HPA di terminal lain
kubectl get hpa -n cloudlab-apps --watch
```

## Keamanan

### Network Policies (Opsional)

```bash
# Terapkan network policies untuk isolasi
kubectl apply -f k8s/network-policies/
```

### RBAC

```bash
# Cek service accounts
kubectl get serviceaccounts -n cloudlab-monitoring

# Cek roles
kubectl get clusterroles | grep prometheus
kubectl get clusterrolebindings | grep prometheus
```

### Manajemen Secrets

```bash
# Lihat secrets (encoded)
kubectl get secrets -n cloudlab-apps
kubectl get secrets -n cloudlab-monitoring

# Decode secret
kubectl get secret cloudlab-tls -n cloudlab-apps -o jsonpath='{.data.tls\.crt}' | base64 -d
```

## Pembersihan (Cleanup)

```bash
# Hapus semua resources
kubectl delete -k k8s/

# Atau hapus per namespace
kubectl delete namespace cloudlab-apps
kubectl delete namespace cloudlab-monitoring

# Hapus cluster (Minikube)
minikube delete

# Hapus cluster (Kind)
kind delete cluster
```

## Pemecahan Masalah (Troubleshooting)

### Pods tidak mulai

```bash
# Cek status pod
kubectl get pods -n cloudlab-apps

# Deskripsikan pod untuk melihat events
kubectl describe pod <pod-name> -n cloudlab-apps

# Cek logs
kubectl logs <pod-name> -n cloudlab-apps

# Masalah umum:
# - ImagePullBackOff: Image tidak ditemukan
# - CrashLoopBackOff: Container crash saat start
# - Pending: Tidak cukup resources
```

### Ingress tidak dapat diakses

```bash
# Cek ingress controller
kubectl get pods -n ingress-nginx

# Cek resource ingress
kubectl describe ingress cloudlab-ingress -n cloudlab-apps

# Cek endpoints service
kubectl get endpoints -n cloudlab-apps

# Untuk Minikube, pastikan tunnel berjalan
minikube tunnel
```

### Prometheus tidak mengambil metrics

```bash
# Cek targets Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring
# Buka http://localhost:9090/targets

# Cek service discovery
kubectl get servicemonitors -n cloudlab-monitoring

# Cek anotasi pod
kubectl get pod <pod-name> -n cloudlab-apps -o yaml | grep prometheus.io
```

### Masalah penyimpanan (Storage)

```bash
# Cek PVCs
kubectl get pvc -n cloudlab-monitoring

# Cek PVs
kubectl get pv

# Deskripsikan PVC untuk melihat events
kubectl describe pvc grafana-storage -n cloudlab-monitoring

# Untuk Minikube, pastikan storage provisioner aktif
minikube addons enable storage-provisioner
```

## Topik Tingkat Lanjut

### Deployment Menggunakan Helm

```bash
# Install dengan Helm (jika chart helm sudah dibuat)
helm install cloudlab ./helm/cloudlab -n cloudlab-apps --create-namespace

# Upgrade
helm upgrade cloudlab ./helm/cloudlab -n cloudlab-apps

# Rollback
helm rollback cloudlab -n cloudlab-apps
```

### GitOps dengan ArgoCD

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create Application
kubectl apply -f argocd/application.yaml
```

### Service Mesh (Istio)

```bash
# Install Istio
istioctl install --set profile=demo -y

# Enable sidecar injection
kubectl label namespace cloudlab-apps istio-injection=enabled

# Redeploy pods
kubectl rollout restart deployment -n cloudlab-apps
```

## Sumber Daya

- [Dokumentasi Kubernetes](https://kubernetes.io/docs/)
- [Cheat Sheet kubectl](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Dokumentasi Kustomize](https://kustomize.io/)
- [Dokumentasi Helm](https://helm.sh/docs/)
- [Operator Prometheus](https://prometheus-operator.dev/)

## FAQ

Punya pertanyaan? Cek [FAQ.md](FAQ.md) untuk jawaban pertanyaan umum seperti:
- Mengapa ada `apps/` dan `k8s/apps/`?
- Bagaimana cara update aplikasi?
- Troubleshooting pods yang pending
- Dan banyak lagi...

## Dukungan

Untuk masalah atau pertanyaan, silakan buat issue di repository.

---

**Selamat Melakukan Deployment Kubernetes!**
