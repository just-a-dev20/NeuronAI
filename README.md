# NeuronAI

A multi-platform AI assistant application with Flutter frontend and Go/Python backend.

## Architecture

- **Frontend**: Flutter (Dart) - Android, iPad, Linux Desktop
- **Backend**: 
  - Go - API Gateway, WebSocket server, gRPC client
  - Python - AI processing, gRPC server, LLM integration
- **Infrastructure**: Supabase (Database & Auth), Docker, CI/CD

## Project Structure

```
NeuronAI/
├── backend/
│   ├── go/              # Go API Gateway
│   └── python/          # Python AI Service
├── frontend/            # Flutter Application
├── proto/               # Protobuf schemas
├── infra/               # Docker, K8s, CI/CD
└── docs/                # Documentation
```

## Quick Start

### Prerequisites

- Go 1.22+
- Python 3.11+
- Flutter 3.16+
- Docker & Docker Compose
- Supabase account (optional - can use local database)

### One-Line Installer (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/neuronai/main/install.sh | bash
```

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/neuronai/main/install.sh -o install.sh
cat install.sh  # Review the script
bash install.sh
```

### Self-Hosted Deployment

The easiest way to get started is using Docker Compose with the self-hosted configuration:

```bash
git clone https://github.com/yourusername/neuronai.git  # Replace 'yourusername' with actual GitHub username
cd neuronai/infra/docker

# Copy and edit environment configuration
cp .env.example .env
# Edit .env with your settings

# Deploy
./scripts/deploy.sh
```

Services will be available at:
- API Gateway: http://localhost:8080
- MinIO Console: http://localhost:9001

**⚠️ SECURITY WARNING: Default admin credentials (admin@neuronai.local / admin123) MUST be changed immediately after first login. These are insecure defaults for development only.**

See [Self-Hosting Guide](infra/docker/SELFHOSTING.md) for detailed instructions.

### Development Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/neuronai.git
cd neuronai
```

2. Create `.env` file:
```bash
JWT_SECRET=your-secret-key
SUPABASE_URL=your-supabase-url
SUPABASE_KEY=your-supabase-key
OPENAI_API_KEY=your-openai-key
```

### Backend Services

#### Go Gateway

```bash
cd backend/go
go mod download
JWT_SECRET=secret go run cmd/gateway/main.go
```

#### Python AI Service

```bash
cd backend/python
uv pip install -e ".[dev]"
python main.py
```

### Docker (Recommended)

**Self-Hosted (Full Stack):**
```bash
cd infra/docker
./scripts/deploy.sh
```

**Development Only:**
```bash
cd infra/docker
docker-compose up -d
```

### Flutter Frontend

```bash
cd frontend
flutter pub get
flutter run
```

## Development

### Running Tests

**Go:**
```bash
cd backend/go
go test ./...
```

**Python:**
```bash
cd backend/python
pytest
```

**Flutter:**
```bash
cd frontend
flutter test
```

### Code Quality

**Go:**
```bash
gofmt -w .
go vet ./...
```

**Python:**
```bash
ruff check .
ruff format .
mypy src/
```

**Flutter:**
```bash
flutter analyze
dart format .
```

## Features

- Real-time chat with WebSocket
- Multi-agent swarm orchestration
- Streaming responses
- File attachments (images, videos)
- Syntax highlighting for code
- Markdown & LaTeX support
- Cross-platform (Android, iPad, Linux)

## Documentation

Comprehensive documentation is available in the [docs/](docs/) directory:

- **[Architecture](docs/architecture.md)** - System design and component overview
- **[API Reference](docs/api.md)** - Complete REST, WebSocket, and gRPC documentation
- **[Development Guide](docs/development.md)** - Setup, coding standards, and workflows
- **[Deployment Guide](docs/deployment.md)** - Production deployment instructions
- **[Self-Hosting Guide](infra/docker/SELFHOSTING.md)** - Self-hosted deployment with Docker
- **[Backend](docs/backend.md)** - Go and Python service documentation
- **[Frontend](docs/frontend.md)** - Flutter app documentation
- **[Protocol Buffers](docs/protobuf.md)** - gRPC schema reference

### REST Endpoints

- `GET /health` - Health check
- `POST /api/v1/chat` - Send message
- `POST /api/v1/chat/stream` - Stream message
- `WS /ws` - WebSocket connection

### gRPC Services

See `proto/neuronai.proto` or [Protocol Buffers documentation](docs/protobuf.md) for service definitions.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

GNU Affero General Public License v3.0 (AGPL v3) - see LICENSE file for details
