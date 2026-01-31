# NeuronAI Architecture Documentation

## Overview

NeuronAI is a multi-platform AI assistant application built with a microservices architecture. The system consists of three main components:

1. **Go API Gateway** - HTTP/WebSocket server and gRPC client
2. **Python AI Service** - gRPC server with LLM integration and agent orchestration
3. **Flutter Frontend** - Cross-platform mobile and desktop application

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Frontend                          │
│                    (Android, iPad, Linux)                        │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Chat Screen │  │Login Screen  │  │   Settings   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │Auth Provider │  │Chat Provider │  │Settings Prov │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐                            │
│  │ API Service  │  │ WebSocket    │                            │
│  └──────────────┘  └──────────────┘                            │
└────────────────────┬────────────────────────────────────────────┘
                     │ HTTP/WebSocket
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Go API Gateway                              │
│                         (Port 8080)                              │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ REST API     │  │ WebSocket    │  │ JWT Auth     │          │
│  │ Handlers     │  │ Hub          │  │ Middleware   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐                            │
│  │ gRPC Client  │  │ Config       │                            │
│  └──────────────┘  └──────────────┘                            │
└────────────────────┬────────────────────────────────────────────┘
                     │ gRPC
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Python AI Service                             │
│                         (Port 50051)                             │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ gRPC Server  │  │  Swarm       │  │  Agent       │          │
│  │              │  │ Orchestrator │  │ Logic        │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ LLM Client   │  │ Database     │  │ Config       │          │
│  │ (OpenAI/Claude)│  │ (Supabase)  │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Go API Gateway

**Responsibilities:**
- HTTP server with REST endpoints
- WebSocket hub for real-time communication
- JWT authentication and authorization
- gRPC client to Python service
- Request routing and middleware

**Key Modules:**
- `cmd/gateway/main.go` - Application entry point
- `internal/api/handler.go` - HTTP handlers
- `internal/websocket/hub.go` - WebSocket management
- `internal/grpc/client.go` - gRPC client
- `internal/middleware/auth.go` - JWT middleware
- `internal/config/config.go` - Configuration

**Technology Stack:**
- Go 1.22+
- Standard library HTTP server
- gorilla/websocket (if used)
- google.golang.org/grpc

### 2. Python AI Service

**Responsibilities:**
- gRPC server implementation
- Multi-agent swarm orchestration
- LLM integration (OpenAI, Claude)
- Database operations via Supabase
- Streaming response handling

**Key Modules:**
- `main.py` - Entry point
- `src/neuronai/grpc/server.py` - gRPC server
- `src/neuronai/agents/orchestrator.py` - Agent coordination
- `src/neuronai/models/database.py` - Data models
- `src/neuronai/config/settings.py` - Configuration

**Technology Stack:**
- Python 3.11+
- grpcio + grpcio-tools
- pydantic + pydantic-settings
- supabase-py
- openai/claude SDKs

### 3. Flutter Frontend

**Responsibilities:**
- Cross-platform UI (Android, iPad, Linux)
- State management
- API communication
- WebSocket client
- Authentication flow

**Key Modules:**
- `lib/main.dart` - Application entry
- `lib/screens/` - UI screens
- `lib/providers/` - State management
- `lib/services/` - API/WebSocket services
- `lib/models/` - Data models
- `lib/widgets/` - Reusable components

**Technology Stack:**
- Flutter 3.16+
- Dart 3.0+
- Provider for state management
- Dio for HTTP
- web_socket_channel
- flutter_markdown

## Communication Flow

### 1. Chat Request Flow

```
User → Flutter App → Go Gateway → Python Service → LLM API
                     ↓
              WebSocket Broadcast
                     ↓
              Flutter UI Update
```

### 2. Authentication Flow

```
User → Login Screen → Supabase Auth → JWT Token → API Requests
```

### 3. Streaming Response Flow

```
LLM API → Python Service (stream) → gRPC (stream) → Go Gateway → WebSocket → Flutter
```

## Data Flow

### Request Lifecycle

1. **User Input** - Flutter app captures user message
2. **API Call** - HTTP POST to `/api/v1/chat` or WebSocket message
3. **Authentication** - JWT validation in Go middleware
4. **gRPC Call** - Go gateway forwards to Python service
5. **AI Processing** - Python orchestrator processes with agents
6. **LLM Call** - External API call for response generation
7. **Response** - Streamed back through the chain
8. **UI Update** - Flutter displays response with markdown

## Multi-Agent Swarm Architecture

The Python service implements a swarm intelligence pattern for complex tasks:

```
┌─────────────────────────────────────┐
│         Swarm Orchestrator          │
│                                     │
│  ┌─────────┐  ┌─────────┐          │
│  │Researcher│  │ Writer  │          │
│  │  Agent   │  │  Agent  │          │
│  └────┬────┘  └────┬────┘          │
│       └─────────────┘               │
│              │                      │
│       ┌──────┴──────┐              │
│       ▼             ▼              │
│  ┌─────────┐  ┌─────────┐          │
│  │  Code   │  │  Image  │          │
│  │  Agent  │  │  Agent  │          │
│  └─────────┘  └─────────┘          │
└─────────────────────────────────────┘
```

**Agent Types:**
- **Orchestrator** - Coordinates task distribution
- **Researcher** - Information gathering and analysis
- **Writer** - Content creation and editing
- **Code** - Programming and technical tasks
- **Image** - Visual content generation
- **Video** - Video processing and generation

## Security Architecture

### Authentication
- JWT tokens issued by Supabase Auth
- Tokens validated on every request
- Refresh token mechanism for session persistence

### Authorization
- Role-based access control (RBAC)
- User-specific data isolation
- Resource-level permissions

### Data Protection
- HTTPS/TLS for all communications
- Environment variable management
- Secrets stored in secure vaults

## Scalability Considerations

### Horizontal Scaling
- Go gateway: Stateless, can run multiple instances
- Python service: gRPC load balancing
- Database: Supabase handles scaling

### Caching Strategy
- JWT token caching
- LLM response caching for common queries
- Asset CDN for media files

### Performance Optimizations
- Connection pooling for gRPC
- WebSocket connection reuse
- Lazy loading in Flutter
- Image optimization and caching

## Monitoring & Observability

### Logging
- Structured JSON logging
- Correlation IDs across services
- Log aggregation (ELK stack or similar)

### Metrics
- Request latency
- Error rates
- LLM API costs
- Active connections

### Health Checks
- `/health` endpoint in Go gateway
- gRPC health checks
- Database connectivity checks

## Technology Decisions

### Why Go for Gateway?
- High performance HTTP handling
- Efficient concurrency with goroutines
- Small binary size
- Strong standard library

### Why Python for AI?
- Rich ML/AI ecosystem
- Native async/await support
- Excellent LLM SDKs
- Rapid prototyping

### Why Flutter?
- Single codebase for multiple platforms
- Native performance
- Rich widget ecosystem
- Strong typing with Dart

## Future Architecture Improvements

1. **Message Queue** - Add Redis/RabbitMQ for async processing
2. **Caching Layer** - Implement Redis for response caching
3. **CDN** - Add CloudFront/Cloudflare for asset delivery
4. **Monitoring** - Integrate Prometheus + Grafana
5. **Tracing** - Add OpenTelemetry distributed tracing
