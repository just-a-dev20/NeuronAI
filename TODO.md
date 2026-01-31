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
1. [x] **Fix Go Build Dependencies** ✅
   - Run `go mod tidy` in `backend/go/`
   - Generate proper protobuf Go files using protoc
   - Fix import issues in `internal/grpc/pb/neuronai.pb.go`

2. [x] **Generate Python Protobuf Files** ✅
   - Run `python -m grpc_tools.protoc` to generate `neuronai_pb2.py` and `neuronai_pb2_grpc.py`
   - Place generated files in `backend/python/src/neuronai/grpc/`
   - Note: Minor import fix needed in generated files

3. [ ] **Add Comprehensive Test Coverage** ⚠️ CRITICAL
   - Go: Unit tests for handlers, middleware, gRPC client
   - Python: pytest suite for orchestrator, gRPC server
   - Flutter: Widget tests for screens and providers

### Medium Priority
4. [~] **Implement LLM Integration** 🔄 PARTIAL
   - Configuration exists (OpenAI API key, model settings)
   - Connect actual OpenAI/Claude APIs in Python service
   - Add streaming response handling
   - Implement prompt templates

5. [~] **Supabase Database Integration** 🔄 PARTIAL
   - Database models exist (User, Session, Message, Attachment)
   - [x] Implement `getSessions()` API endpoint in ApiService
   - [x] Add `loadSessions()` method in ChatProvider
   - Set up Supabase project
   - Create database schema
   - Implement CRUD operations in both services

6. [x] **File Upload/Download Endpoints** ✅
   - [x] Add file picker in Flutter (`chat_input.dart`)
   - [x] Implement `sendFile()` method in ChatProvider
   - [x] Add multipart form handling in Go
   - [ ] Implement file storage (Supabase Storage or S3)
   - [x] Add progress tracking

7. [~] **Authentication Flow** 🔄 PARTIAL
   - JWT middleware exists in Go
   - Login screen exists in Flutter
   - [x] Implement secure token storage (`flutter_secure_storage`)
   - [x] Add `login()` method to ApiService
   - [x] Connect login flow to backend API
   - [ ] Integrate Supabase Auth in Flutter
   - [ ] Add signup/password reset screens
   - [ ] Implement token refresh

### Low Priority
8. [~] **UI Polish** 🔄 PARTIAL
   - [x] Create settings screen (`settings_screen.dart`)
   - [x] Navigate to settings from chat screen
   - [x] Implement image display in message bubbles (`cached_network_image`)
   - Add gallery view for generated assets
   - [x] Implement dark mode toggle ✅ (exists in main.dart)
   - Add loading skeletons

9. [ ] **Advanced Features** ⚠️
   - Implement agent-specific tools
   - Add RAG pipeline
   - Create conversation history sidebar
   - Add export functionality

10. [~] **Code Quality** 🔄 PARTIAL
     - [x] Run CodeRabbit review on TODO implementations
     - [x] Add linting to CI pipeline ✅ (gofmt, ruff, mypy, flutter analyze)
     - [x] Create API documentation ✅ (exists in docs/api.md)
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

1. **Write basic tests for critical paths** ⚠️ HIGHEST PRIORITY - Zero test coverage
2. Implement actual LLM API calls in Python orchestrator (currently returns stubs)
3. Initialize Supabase client and implement CRUD operations
4. Add signup/password reset screens to Flutter
5. Create settings screen and gallery view in Flutter
6. Set up environment variables and test the full stack locally
