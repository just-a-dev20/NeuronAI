# NeuronAI Development Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Setup](#project-setup)
3. [Development Workflow](#development-workflow)
4. [Code Standards](#code-standards)
5. [Testing](#testing)
6. [Debugging](#debugging)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

- **Go** 1.22 or higher
- **Python** 3.11 or higher
- **Flutter** 3.16 or higher
- **Docker** & Docker Compose
- **Git**
- **Protocol Buffers** compiler (protoc)

### Optional Tools

- **VS Code** with extensions:
  - Go
  - Python
  - Flutter/Dart
  - Protocol Buffers
- **Postman** or **Insomnia** for API testing
- **Android Studio** for Android development

### Environment Variables

Create a `.env` file in the project root:

```bash
# Required
JWT_SECRET=your-super-secret-jwt-key-min-32-chars
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key

# Optional
OPENAI_API_KEY=your-openai-api-key
CLAUDE_API_KEY=your-claude-api-key
PYTHON_SERVICE_ADDR=localhost:50051
GO_GATEWAY_PORT=8080
LOG_LEVEL=info
```

## Project Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/neuronai.git
cd neuronai
```

### 2. Install Go Dependencies

```bash
cd backend/go
go mod download
go mod tidy
cd ../..
```

### 3. Install Python Dependencies

Using `uv` (recommended):

```bash
cd backend/python
uv pip install -e ".[dev]"
cd ../..
```

Or using pip:

```bash
cd backend/python
pip install -e ".[dev]"
cd ../..
```

### 4. Install Flutter Dependencies

```bash
cd frontend
flutter pub get
cd ..
```

### 5. Generate Protocol Buffer Files

```bash
# Generate Go files
cd proto
protoc --go_out=../backend/go/internal/grpc/pb \
       --go-grpc_out=../backend/go/internal/grpc/pb \
       neuronai.proto

# Generate Python files
python -m grpc_tools.protoc -I. \
       --python_out=../backend/python/src/neuronai/grpc \
       --grpc_python_out=../backend/python/src/neuronai/grpc \
       neuronai.proto

cd ..
```

### 6. Verify Setup

```bash
# Test Go build
cd backend/go
go build ./cmd/gateway
cd ../..

# Test Python
cd backend/python
python -c "import neuronai; print('OK')"
cd ../..

# Test Flutter
cd frontend
flutter analyze
cd ..
```

## Development Workflow

### Running Services Locally

#### Option 1: Individual Services

**Terminal 1 - Go Gateway:**
```bash
cd backend/go
export JWT_SECRET=your-secret
export SUPABASE_URL=your-url
export SUPABASE_KEY=your-key
go run cmd/gateway/main.go
```

**Terminal 2 - Python Service:**
```bash
cd backend/python
export JWT_SECRET=your-secret
export SUPABASE_URL=your-url
export SUPABASE_KEY=your-key
python main.py
```

**Terminal 3 - Flutter (choose one):**

```bash
# Linux Desktop
cd frontend
flutter run -d linux

# Android Emulator
cd frontend
flutter run -d emulator-5554

# Chrome (Web)
cd frontend
flutter run -d chrome
```

#### Option 2: Docker Compose (Recommended)

```bash
cd infra/docker
docker-compose up -d
```

This starts:
- Go gateway on port 8080
- Python service on port 50051
- (Optional) Redis, PostgreSQL

### Development Scripts

Add to your shell profile (`.bashrc`, `.zshrc`):

```bash
# NeuronAI aliases
alias nr-go='cd /path/to/neuronai/backend/go && go run cmd/gateway/main.go'
alias nr-py='cd /path/to/neuronai/backend/python && python main.py'
alias nr-flutter='cd /path/to/neuronai/frontend && flutter run'
alias nr-test='cd /path/to/neuronai && ./scripts/test-all.sh'
alias nr-lint='cd /path/to/neuronai && ./scripts/lint-all.sh'
```

### Git Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes and commit:**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

3. **Push and create PR:**
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Commit message format:**
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation
   - `test:` Tests
   - `refactor:` Code refactoring
   - `chore:` Maintenance

## Code Standards

### Go Standards

**Formatting:**
```bash
gofmt -w .
goimports -w .
```

**Linting:**
```bash
go vet ./...
golangci-lint run  # if installed
```

**Style Guidelines:**
- Use `gofmt` for formatting
- Maximum line length: 100 characters
- Use meaningful variable names
- Add comments for exported functions
- Handle all errors explicitly

**Example:**
```go
// ProcessChat handles incoming chat requests and forwards to AI service.
func (h *Handler) ProcessChat(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    
    var req ChatRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        h.respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }
    
    resp, err := h.pythonClient.ProcessChat(ctx, &req)
    if err != nil {
        h.logger.Error("failed to process chat", zap.Error(err))
        h.respondError(w, http.StatusInternalServerError, "processing failed")
        return
    }
    
    h.respondJSON(w, http.StatusOK, resp)
}
```

### Python Standards

**Formatting & Linting:**
```bash
cd backend/python
ruff check .
ruff format .
mypy src/
```

**Style Guidelines:**
- Use type hints for all function signatures
- Follow PEP 8 naming conventions
- Maximum line length: 88 characters (Black default)
- Use docstrings for modules, classes, and functions
- Use `isort` for import sorting

**Example:**
```python
from typing import Optional
from pydantic import BaseModel

class ChatRequest(BaseModel):
    """Request model for chat messages."""
    
    session_id: str
    content: str
    message_type: str = "text"
    metadata: Optional[dict] = None

async def process_chat(request: ChatRequest) -> ChatResponse:
    """Process a chat request through the orchestrator.
    
    Args:
        request: The chat request containing message details.
        
    Returns:
        ChatResponse with AI-generated content.
        
    Raises:
        ValueError: If request validation fails.
        ProcessingError: If AI processing fails.
    """
    if not request.content.strip():
        raise ValueError("Content cannot be empty")
    
    # Process through orchestrator
    result = await orchestrator.process(request)
    return ChatResponse(**result)
```

### Flutter/Dart Standards

**Formatting & Analysis:**
```bash
cd frontend
dart format .
flutter analyze
```

**Style Guidelines:**
- Use `dart format` for formatting
- Maximum line length: 80 characters
- Use `const` constructors where possible
- Follow Effective Dart guidelines
- Use `snake_case` for files, `camelCase` for variables

**Example:**
```dart
import 'package:flutter/material.dart';

/// A widget that displays a chat message bubble.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isUser,
    super.key,
  });

  final String message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser 
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}
```

## Testing

### Running Tests

**Go:**
```bash
cd backend/go

