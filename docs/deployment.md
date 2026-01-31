# NeuronAI Deployment Guide

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Environment Setup](#environment-setup)
4. [Docker Deployment](#docker-deployment)
5. [Cloud Deployment](#cloud-deployment)
6. [Production Checklist](#production-checklist)
7. [Monitoring & Logging](#monitoring--logging)
8. [Troubleshooting](#troubleshooting)

## Overview

NeuronAI can be deployed in multiple configurations:

- **Docker Compose** - Single server, development/staging
- **Kubernetes** - Production scale, high availability
- **Cloud Platforms** - AWS, GCP, Azure managed services
- **Edge Deployment** - On-premises or hybrid

## Prerequisites

### Infrastructure Requirements

**Minimum (Development):**
- 2 CPU cores
- 4 GB RAM
- 20 GB storage
- Docker & Docker Compose

**Recommended (Production):**
- 4+ CPU cores
- 8+ GB RAM
- 100+ GB SSD storage
- Load balancer
- SSL certificates

### Required Services

- **Supabase** - Database and authentication
- **LLM API** - OpenAI, Claude, or self-hosted
- **Container Registry** - Docker Hub, AWS ECR, GCR
- **Domain & DNS** - For production access

### Environment Variables

Production `.env` file:

```bash
# Required
JWT_SECRET=your-production-jwt-secret-min-64-chars
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-service-key
SUPABASE_JWT_SECRET=your-supabase-jwt-secret

# LLM Configuration
OPENAI_API_KEY=sk-prod-...
CLAUDE_API_KEY=sk-ant-...
DEFAULT_LLM_PROVIDER=openai

# Service Configuration
GO_GATEWAY_PORT=8080
PYTHON_SERVICE_PORT=50051
PYTHON_SERVICE_ADDR=python-service:50051

# Security
CORS_ALLOWED_ORIGINS=https://app.neuronai.app,https://admin.neuronai.app
RATE_LIMIT_REQUESTS_PER_MINUTE=100
MAX_MESSAGE_SIZE=10485760  # 10MB

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Monitoring (optional)
SENTRY_DSN=https://...@sentry.io/...
DATADOG_API_KEY=...
```

## Environment Setup

### 1. Supabase Configuration

**Database Schema:**

```sql
-- Create tables
CREATE TABLE conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    title TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID REFERENCES conversations(id),
    user_id UUID REFERENCES auth.users(id),
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    agent_type TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE attachments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    message_id UUID REFERENCES messages(id),
    filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    size_bytes INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_conversations_user_id ON conversations(user_id);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);

-- Row Level Security (RLS)
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own conversations" ON conversations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own conversations" ON conversations
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

**Storage Buckets:**

```sql
-- Create storage bucket for attachments
insert into storage.buckets (id, name)
values ('attachments', 'attachments');

-- Set bucket policies
CREATE POLICY "Users can upload own attachments" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'attachments' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );
```

### 2. SSL/TLS Certificates

**Using Let's Encrypt:**

```bash
# Install certbot
sudo apt-get install certbot

# Generate certificate
sudo certbot certonly --standalone -d api.neuronai.app

# Certificates location
/etc/letsencrypt/live/api.neuronai.app/fullchain.pem
/etc/letsencrypt/live/api.neuronai.app/privkey.pem
```

**Auto-renewal:**

```bash
# Add to crontab
0 12 * * * /usr/bin/certbot renew --quiet
```

## Docker Deployment

### Single Server Deployment

**Directory Structure:**

```
production/
├── docker-compose.yml
├── .env
├── nginx/
│   ├── nginx.conf
│   └── ssl/
├── data/
│   ├── postgres/
│   └── redis/
└── scripts/
    ├── backup.sh
    └── deploy.sh
```

**docker-compose.yml:**

```yaml
version: '3.8'

services:
  # Go API Gateway
  gateway:
    image: neuronai/gateway:latest
    container_name: neuronai-gateway
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - PYTHON_SERVICE_ADDR=python:50051
      - JWT_SECRET=${JWT_SECRET}
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_KEY=${SUPABASE_KEY}
      - LOG_LEVEL=${LOG_LEVEL:-info}
    depends_on:
      - python
    networks:
      - neuronai-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Python AI Service
  python:
    image: neuronai/python:latest
    container_name: neuronai-python
    restart: unless-stopped
    environment:
      - PORT=50051
      - JWT_SECRET=${JWT_SECRET}
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_KEY=${SUPABASE_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - LOG_LEVEL=${LOG_LEVEL:-info}
    networks:
      - neuronai-network
    healthcheck:
      test: ["CMD", "python", "-c", "import grpc; print('OK')"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: neuronai-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - gateway
    networks:
      - neuronai-network

  # Redis Cache (optional)
  redis:
    image: redis:7-alpine
    container_name: neuronai-redis
    restart: unless-stopped
    volumes:
      - ./data/redis:/data
    networks:
      - neuronai-network

networks:
  neuronai-network:
    driver: bridge
```

**nginx.conf:**

```nginx
events {
    worker_connections 1024;
}

http {
    upstream gateway {
        server gateway:8080;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=ws:10m rate=100r/s;

    server {
        listen 80;
        server_name api.neuronai.app;
        
        # Redirect to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name api.neuronai.app;

        # SSL certificates
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # REST API
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://gateway;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # WebSocket
        location /ws {
            limit_req zone=ws burst=100 nodelay;
            
            proxy_pass http://gateway;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            
            proxy_connect_timeout 7d;
            proxy_send_timeout 7d;
            proxy_read_timeout 7d;
        }

        # Health check
        location /health {
            proxy_pass http://gateway;
            access_log off;
        }
    }
}
```

### Deployment Script

**scripts/deploy.sh:**

```bash
#!/bin/bash
set -e

echo "Starting NeuronAI deployment..."

# Load environment variables
export $(grep -v '^#' .env | xargs)

# Pull latest images
docker-compose pull

# Start services
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 10

# Check health
docker-compose ps

# Run migrations (if needed)
# docker-compose exec python python -m alembic upgrade head

echo "Deployment complete!"
echo "API available at: https://api.neuronai.app"
```

### Backup Script

**scripts/backup.sh:**

```bash
#!/bin/bash
set -e

BACKUP_DIR="/backups/neuronai"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup environment
cp .env $BACKUP_DIR/env_$DATE

# Backup Docker volumes
docker run --rm -v neuronai_data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/data_$DATE.tar.gz /data

# Upload to S3 (optional)
# aws s3 cp $BACKUP_DIR/data_$DATE.tar.gz s3://neuronai-backups/

# Clean old backups (keep last 7 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/data_$DATE.tar.gz"
```

## Cloud Deployment

### AWS Deployment

**Architecture:**

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Route 53  │────▶│  CloudFront  │────▶│    ALB      │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                │
                       ┌────────────────────────┼────────────────────────┐
                       │                        │                        │
                       ▼                        ▼                        ▼
                ┌─────────────┐          ┌─────────────┐          ┌─────────────┐
                │   ECS/Fargate│          │   ECS/Fargate│          │   RDS       │
                │   (Go)       │          │   (Python)   │          │ (Postgres)  │
                └─────────────┘          └─────────────┘          └─────────────┘
```

**Terraform Configuration (simplified):**

```hcl
# ECS Cluster
resource "aws_ecs_cluster" "neuronai" {
  name = "neuronai-cluster"
}

# Go Gateway Service
resource "aws_ecs_service" "gateway" {
  name            = "neuronai-gateway"
  cluster         = aws_ecs_cluster.neuronai.id
  task_definition = aws_ecs_task_definition.gateway.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gateway.arn
    container_name   = "gateway"
    container_port   = 8080
  }
}

# Auto Scaling
resource "aws_appautoscaling_target" "gateway" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.neuronai.name}/${aws_ecs_service.gateway.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```

### Google Cloud Platform (GCP)

**Using Cloud Run:**

```yaml
# cloudbuild.yaml
steps:
  # Build Go Gateway
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/neuronai-gateway:$SHORT_SHA', './backend/go']
  
  # Build Python Service
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/neuronai-python:$SHORT_SHA', './backend/python']
  
  # Push images
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/neuronai-gateway:$SHORT_SHA']
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/neuronai-python:$SHORT_SHA']
  
  # Deploy to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'neuronai-gateway'
      - '--image=gcr.io/$PROJECT_ID/neuronai-gateway:$SHORT_SHA'
      - '--region=us-central1'
      - '--platform=managed'
      - '--allow-unauthenticated'
```

### Azure Deployment

**Using Container Instances:**

```bash
# Create resource group
az group create --name neuronai-rg --location eastus

# Deploy Go Gateway
az container create \
  --resource-group neuronai-rg \
  --name neuronai-gateway \
  --image neuronai/gateway:latest \
  --ports 8080 \
  --environment-variables JWT_SECRET=xxx SUPABASE_URL=xxx

# Deploy Python Service
az container create \
  --resource-group neuronai-rg \
  --name neuronai-python \
  --image neuronai/python:latest \
  --ports 50051 \
  --environment-variables JWT_SECRET=xxx OPENAI_API_KEY=xxx
```

## Production Checklist

### Security

- [ ] SSL/TLS certificates configured
- [ ] Environment variables secured (not in code)
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] Security headers set
- [ ] JWT secrets rotated regularly
- [ ] API keys stored in secret manager
- [ ] Database connections encrypted
- [ ] Input validation implemented
- [ ] Dependency vulnerabilities scanned

### Performance

- [ ] Load balancer configured
- [ ] Auto-scaling enabled
- [ ] Database indexes optimized
- [ ] Caching layer (Redis) configured
- [ ] CDN for static assets
- [ ] Connection pooling enabled
- [ ] Resource limits set (CPU/Memory)
- [ ] Health checks configured
- [ ] Graceful shutdown implemented

### Monitoring

- [ ] Application logs aggregated
- [ ] Error tracking (Sentry) configured
- [ ] Performance monitoring (APM) enabled
- [ ] Alerting rules set up
- [ ] Dashboard created
- [ ] Uptime monitoring
- [ ] Database monitoring
- [ ] Resource utilization tracking

### Backup & Recovery

- [ ] Automated backups scheduled
- [ ] Backup restoration tested
- [ ] Disaster recovery plan documented
- [ ] Database snapshots configured
- [ ] Configuration backups
- [ ] Offsite backup storage

### Documentation

- [ ] API documentation published
- [ ] Runbooks created
- [ ] On-call procedures defined
- [ ] Incident response plan
- [ ] Rollback procedures
- [ ] Environment documentation

## Monitoring & Logging

### Logging Configuration

**Go Gateway:**
```go
// Structured JSON logging
logger, _ := zap.NewProduction()
defer logger.Sync()

logger.Info("request processed",
    zap.String("method", r.Method),
    zap.String("path", r.URL.Path),
    zap.Duration("duration", duration),
    zap.Int("status", status),
)
```

**Python Service:**
```python
import structlog

structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ]
)

logger = structlog.get_logger()
logger.info("processing_request", session_id=session_id, user_id=user_id)
```

### Monitoring Stack

**Prometheus + Grafana:**

```yaml
# docker-compose.monitoring.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
```

**Key Metrics:**
- Request rate and latency
- Error rates (4xx, 5xx)
- Active WebSocket connections
- LLM API costs
- Database query performance
- Container resource usage

### Alerting Rules

```yaml
# alertmanager.yml
groups:
  - name: neuronai
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          
      - alert: ServiceDown
        expr: up{job="neuronai-gateway"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "NeuronAI gateway is down"
```

## Troubleshooting

### Common Deployment Issues

**Issue: Services can't communicate**
```bash
# Check network connectivity
docker network ls
docker network inspect neuronai-network

# Verify service discovery
docker-compose exec gateway ping python
```

**Issue: Database connection failures**
```bash
# Check Supabase status
# Verify connection string
curl -I $SUPABASE_URL/rest/v1/

# Check firewall rules
```

**Issue: High memory usage**
```bash
# Monitor container stats
docker stats

# Check for memory leaks
docker-compose restart python
```

**Issue: SSL certificate errors**
```bash
# Verify certificate validity
openssl x509 -in /path/to/cert.pem -text -noout

# Check certificate chain
openssl verify -CAfile /path/to/chain.pem /path/to/cert.pem
```

### Rollback Procedures

**Docker Compose Rollback:**
```bash
# List previous images
docker images | grep neuronai

# Rollback to previous version
docker-compose down
docker-compose up -d --no-deps --build gateway

# Or use specific tag
docker-compose up -d gateway=neuronai/gateway:v1.0.0
```

**Database Rollback:**
```bash
# Restore from backup
docker run --rm -v neuronai_data:/data -v /backups:/backup alpine sh -c "cd / && tar xzf /backup/data_YYYYMMDD.tar.gz"
```

### Emergency Contacts

- **Primary On-Call:** [Contact Info]
- **Secondary On-Call:** [Contact Info]
- **Infrastructure Team:** [Contact Info]
- **Supabase Support:** support@supabase.io

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [GCP Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
