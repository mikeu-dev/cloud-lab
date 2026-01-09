# Migration Guide: Docker Compose → Kubernetes

Panduan migrasi CloudLab dari Docker Compose ke Kubernetes.

## 📊 Comparison Overview

| Aspect | Docker Compose | Kubernetes |
|--------|---------------|------------|
| **Orchestration** | Single host | Multi-node cluster |
| **Scaling** | Manual (`docker-compose scale`) | Auto-scaling (HPA) |
| **High Availability** | Limited | Built-in (replicas, self-healing) |
| **Load Balancing** | Basic | Advanced (Services, Ingress) |
| **Storage** | Docker volumes | PersistentVolumes |
| **Networking** | Bridge network | Service mesh, Network Policies |
| **Configuration** | Environment variables | ConfigMaps, Secrets |
| **Deployment** | `docker-compose up` | `kubectl apply` |
| **Monitoring** | Manual setup | Native integration |

## 🔄 Mapping Components

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
  replicas: 3  # HA dengan multiple replicas
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
- Services provide DNS-based service discovery
- Network Policies untuk traffic control (optional)
- Pods dapat communicate via service names

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
- Readiness probes ensure service is ready
- Init containers untuk startup dependencies
- Service discovery handles availability

## 📝 Migration Steps

### Phase 1: Preparation

1. **Audit Current Setup**
   ```bash
   # List running services
   docker-compose ps
   
   # Check resource usage
   docker stats
   
   # Export configurations
   docker-compose config > docker-compose-backup.yml
   ```

2. **Build and Tag Images**
   ```bash
   # Build images dengan versioning
   cd apps/demo-apps/nodejs-app
   docker build -t cloudlab-nodejs-app:1.0.0 .
   docker tag cloudlab-nodejs-app:1.0.0 cloudlab-nodejs-app:latest
   
   cd ../python-app
   docker build -t cloudlab-python-app:1.0.0 .
   docker tag cloudlab-python-app:1.0.0 cloudlab-python-app:latest
   ```

3. **Backup Data**
   ```bash
   # Backup Grafana data
   docker cp cloudlab-grafana:/var/lib/grafana ./backup/grafana
   
   # Backup Prometheus data
   docker cp cloudlab-prometheus:/prometheus ./backup/prometheus
   ```

### Phase 2: Setup Kubernetes

1. **Choose Cluster Type**
   - Local: Minikube or Kind
   - Cloud: GKE, EKS, or AKS
   - On-premise: kubeadm or k3s

2. **Install Required Tools**
   ```bash
   # kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install kubectl /usr/local/bin/
   
   # Minikube (untuk local)
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   ```

3. **Start Cluster**
   ```bash
   # Minikube
   minikube start --cpus=4 --memory=8192
   minikube addons enable ingress
   minikube addons enable metrics-server
   ```

### Phase 3: Deploy to Kubernetes

1. **Prepare Images**
   ```bash
   # For Minikube
   minikube image load cloudlab-nodejs-app:latest
   minikube image load cloudlab-python-app:latest
   
   # For other clusters, push to registry
   # docker push your-registry/cloudlab-nodejs-app:latest
   ```

2. **Generate SSL Certificates**
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

3. **Deploy Resources**
   ```bash
   # Deploy dengan kustomize
   kubectl apply -k k8s/
   
   # Wait for rollout
   kubectl rollout status deployment/nodejs-app -n cloudlab-apps
   kubectl rollout status deployment/python-app -n cloudlab-apps
   kubectl rollout status deployment/grafana -n cloudlab-monitoring
   kubectl rollout status statefulset/prometheus -n cloudlab-monitoring
   ```

4. **Verify Deployment**
   ```bash
   # Check pods
   kubectl get pods -n cloudlab-apps
   kubectl get pods -n cloudlab-monitoring
   
   # Check services
   kubectl get svc -n cloudlab-apps
   kubectl get svc -n cloudlab-monitoring
   
   # Check ingress
   kubectl get ingress -A
   ```

### Phase 4: Data Migration

1. **Restore Grafana Data**
   ```bash
   # Copy backup ke pod
   kubectl cp ./backup/grafana grafana-<pod-id>:/var/lib/grafana -n cloudlab-monitoring
   
   # Restart Grafana
   kubectl rollout restart deployment/grafana -n cloudlab-monitoring
   ```

2. **Restore Prometheus Data**
   ```bash
   # Copy backup ke pod
   kubectl cp ./backup/prometheus prometheus-0:/prometheus -n cloudlab-monitoring
   
   # Restart Prometheus
   kubectl rollout restart statefulset/prometheus -n cloudlab-monitoring
   ```