# Run all tests
go test ./...

# Run with coverage
go test -cover ./...

# Run specific package
go test ./internal/api/...

# Run with race detection
go test -race ./...
```

**Python:**
```bash
cd backend/python

# Run all tests
pytest

# Run with coverage
pytest --cov=src/neuronai --cov-report=html

# Run specific test file
pytest tests/test_orchestrator.py

# Run with verbose output
pytest -v
```

**Flutter:**
```bash
cd frontend

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/providers/chat_provider_test.dart

# Run integration tests
flutter test integration_test/
```

### Writing Tests

**Go Test Example:**
```go
func TestProcessChat(t *testing.T) {
    tests := []struct {
        name       string
        request    ChatRequest
        wantStatus int
        wantErr    bool
    }{
        {
            name: "valid request",
            request: ChatRequest{
                SessionID: "test-session",
                Content:   "Hello",
            },
            wantStatus: http.StatusOK,
            wantErr:    false,
        },
        {
            name:       "empty content",
            request:    ChatRequest{SessionID: "test-session"},
            wantStatus: http.StatusBadRequest,
            wantErr:    true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test implementation
        })
    }
}
```

**Python Test Example:**
```python
import pytest
from neuronai.agents.orchestrator import Orchestrator

@pytest.fixture
def orchestrator():
    return Orchestrator()

@pytest.mark.asyncio
async def test_process_chat_valid(orchestrator):
    request = ChatRequest(
        session_id="test-session",
        content="Hello"
    )
    
    response = await orchestrator.process_chat(request)
    
    assert response.content is not None
    assert response.status == "completed"

@pytest.mark.asyncio
async def test_process_chat_empty_content(orchestrator):
    request = ChatRequest(
        session_id="test-session",
        content=""
    )
    
    with pytest.raises(ValueError, match="Content cannot be empty"):
        await orchestrator.process_chat(request)
```

**Flutter Test Example:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:neuronai/providers/chat_provider.dart';

void main() {
  group('ChatProvider', () {
    late ChatProvider provider;
    
    setUp(() {
      provider = ChatProvider(
        apiService: MockApiService(),
        wsService: MockWebSocketService(),
      );
    });
    
    test('should add message to chat', () {
      provider.addMessage('Hello', isUser: true);
      
      expect(provider.messages.length, 1);
      expect(provider.messages.first.content, 'Hello');
    });
    
    test('should clear messages', () {
      provider.addMessage('Hello', isUser: true);
      provider.clearMessages();
      
      expect(provider.messages, isEmpty);
    });
  });
}
```

## Debugging

### Go Debugging

**Using VS Code:**
1. Set breakpoints in code
2. Press F5 or click "Run and Debug"
3. Select "Go Launch" configuration

**Using Delve (command line):**
```bash
cd backend/go
dlv debug cmd/gateway/main.go
(dlv) break main.main
(dlv) continue
```

**Logging:**
```go
import "log"

// Simple logging
log.Printf("Processing request: %s", requestID)

// Structured logging (if using zap)
logger.Info("processing chat",
    zap.String("session_id", sessionID),
    zap.String("user_id", userID),
)
```

### Python Debugging

**Using VS Code:**
1. Set breakpoints
2. Press F5
3. Select "Python: Current File" configuration

**Using pdb (command line):**
```python
import pdb; pdb.set_trace()  # Add breakpoint
```

