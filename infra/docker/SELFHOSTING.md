# NeuronAI Self-Hosting Guide

This guide will help you deploy NeuronAI on your own server or local machine using Docker Compose.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Production Deployment](#production-deployment)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Overview

The self-hosted deployment includes:

- **PostgreSQL** - Database for users, sessions, messages, and attachments
- **Redis** - Cache and session storage
- **Go API Gateway** - REST API and WebSocket server
- **Python AI Service** - AI processing and LLM integration
- **MinIO** - S3-compatible object storage for file uploads
- **Nginx** (optional) - Reverse proxy with SSL support

## Prerequisites

### System Requirements

**Minimum:**
- 2 CPU cores
- 4 GB RAM
- 20 GB storage
- Docker 20.10+ and Docker Compose 2.0+

**Recommended:**
- 4+ CPU cores
- 8+ GB RAM
- 100+ GB SSD storage

### Required Software

```bash
# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt-get install docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/neuronai.git
cd neuronai/infra/docker
```

### 2. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit the configuration
nano .env
```

**Minimum required changes:**
```env
# SECURITY - CHANGE THESE!
JWT_SECRET=your-super-secret-key-here
POSTGRES_PASSWORD=your-secure-password
REDIS_PASSWORD=your-secure-password
MINIO_ROOT_PASSWORD=your-secure-password

# LLM Configuration (required)
OPENAI_API_KEY=sk-your-openai-api-key
```

### 3. Deploy

```bash
# Run the deployment script
./scripts/deploy.sh

# Or manually:
docker-compose -f docker-compose.selfhosted.yml up -d
```

### 4. Access the Services

After deployment, the following services are available:

- **API Gateway**: http://localhost:8080
- **MinIO Console**: http://localhost:9001 (login with MINIO_ROOT_USER/PASSWORD)
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

**Default admin credentials:**
- Email: `admin@neuronai.local`
- Password: `admin123`

⚠️ **Important**: Change the default admin password immediately!

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `JWT_SECRET` | Secret key for JWT tokens | - | Yes |
| `POSTGRES_USER` | PostgreSQL username | neuronai | Yes |
| `POSTGRES_PASSWORD` | PostgreSQL password | changeme | Yes |
| `POSTGRES_DB` | PostgreSQL database name | neuronai | Yes |
| `REDIS_PASSWORD` | Redis password | changeme | Yes |
| `MINIO_ROOT_USER` | MinIO admin user | minioadmin | Yes |
| `MINIO_ROOT_PASSWORD` | MinIO admin password | changeme | Yes |
| `OPENAI_API_KEY` | OpenAI API key | - | Yes |
| `DEFAULT_MODEL` | Default LLM model | gpt-4 | No |
| `MAX_TOKENS` | Max tokens per request | 4096 | No |
| `TEMPERATURE` | LLM temperature | 0.7 | No |
| `ENVIRONMENT` | Environment name | production | No |
| `LOG_LEVEL` | Logging level | INFO | No |

### Generating Secure Secrets

```bash
# Generate JWT secret
openssl rand -base64 64

# Generate secure passwords
openssl rand -base64 32
```

### Database Schema

The database is automatically initialized with the following tables:

- `users` - User accounts and authentication
- `sessions` - Chat sessions/conversations
- `messages` - Chat messages
- `attachments` - File attachments

See `init-scripts/01-schema.sql` for the full schema.

## Production Deployment

### With Nginx and SSL

1. **Configure your domain** in `.env`:
```env
DOMAIN=neuronai.yourdomain.com
LETSENCRYPT_EMAIL=admin@yourdomain.com
```

2. **Get SSL certificates** (Let's Encrypt):
```bash
# Install certbot
sudo apt-get install certbot

# Generate certificates
sudo certbot certonly --standalone -d neuronai.yourdomain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/neuronai.yourdomain.com/fullchain.pem nginx/ssl/
sudo cp /etc/letsencrypt/live/neuronai.yourdomain.com/privkey.pem nginx/ssl/
```

3. **Enable HTTPS in nginx.conf**:
Uncomment and configure the HTTPS server block in `nginx/nginx.conf`.

4. **Deploy with production profile**:
```bash
./scripts/deploy.sh production
```

### Auto-Renewal for SSL

Add to crontab:
```bash
0 12 * * * /usr/bin/certbot renew --quiet && cp /etc/letsencrypt/live/neuronai.yourdomain.com/*.pem /path/to/nginx/ssl/
```

### Security Checklist

- [ ] Change all default passwords
- [ ] Use strong JWT secret (64+ characters)
- [ ] Enable HTTPS with valid SSL certificates
- [ ] Configure firewall (allow only 80, 443, 22)
- [ ] Set up regular backups
- [ ] Enable automatic security updates
- [ ] Use non-root user for deployment
- [ ] Configure log rotation

## Maintenance

### Backup

```bash
# Create backup
./scripts/backup.sh /path/to/backup/dir

# Or manually:
docker-compose -f docker-compose.selfhosted.yml exec postgres pg_dumpall -c -U neuronai > backup.sql
```

### Update

```bash
# Update to latest version
./scripts/update.sh

# Or manually:
git pull
docker-compose -f docker-compose.selfhosted.yml down
docker-compose -f docker-compose.selfhosted.yml up -d --build
```

### View Logs

```bash
# All services
docker-compose -f docker-compose.selfhosted.yml logs -f

# Specific service
docker-compose -f docker-compose.selfhosted.yml logs -f gateway
docker-compose -f docker-compose.selfhosted.yml logs -f python
docker-compose -f docker-compose.selfhosted.yml logs -f postgres
```

### Restart Services

```bash
# Restart all
docker-compose -f docker-compose.selfhosted.yml restart

# Restart specific service
docker-compose -f docker-compose.selfhosted.yml restart gateway
```

### Database Management

```bash
# Access PostgreSQL CLI
docker-compose -f docker-compose.selfhosted.yml exec postgres psql -U neuronai -d neuronai

# Run migrations (if needed)
docker-compose -f docker-compose.selfhosted.yml exec postgres psql -U neuronai -d neuronai -f /docker-entrypoint-initdb.d/01-schema.sql
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose -f docker-compose.selfhosted.yml logs

# Check disk space
df -h

# Check memory
free -h

# Restart with clean slate
docker-compose -f docker-compose.selfhosted.yml down -v
docker-compose -f docker-compose.selfhosted.yml up -d
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker-compose -f docker-compose.selfhosted.yml ps

# Check PostgreSQL logs
docker-compose -f docker-compose.selfhosted.yml logs postgres

# Verify environment variables
cat .env | grep POSTGRES
```

### API Gateway Not Responding

```bash
# Check health endpoint
curl http://localhost:8080/health

# Check gateway logs
docker-compose -f docker-compose.selfhosted.yml logs gateway

# Verify Python service is accessible
docker-compose -f docker-compose.selfhosted.yml exec gateway ping python
```

### High Memory Usage

```bash
# Monitor container stats
docker stats

# Restart services
docker-compose -f docker-compose.selfhosted.yml restart
```

### File Upload Issues

```bash
# Check MinIO is running
curl http://localhost:9000/minio/health/live

# Check MinIO logs
docker-compose -f docker-compose.selfhosted.yml logs minio

# Verify upload directory permissions
ls -la data/uploads/
```

## Advanced Configuration

### Custom Ports

Edit `docker-compose.selfhosted.yml` to change ports:

```yaml
services:
  gateway:
    ports:
      - "8080:8080"  # Change to "9000:8080" for port 9000
```

### External Database

To use an external PostgreSQL database:

```env
# In .env, set external database URL
DATABASE_URL=postgresql://user:pass@external-host:5432/neuronai
```

Then remove the `postgres` service from docker-compose.

### Scaling

For high availability, consider:

1. Using an external managed database (AWS RDS, GCP Cloud SQL)
2. Running multiple gateway instances behind a load balancer
3. Using Redis Cluster for caching
4. Setting up monitoring with Prometheus/Grafana

## Support

For issues and questions:

- Check the [main documentation](../docs/)
- Review [troubleshooting](#troubleshooting) section
- Open an issue on GitHub

## License

MIT License - see LICENSE file for details
