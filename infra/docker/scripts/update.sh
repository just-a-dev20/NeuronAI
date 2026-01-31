#!/bin/bash
set -e

# NeuronAI Update Script
# Usage: ./update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "NeuronAI Update"
echo "=========================================="

# Pull latest code
echo "Pulling latest code..."
cd "$DOCKER_DIR/../.."
git pull origin main || echo "⚠️  Could not pull latest code"

# Backup before update
echo "Creating backup before update..."
"$SCRIPT_DIR/backup.sh" || echo "⚠️  Backup failed, continuing anyway..."

# Rebuild and restart services
echo "Rebuilding and restarting services..."
cd "$DOCKER_DIR"
docker-compose -f docker-compose.selfhosted.yml down
docker-compose -f docker-compose.selfhosted.yml pull
docker-compose -f docker-compose.selfhosted.yml up -d --build

echo ""
echo "=========================================="
echo "Update Complete!"
echo "=========================================="
echo ""
echo "Services have been updated and restarted."
echo ""