**Logging:**
```python
import logging

logger = logging.getLogger(__name__)

logger.debug("Debug information")
logger.info("Processing request: %s", request_id)
logger.warning("Warning message")
logger.error("Error occurred", exc_info=True)
```

### Flutter Debugging

**Using VS Code:**
1. Set breakpoints
2. Press F5
3. Use Debug Console for inspection

**Flutter DevTools:**
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

**Logging:**
```dart
import 'dart:developer' as developer;

// Simple logging
print('Debug message');

// Structured logging
developer.log(
  'Processing chat message',
  name: 'ChatProvider',
  error: error,
  stackTrace: stackTrace,
);
```

**Widget Inspection:**
```dart
// Wrap widget with debug info
debugPrint('Building MessageBubble');

// Check widget tree
print(widget.toStringDeep());
```

## Troubleshooting

### Common Issues

#### Go Build Errors

**Issue:** `undefined: grpc.ClientConn`
```bash
# Solution: Install gRPC dependencies
cd backend/go
go get google.golang.org/grpc
go mod tidy
```

**Issue:** `cannot find package "github.com/neuronai/..."`
```bash
# Solution: Check go.mod module name
cat backend/go/go.mod
# Should be: module github.com/neuronai/backend/go
```

#### Python Import Errors

**Issue:** `ModuleNotFoundError: No module named 'neuronai'`
```bash
# Solution: Install in editable mode
cd backend/python
pip install -e ".[dev]"
# Or with uv:
uv pip install -e ".[dev]"
```

**Issue:** `ImportError: cannot import name 'ChatRequest'`
```bash
# Solution: Regenerate protobuf files
cd proto
python -m grpc_tools.protoc -I. \
    --python_out=../backend/python/src/neuronai/grpc \
    --grpc_python_out=../backend/python/src/neuronai/grpc \
    neuronai.proto
```

#### Flutter Build Errors

**Issue:** `Target kernel_snapshot failed`
```bash
# Solution: Clean and rebuild
cd frontend
flutter clean
flutter pub get
flutter build
```

**Issue:** `Connection refused` to backend
```bash
# Solution: Check backend is running
curl http://localhost:8080/health

# Check Android emulator uses 10.0.2.2 for localhost
# Update API base URL in Flutter code
```

#### Protocol Buffer Issues

**Issue:** Generated files out of sync
```bash
# Solution: Regenerate all protobuf files
cd proto

# Go
protoc --go_out=../backend/go/internal/grpc/pb \
       --go-grpc_out=../backend/go/internal/grpc/pb \
       neuronai.proto

# Python
python -m grpc_tools.protoc -I. \
       --python_out=../backend/python/src/neuronai/grpc \
       --grpc_python_out=../backend/python/src/neuronai/grpc \
       neuronai.proto
```

#### Docker Issues

**Issue:** `port already allocated`
```bash
# Solution: Find and stop conflicting container
docker ps
docker stop <container_id>
# Or use different ports in docker-compose.yml
```

**Issue:** Services can't communicate
```bash
# Solution: Check network
docker network ls
docker-compose down && docker-compose up -d
```

### Getting Help

1. **Check logs:**
   - Go: `go run cmd/gateway/main.go 2>&1 | tee gateway.log`
   - Python: `python main.py 2>&1 | tee python.log`
   - Flutter: `flutter run --verbose`

2. **Review documentation:**
   - [Go Documentation](docs/backend-go.md)
   - [Python Documentation](docs/backend-python.md)
   - [Flutter Documentation](docs/frontend.md)

3. **Check GitHub Issues:**
   - Search existing issues
   - Create new issue with:
     - Environment details
     - Steps to reproduce
     - Expected vs actual behavior
     - Relevant logs

4. **Community:**
   - Discord: [NeuronAI Discord](link)
   - Stack Overflow: Tag with `neuronai`

## Performance Optimization

### Go Optimization

- Use `sync.Pool` for object reuse
- Profile with `go tool pprof`
- Enable HTTP/2 for better performance
- Use connection pooling for gRPC

### Python Optimization

- Use `asyncio` for concurrent operations
- Profile with `cProfile` or `py-spy`
- Cache expensive computations
- Use `uvloop` for better async performance

### Flutter Optimization

- Use `const` constructors
- Implement `ListView.builder` for long lists
- Use `RepaintBoundary` for complex widgets
- Profile with Flutter DevTools

## Security Best Practices

1. **Never commit secrets** - Use environment variables
2. **Validate all inputs** - Sanitize user data
3. **Use HTTPS** - In production, always
4. **Rate limiting** - Prevent abuse
5. **CORS configuration** - Restrict origins
6. **Dependency updates** - Keep packages updated
7. **Security scanning** - Run `safety` for Python, `gosec` for Go

## Additional Resources

- [Effective Go](https://golang.org/doc/effective_go.html)
- [Python Type Hints](https://docs.python.org/3/library/typing.html)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Flutter Best Practices](https://docs.flutter.dev/perf/best-practices)
- [gRPC Documentation](https://grpc.io/docs/)
- [Protocol Buffers Guide](https://developers.google.com/protocol-buffers)
