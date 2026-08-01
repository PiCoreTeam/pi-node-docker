#!/usr/bin/env bash
set -e

echo "🔧 Setting up Enterprise Monitoring Stack for Pi Node..."

# Create directories
mkdir -p monitoring

# Prometheus config
cat > monitoring/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'pi-node'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

# Make scripts executable
chmod +x healthcheck.sh alert_manager.sh || true

echo "🚀 Starting production monitoring stack..."
docker compose -f docker-compose.production.yml up -d

echo "✅ Monitoring stack deployed!"
echo "Grafana: http://localhost:3000 (default: admin / admin)"
