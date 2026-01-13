#!/bin/bash

# CloudLab Cleanup Script
# This script stops and removes all CloudLab containers and volumes

set -e

echo "🧹 CloudLab Cleanup Script"
echo "=========================="
echo ""

read -p "⚠️  This will stop all services and remove volumes. Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo "🛑 Stopping services..."
docker compose down

read -p "🗑️  Remove volumes (all data will be lost)? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing volumes..."
    docker compose down -v
    echo "✅ Volumes removed"
fi

echo ""
read -p "🧹 Remove Docker images? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing images..."
    docker compose down --rmi all
    echo "✅ Images removed"
fi

echo ""
echo "✨ Cleanup complete!"
