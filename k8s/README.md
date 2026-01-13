# Kubernetes Deployment Guide

Panduan lengkap untuk deploy CloudLab ke Kubernetes cluster.

## 📋 Prerequisites

### Required Tools
- **kubectl** v1.28+ - Kubernetes CLI
- **Docker** v20.10+ - Container runtime
- **Kubernetes cluster** - Salah satu dari:
  - Minikube (local development)
  - Kind (Kubernetes in Docker)
  - GKE/EKS/AKS (cloud managed)
  - kubeadm/k3s (self-managed)

### Optional Tools
- **Helm** v3.0+ - Package manager
- **k9s** - Terminal UI untuk Kubernetes
- **kubectx/kubens** - Context dan namespace switching
- **kustomize** - Configuration management (built-in kubectl)

## 📁 Understanding Directory Structure

> **⚠️ PENTING:** Jangan bingung antara `apps/` dan `k8s/apps/` - mereka **BERBEDA**!

```
cloud-lab/
├── apps/                    # 📦 SOURCE CODE (untuk build images)
│   └── demo-apps/
│       ├── nodejs-app/      # ← Dockerfile, package.json, server.js
│       └── python-app/      # ← Dockerfile, requirements.txt, app.py
│
└── k8s/                     # ☸️ KUBERNETES CONFIGS (untuk deploy)
    └── apps/                # 🚀 DEPLOYMENT MANIFESTS
        ├── nodejs-app/      # ← deployment.yaml, service.yaml, hpa.yaml
        └── python-app/      # ← deployment.yaml, service.yaml, hpa.yaml
```

**Workflow:**
1. **Build** dari `apps/` → Docker image
2. **Deploy** dengan `k8s/apps/` → Running pods

**Analogi:**
- `apps/` = Resep masakan (cara buat)
- `k8s/apps/` = Menu restoran (cara sajikan)

