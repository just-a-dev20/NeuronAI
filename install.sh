#!/bin/bash
set -e

# NeuronAI One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/yourusername/neuronai/main/install.sh | bash

REPO_URL="${REPO_URL:-https://github.com/yourusername/neuronai.git}"  # Replace with actual repository URL
INSTALL_DIR="${INSTALL_DIR:-$HOME/neuronai}"

echo "=========================================="
echo "NeuronAI Installer"
echo "=========================================="

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v git &> /dev/null; then
    echo "Installing git..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y git
    elif command -v yum &> /dev/null; then
        sudo yum install -y git
    else
        echo "ERROR: Please install git manually"
        exit 1
    fi
fi

if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✓ Docker installed (please log out and back in for group changes to take effect)"
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# Clone repository
echo ""
echo "Cloning NeuronAI repository..."
if [ -d "$INSTALL_DIR" ]; then
    echo "Directory $INSTALL_DIR already exists. Updating..."
    cd "$INSTALL_DIR"
    git pull
else
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Setup environment
echo ""
echo "Setting up environment..."
cd infra/docker

if [ ! -f .env ]; then
    cp .env.example .env
    echo "✓ Created .env file"
    echo ""
    echo "⚠️  IMPORTANT: Please edit .env file and set:"
    echo "   - JWT_SECRET (generate with: openssl rand -base64 64)"
    echo "   - POSTGRES_PASSWORD"
    echo "   - REDIS_PASSWORD"
    echo "   - MINIO_ROOT_PASSWORD"
    echo "   - OPENAI_API_KEY"
    echo ""
    read -p "Press Enter to continue with default values (NOT recommended for production)..."
fi

# Deploy
echo ""
echo "Deploying NeuronAI..."
if [ ! -f "scripts/deploy.sh" ]; then
    echo "ERROR: scripts/deploy.sh not found"
    exit 1
fi
if [ ! -x "scripts/deploy.sh" ]; then
    echo "ERROR: scripts/deploy.sh is not executable. Running: chmod +x scripts/deploy.sh"
    chmod +x scripts/deploy.sh
fi
./scripts/deploy.sh

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "NeuronAI is now running at:"
echo "  - API Gateway: http://localhost:8080"
echo "  - MinIO Console: http://localhost:9001"
echo ""
echo "⚠️  SECURITY WARNING ⚠️"
echo "Default admin credentials (admin@neuronai.local / admin123)"
echo "MUST be changed immediately after first login."
echo "These are insecure defaults for development only."
echo ""
echo "For more information, see:"
echo "  - Self-Hosting Guide: infra/docker/SELFHOSTING.md"
echo "  - Documentation: docs/"
echo ""
echo "Useful commands:"
echo "  cd $INSTALL_DIR/infra/docker"
echo "  ./scripts/backup.sh    # Create backup"
echo "  ./scripts/update.sh    # Update to latest version"
echo "  docker-compose -f docker-compose.selfhosted.yml logs -f  # View logs"
echo ""
