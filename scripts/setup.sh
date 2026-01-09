#!/bin/bash

# CloudLab Setup Script
# This script initializes the CloudLab environment

set -e

echo "🚀 CloudLab Setup Script"
echo "========================"
echo ""

# Check Docker
echo "📦 Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi
echo "✅ Docker found: $(docker --version)"

# Check Docker Compose
echo "📦 Checking Docker Compose installation..."
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi
echo "✅ Docker Compose found: $(docker-compose --version)"

# Create necessary directories
echo ""
echo "📁 Creating directories..."
mkdir -p nginx/ssl nginx/conf.d
mkdir -p monitoring/grafana/dashboards
mkdir -p apps/demo-apps
echo "✅ Directories created"

# Generate SSL certificates if not exist
echo ""
echo "🔒 Checking SSL certificates..."
if [ ! -f "nginx/ssl/cert.pem" ] || [ ! -f "nginx/ssl/key.pem" ]; then
    echo "🔐 Generating self-signed SSL certificates..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout nginx/ssl/key.pem \
        -out nginx/ssl/cert.pem \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=localhost"
    echo "✅ SSL certificates generated"
else
    echo "✅ SSL certificates already exist"
fi

# Create .env file if not exist
echo ""
echo "⚙️  Checking environment configuration..."
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env file created"
else
    echo "✅ .env file already exists"
fi

# Validate Docker Compose configuration
echo ""
echo "🔍 Validating Docker Compose configuration..."
docker-compose config > /dev/null
echo "✅ Docker Compose configuration is valid"

# Pull images
echo ""
echo "📥 Pulling Docker images..."
docker-compose pull
echo "✅ Images pulled"

# Build custom images
echo ""
echo "🔨 Building application images..."
docker-compose build
echo "✅ Images built"

# Start services
echo ""
echo "🚀 Starting services..."
docker-compose up -d
echo "✅ Services started"

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Health checks
echo ""
echo "🏥 Running health checks..."

check_service() {
    local name=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -k -f -s "$url" > /dev/null 2>&1; then
            echo "✅ $name is healthy"
            return 0
        fi
        echo "⏳ Waiting for $name... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ $name failed to start"
    return 1
}

check_service "Node.js App" "https://localhost/health"
check_service "Python API" "https://localhost/api/health"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3000/api/health"

# Display service URLs
echo ""
echo "✨ CloudLab is ready!"
echo "===================="
echo ""
echo "📊 Service URLs:"
echo "  • Node.js App:  https://localhost/"
echo "  • Python API:   https://localhost/api"
echo "  • Grafana:      http://localhost:3000 (admin/admin123)"
echo "  • Prometheus:   http://localhost:9090"
echo ""
echo "📝 Useful commands:"
echo "  • View logs:    docker-compose logs -f"
echo "  • Stop:         docker-compose down"
echo "  • Restart:      docker-compose restart"
echo ""
echo "🎉 Happy coding!"
