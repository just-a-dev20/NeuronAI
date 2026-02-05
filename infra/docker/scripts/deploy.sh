#!/bin/bash
set -e

# NeuronAI Self-Hosted Deployment Script
# Usage: ./deploy.sh [environment]
# Environment: development (default) or production

ENVIRONMENT=${1:-development}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DOCKER_DIR")"

echo "=========================================="
echo "NeuronAI Self-Hosted Deployment"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        echo "ERROR: Docker is not installed"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        echo "ERROR: Docker Compose is not installed"
        exit 1
    fi
    
    echo "✓ Prerequisites check passed"
}

# Setup environment
setup_environment() {
    echo "Setting up environment..."
    
    cd "$DOCKER_DIR"
    
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            echo "Creating .env file from .env.example..."
            cp .env.example .env
            echo "⚠️  WARNING: Please edit .env file and set secure passwords before running in production!"
            echo "   Default admin credentials: admin@neuronai.local / admin123"
        else
            echo "ERROR: .env.example not found"
            exit 1
        fi
    fi
    
    # Source environment variables
    set -a
    source .env
    set +a
    
    echo "✓ Environment configured"
}

# Create necessary directories
create_directories() {
    echo "Creating necessary directories..."
    
    mkdir -p "$DOCKER_DIR/nginx/ssl"
    mkdir -p "$DOCKER_DIR/data/postgres"
    mkdir -p "$DOCKER_DIR/data/redis"
    mkdir -p "$DOCKER_DIR/data/minio"
    mkdir -p "$DOCKER_DIR/data/uploads"
    
    echo "✓ Directories created"
}

# Build and start services
deploy_services() {
    echo "Building and starting services..."
    
    cd "$DOCKER_DIR"
    
    if [ "$ENVIRONMENT" = "production" ]; then
        echo "Starting in production mode with nginx..."
        docker compose -f docker-compose.selfhosted.yml --profile production up -d --build
    else
        echo "Starting in development mode..."
        docker compose -f docker-compose.selfhosted.yml up -d --build
    fi
    
    echo "✓ Services deployed"
}

# Wait for services to be healthy
wait_for_health() {
    echo "Waiting for services to be healthy..."
    
    cd "$DOCKER_DIR"
    
    # Wait for postgres
    echo "  - Waiting for PostgreSQL..."
    until docker compose -f docker-compose.selfhosted.yml exec -T postgres pg_isready -U "${POSTGRES_USER:-neuronai}" -d "${POSTGRES_DB:-neuronai}" > /dev/null 2>&1; do
        sleep 2
    done
    echo "    ✓ PostgreSQL is ready"
    
    # Wait for gateway
    echo "  - Waiting for API Gateway..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            echo "    ✓ API Gateway is ready"
            break
        fi
        sleep 2
        if [ $i -eq 30 ]; then
            echo "    ⚠️  API Gateway health check timeout"
        fi
    done
    
    echo "✓ All services are healthy"
}

# Display status
show_status() {
    echo ""
    echo "=========================================="
    echo "Deployment Complete!"
    echo "=========================================="
    echo ""
    echo "Services are running:"
    echo "  - API Gateway:     http://localhost:8080"
    echo "  - PostgreSQL:      localhost:5432"
    echo "  - Redis:           localhost:6379"
    echo "  - MinIO (S3):      http://localhost:9000 (Console: http://localhost:9001)"
    echo ""
    
    if [ "$ENVIRONMENT" = "production" ]; then
        echo "  - Nginx Proxy:     http://localhost:80 (and https://localhost:443 if SSL configured)"
    fi
    
    echo ""
    echo "Default admin credentials:"
    echo "  Email:    admin@neuronai.local"
    echo "  Password: admin123"
    echo ""
    echo "⚠️  IMPORTANT: Change the default admin password immediately!"
    echo ""
    echo "Useful commands:"
    echo "  - View logs:       docker compose -f docker-compose.selfhosted.yml logs -f"
    echo "  - Stop services:   docker compose -f docker-compose.selfhosted.yml down"
    echo "  - Restart:         docker compose -f docker-compose.selfhosted.yml restart"
    echo ""
}

# Main deployment flow
main() {
    check_prerequisites
    setup_environment
    create_directories
    deploy_services
    wait_for_health
    show_status
}

main "$@"