Lihat [main README](../README.md#struktur-direktori) untuk penjelasan lengkap.

## 🚀 Quick Start

### 1. Setup Kubernetes Cluster

#### Option A: Minikube (Recommended untuk Development)

```bash
# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster dengan resources yang cukup
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

#### Option B: Kind (Kubernetes in Docker)

```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster dengan config
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

#### Option C: Cloud Managed (GKE/EKS/AKS)

Ikuti dokumentasi cloud provider masing-masing.

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

### 3. Generate SSL Certificates

```bash
# Generate self-signed certificate untuk development
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

# Atau deploy secara manual per component
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/configmaps/
kubectl apply -f k8s/base/secrets/
kubectl apply -f k8s/apps/
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/ingress/
```

### 5. Verify Deployment

```bash
# Check namespaces
kubectl get namespaces

# Check pods
kubectl get pods -n cloudlab-apps
kubectl get pods -n cloudlab-monitoring

# Check services
kubectl get svc -n cloudlab-apps
kubectl get svc -n cloudlab-monitoring

# Check ingress
kubectl get ingress -n cloudlab-apps
kubectl get ingress -n cloudlab-monitoring

# Wait for rollout
kubectl rollout status deployment/nodejs-app -n cloudlab-apps
kubectl rollout status deployment/python-app -n cloudlab-apps
kubectl rollout status deployment/grafana -n cloudlab-monitoring
kubectl rollout status statefulset/prometheus -n cloudlab-monitoring
```

### 6. Access Applications

#### Option A: Port Forwarding (Recommended untuk Development)

```bash
# Node.js app
kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps

# Python app
kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps

# Grafana
kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring

# Access:
# http://localhost:3001 - Node.js app
# http://localhost:5000 - Python app
# http://localhost:3000 - Grafana (admin/admin123)
# http://localhost:9090 - Prometheus
```

#### Option B: Ingress (Production)

```bash
# Get Ingress IP/hostname
kubectl get ingress -n cloudlab-apps

# Untuk Minikube
minikube ip  # Catat IP address

# Add ke /etc/hosts
echo "$(minikube ip) cloudlab.local grafana.cloudlab.local prometheus.cloudlab.local" | sudo tee -a /etc/hosts

# Access:
# https://cloudlab.local - Main app
# https://grafana.cloudlab.local - Grafana
# https://prometheus.cloudlab.local - Prometheus
```

## 📊 Monitoring

### Prometheus

```bash
# Access Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring

# Check targets
curl http://localhost:9090/api/v1/targets | jq

# Query metrics
curl 'http://localhost:9090/api/v1/query?query=up'
```

### Grafana

```bash
# Access Grafana
kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring

# Login: admin / admin123
# Datasource sudah auto-configured ke Prometheus
```

## 🔧 Operations

### Scaling

```bash
# Manual scaling
kubectl scale deployment nodejs-app --replicas=5 -n cloudlab-apps

# Check HPA status
kubectl get hpa -n cloudlab-apps

# Describe HPA
kubectl describe hpa nodejs-app-hpa -n cloudlab-apps
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/nodejs-app nodejs-app=cloudlab-nodejs-app:v2 -n cloudlab-apps

# Check rollout status
kubectl rollout status deployment/nodejs-app -n cloudlab-apps

# Rollback jika ada masalah
kubectl rollout undo deployment/nodejs-app -n cloudlab-apps

# Check rollout history
kubectl rollout history deployment/nodejs-app -n cloudlab-apps
```

### Logs

```bash
# View logs
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
# Describe pod
kubectl describe pod <pod-name> -n cloudlab-apps

# Execute command di pod
kubectl exec -it <pod-name> -n cloudlab-apps -- /bin/sh

# Check events
kubectl get events -n cloudlab-apps --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -n cloudlab-apps
```

## 🧪 Testing

### Health Checks

```bash
# Test health endpoints via port-forward
kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps &
curl http://localhost:3001/health

kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps &
curl http://localhost:5000/health
```

### Load Testing

```bash
# Generate load untuk test autoscaling
kubectl run -it --rm load-generator --image=busybox --restart=Never -- /bin/sh

# Di dalam container
while true; do wget -q -O- http://nodejs-app.cloudlab-apps.svc.cluster.local:3001; done

# Watch HPA di terminal lain
kubectl get hpa -n cloudlab-apps --watch
```

## 🔒 Security

### Network Policies (Optional)

```bash
# Apply network policies untuk isolasi
kubectl apply -f k8s/network-policies/
```

### RBAC

```bash
# Check service accounts
kubectl get serviceaccounts -n cloudlab-monitoring

# Check roles
kubectl get clusterroles | grep prometheus
kubectl get clusterrolebindings | grep prometheus
```

### Secrets Management

```bash
# View secrets (encoded)
kubectl get secrets -n cloudlab-apps
kubectl get secrets -n cloudlab-monitoring

# Decode secret
kubectl get secret cloudlab-tls -n cloudlab-apps -o jsonpath='{.data.tls\.crt}' | base64 -d
```

## 🧹 Cleanup

```bash
# Delete semua resources
kubectl delete -k k8s/

# Atau delete per namespace
kubectl delete namespace cloudlab-apps
kubectl delete namespace cloudlab-monitoring

# Delete cluster (Minikube)
minikube delete

# Delete cluster (Kind)
kind delete cluster
```

## 🛠️ Troubleshooting

### Pods tidak start

```bash
# Check pod status
kubectl get pods -n cloudlab-apps

# Describe pod untuk lihat events
kubectl describe pod <pod-name> -n cloudlab-apps

# Check logs
kubectl logs <pod-name> -n cloudlab-apps

# Common issues:
# - ImagePullBackOff: Image tidak ditemukan
# - CrashLoopBackOff: Container crash saat start
# - Pending: Tidak cukup resources
```

### Ingress tidak accessible

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress cloudlab-ingress -n cloudlab-apps

# Check service endpoints
kubectl get endpoints -n cloudlab-apps

# Untuk Minikube, pastikan tunnel running
minikube tunnel
```

### Prometheus tidak scrape metrics

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring
# Buka http://localhost:9090/targets

# Check service discovery
kubectl get servicemonitors -n cloudlab-monitoring

# Check pod annotations
kubectl get pod <pod-name> -n cloudlab-apps -o yaml | grep prometheus.io
```

### Storage issues

```bash
# Check PVCs
kubectl get pvc -n cloudlab-monitoring

# Check PVs
kubectl get pv

# Describe PVC untuk lihat events
kubectl describe pvc grafana-storage -n cloudlab-monitoring

# Untuk Minikube, pastikan storage provisioner enabled
minikube addons enable storage-provisioner
```

## 📚 Advanced Topics

### Helm Deployment

```bash
# Install dengan Helm (jika helm charts sudah dibuat)
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

## 🔗 Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)

## ❓ FAQ

Punya pertanyaan? Check [FAQ.md](FAQ.md) untuk jawaban pertanyaan umum seperti:
- Mengapa ada `apps/` dan `k8s/apps/`?
- Bagaimana cara update aplikasi?
- Troubleshooting pods yang pending
- Dan banyak lagi...

## 📞 Support

Untuk issues atau pertanyaan, silakan buat issue di repository.

---

**Happy Kubernetes Deployment! 🚀**
