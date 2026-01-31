# NeuronAI Project TODO

## ✅ Completed Implementation

### Phase 1: Project Structure & Architecture
- [x] Created project directory structure
- [x] Defined protobuf schemas (`proto/neuronai.proto`)
- [x] Set up configuration files (go.mod, pyproject.toml, pubspec.yaml)

### Phase 2: Go Backend (API Gateway)
- [x] HTTP server with graceful shutdown
- [x] REST API endpoints (/health, /api/v1/chat, /api/v1/chat/stream)
- [x] WebSocket hub for real-time communication
- [x] JWT authentication middleware
- [x] gRPC client for Python service
- [x] Configuration management

### Phase 3: Python Backend (AI Service)
- [x] gRPC server implementation
- [x] Swarm orchestrator for multi-agent coordination
- [x] Pydantic models for database entities
- [x] JWT validation utilities
- [x] Configuration with pydantic-settings
- [x] Agent logic foundation

### Phase 4: Flutter Frontend
- [x] Provider-based state management (Auth, Chat, Settings)
- [x] Dio API client with interceptors and JWT handling
- [x] WebSocket service with auto-reconnection
- [x] Chat interface with message bubbles
- [x] Login screen with form validation
- [x] Markdown support for rich text messages
- [x] Code block rendering
- [x] Responsive UI components

### Phase 5: Infrastructure & DevOps
- [x] Multi-stage Dockerfiles (Go & Python)
- [x] Docker Compose configuration
- [x] GitHub Actions CI/CD pipeline
- [x] Comprehensive README with setup instructions

---

## 🚧 Remaining Tasks (Priority Order)

### High Priority
1. [ ] **Fix Go Build Dependencies**
   - Run `go mod tidy` in `backend/go/`
   - Generate proper protobuf Go files using protoc
   - Fix import issues in `internal/grpc/pb/neuronai.pb.go`

2. [ ] **Generate Python Protobuf Files**
   - Run `python -m grpc_tools.protoc` to generate `neuronai_pb2.py` and `neuronai_pb2_grpc.py`
   - Place generated files in `backend/python/src/neuronai/grpc/`

3. [ ] **Add Comprehensive Test Coverage**
   - Go: Unit tests for handlers, middleware, gRPC client
   - Python: pytest suite for orchestrator, gRPC server
   - Flutter: Widget tests for screens and providers

### Medium Priority
4. [ ] **Implement LLM Integration**
   - Connect OpenAI/Claude APIs in Python service
   - Add streaming response handling
   - Implement prompt templates

5. [ ] **Supabase Database Integration**
   - Set up Supabase project
   - Create database schema
   - Implement CRUD operations in both services

6. [ ] **File Upload/Download Endpoints**
   - Add multipart form handling in Go
   - Implement file storage (Supabase Storage or S3)
   - Add progress tracking

7. [ ] **Authentication Flow**
   - Integrate Supabase Auth in Flutter
   - Add signup/password reset screens
   - Implement token refresh

### Low Priority
8. [ ] **UI Polish**
   - Create settings screen
   - Add gallery view for generated assets
   - Implement dark mode toggle
   - Add loading skeletons

9. [ ] **Advanced Features**
   - Implement agent-specific tools
   - Add RAG pipeline
   - Create conversation history sidebar
   - Add export functionality

10. [ ] **Code Quality**
    - Run CodeRabbit review
    - Add linting to CI pipeline
    - Create API documentation
    - Add architecture decision records (ADRs)

---

## 📝 Quick Commands

```bash
# Generate protobuf files
cd proto
protoc --go_out=../backend/go/internal/grpc/pb --go-grpc_out=../backend/go/internal/grpc/pb neuronai.proto
python -m grpc_tools.protoc -I. --python_out=../backend/python/src/neuronai/grpc --grpc_python_out=../backend/python/src/neuronai/grpc neuronai.proto

# Fix Go dependencies
cd backend/go && go mod tidy

# Install Python dependencies
cd backend/python && uv pip install -e ".[dev]"

# Run tests
cd backend/go && go test ./...
cd backend/python && pytest
cd frontend && flutter test

# Start services
cd infra/docker && docker-compose up -d
```

---

## 🎯 Next Immediate Actions

1. Fix the Go protobuf imports and build the gateway service
2. Generate Python protobuf files to enable gRPC communication
3. Write basic tests for critical paths
4. Set up environment variables and test the full stack locally