### Phase 5: Testing

1. **Functional Testing**
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

2. **Load Testing**
   ```bash
   # Generate load
   kubectl run -it --rm load-generator --image=busybox -- /bin/sh
   while true; do wget -q -O- http://nodejs-app.cloudlab-apps.svc.cluster.local:3001; done
   
   # Watch autoscaling
   kubectl get hpa -n cloudlab-apps --watch
   ```

3. **Monitoring Testing**
   ```bash
   # Check Prometheus targets
   kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring
   # Open http://localhost:9090/targets
   
   # Check Grafana dashboards
   # Open http://localhost:3000
   ```

### Phase 6: Cutover

1. **Update DNS/Hosts**
   ```bash
   # Get Ingress IP
   kubectl get ingress -n cloudlab-apps
   
   # Update /etc/hosts
   echo "$(minikube ip) cloudlab.local grafana.cloudlab.local" | sudo tee -a /etc/hosts
   ```

2. **Stop Docker Compose**
   ```bash
   # Stop services
   docker-compose down
   
   # Keep volumes untuk backup
   # docker-compose down -v  # Only if you want to remove volumes
   ```

3. **Verify Production Traffic**
   ```bash
   # Test via Ingress
   curl https://cloudlab.local
   curl https://grafana.cloudlab.local
   ```

## 🔙 Rollback Procedure

Jika ada masalah, rollback ke Docker Compose:

```bash
# 1. Stop Kubernetes deployment
kubectl delete -k k8s/

# 2. Start Docker Compose
docker-compose up -d

# 3. Verify services
docker-compose ps
```

## ⚠️ Common Issues

### Issue 1: ImagePullBackOff

**Problem:** Kubernetes tidak bisa pull image

**Solution:**
```bash
# For Minikube, load image langsung
minikube image load cloudlab-nodejs-app:latest

# For other clusters, push ke registry
docker tag cloudlab-nodejs-app:latest your-registry/cloudlab-nodejs-app:latest
docker push your-registry/cloudlab-nodejs-app:latest

# Update kustomization.yaml dengan registry URL
```

### Issue 2: Pods Pending

**Problem:** Pods stuck di Pending state

**Solution:**
```bash
# Check node resources
kubectl top nodes

# Check pod events
kubectl describe pod <pod-name> -n cloudlab-apps

# Scale down jika resource tidak cukup
kubectl scale deployment nodejs-app --replicas=1 -n cloudlab-apps
```

### Issue 3: Ingress Not Working

**Problem:** Tidak bisa access via Ingress

**Solution:**
```bash
# Check Ingress controller
kubectl get pods -n ingress-nginx

# For Minikube, enable ingress addon
minikube addons enable ingress

# For Minikube, run tunnel
minikube tunnel
```

### Issue 4: PVC Pending

**Problem:** PersistentVolumeClaim stuck di Pending

**Solution:**
```bash
# Check storage class
kubectl get storageclass

# For Minikube, enable storage provisioner
minikube addons enable storage-provisioner

# Check PVC events
kubectl describe pvc grafana-storage -n cloudlab-monitoring
```

## 📊 Performance Comparison

### Resource Usage

| Metric | Docker Compose | Kubernetes (3 replicas) |
|--------|---------------|------------------------|
| **Memory** | ~2GB | ~4GB |
| **CPU** | ~1 core | ~2 cores |
| **Startup Time** | ~30s | ~60s |
| **Scalability** | Manual | Auto (HPA) |

### Benefits Gained

✅ **High Availability**: Multiple replicas dengan self-healing
✅ **Auto-scaling**: HPA based on CPU/memory
✅ **Rolling Updates**: Zero-downtime deployments
✅ **Better Monitoring**: Native Prometheus integration
✅ **Cloud Portability**: Deploy anywhere
✅ **Production Ready**: Enterprise-grade orchestration

## 📚 Next Steps

1. **Setup CI/CD**: Update GitHub Actions untuk Kubernetes deployment
2. **Implement GitOps**: ArgoCD atau FluxCD untuk automated sync
3. **Add Monitoring**: Prometheus Operator, Grafana dashboards
4. **Security Hardening**: Network Policies, RBAC, Pod Security
5. **Backup Strategy**: Velero untuk cluster backup
6. **Service Mesh**: Istio atau Linkerd untuk advanced traffic management

## 🔗 References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Compose to Kubernetes](https://kubernetes.io/docs/tasks/configure-pod-container/translate-compose-kubernetes/)
- [Kompose Tool](https://kompose.io/) - Auto-convert Compose to K8s
- [Kustomize](https://kustomize.io/)

---

**Migration Complete! Welcome to Kubernetes! 🎉**
