#!/bin/bash
set -e

# NeuronAI Backup Script
# Usage: ./backup.sh [backup_directory]

BACKUP_DIR=${1:-"./backups"}
DATE=$(date +%Y%m%d_%H%M%S)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "NeuronAI Backup"
echo "Date: $DATE"
echo "=========================================="

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup environment
echo "Backing up environment configuration..."
if [ -f "$DOCKER_DIR/.env" ]; then
    cp "$DOCKER_DIR/.env" "$BACKUP_DIR/env_$DATE"
    echo "✓ Environment backed up"
fi

# Backup database
echo "Backing up PostgreSQL database..."
cd "$DOCKER_DIR"
docker-compose -f docker-compose.selfhosted.yml exec -T postgres pg_dumpall -c -U neuronai > "$BACKUP_DIR/database_$DATE.sql" 2>/dev/null || echo "⚠️  Database backup skipped (PostgreSQL not running)"

if [ -f "$BACKUP_DIR/database_$DATE.sql" ]; then
    gzip "$BACKUP_DIR/database_$DATE.sql"
    echo "✓ Database backed up"
fi

# Backup volumes
echo "Backing up Docker volumes..."
cd "$DOCKER_DIR"

# Create volume backup
docker run --rm \
    -v neuronai_postgres_data:/data/postgres \
    -v neuronai_redis_data:/data/redis \
    -v neuronai_minio_data:/data/minio \
    -v "$BACKUP_DIR:/backup" \
    alpine:latest \
    tar czf "/backup/volumes_$DATE.tar.gz" -C /data . 2>/dev/null || echo "⚠️  Volume backup skipped (volumes not found)"

if [ -f "$BACKUP_DIR/volumes_$DATE.tar.gz" ]; then
    echo "✓ Volumes backed up"
fi

# Cleanup old backups (keep last 7 days)
echo "Cleaning up old backups..."
find "$BACKUP_DIR" -name "env_*" -mtime +7 -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "database_*.sql.gz" -mtime +7 -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "volumes_*.tar.gz" -mtime +7 -delete 2>/dev/null || true

echo ""
echo "=========================================="
echo "Backup Complete!"
echo "=========================================="
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Files created:"
ls -lh "$BACKUP_DIR"/*_$DATE* 2>/dev/null || echo "  No backup files created"
echo ""
