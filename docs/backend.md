# NeuronAI Backend Documentation

## Overview

The NeuronAI backend consists of two microservices:

1. **Go API Gateway** - HTTP/WebSocket server and gRPC client
2. **Python AI Service** - gRPC server with LLM integration

## Go API Gateway

### Architecture

```
cmd/gateway/
└── main.go              # Application entry point

internal/
├── api/
│   └── handler.go       # HTTP handlers
├── config/
│   └── config.go        # Configuration management
├── grpc/
│   ├── client.go        # gRPC client
│   └── pb/             # Generated protobuf files
├── middleware/
│   └── auth.go          # JWT authentication
└── websocket/
    └── hub.go           # WebSocket hub
```

### Key Components

#### Main Entry Point (`cmd/gateway/main.go`)

- Loads configuration
- Initializes gRPC client
- Sets up WebSocket hub
- Configures HTTP routes
- Handles graceful shutdown

#### HTTP Handlers (`internal/api/handler.go`)

**Endpoints:**
- `GET /health` - Health check
- `POST /api/v1/chat` - Send chat message
- `POST /api/v1/chat/stream` - Stream chat response
- `GET /ws` - WebSocket upgrade

**Handler Structure:**
```go
type Handler struct {
    pythonClient *grpc.PythonClient
    wsHub        *websocket.Hub
    config       *config.Config
    logger       *zap.Logger
}

func NewHandler(pc *grpc.PythonClient, ws *websocket.Hub, cfg *config.Config) *Handler {
    return &Handler{
        pythonClient: pc,
        wsHub:        ws,
        config:       cfg,
        logger:       zap.NewProduction(),
    }
}
```

#### WebSocket Hub (`internal/websocket/hub.go`)

Manages WebSocket connections:
- Client registration/deregistration
- Message broadcasting
- Heartbeat mechanism
- Connection pooling

```go
type Hub struct {
    clients    map[*Client]bool
    broadcast  chan []byte
    register   chan *Client
    unregister chan *Client
    python     *grpc.PythonClient
}

func (h *Hub) Run(ctx context.Context) {
    for {
        select {
        case client := <-h.register:
            h.clients[client] = true
        case client := <-h.unregister:
            delete(h.clients, client)
        case message := <-h.broadcast:
            for client := range h.clients {
                select {
                case client.send <- message:
                default:
                    close(client.send)
                    delete(h.clients, client)
                }
            }
        }
    }
}
```

#### gRPC Client (`internal/grpc/client.go`)

Connects to Python AI service:
- Connection pooling
- Request forwarding
- Streaming support
- Error handling

```go
type PythonClient struct {
    conn   *grpc.ClientConn
    client pb.AIServiceClient
}

func NewPythonClient(addr string) (*PythonClient, error) {
    conn, err := grpc.Dial(addr, grpc.WithInsecure())
    if err != nil {
        return nil, err
    }
    
    return &PythonClient{
        conn:   conn,
        client: pb.NewAIServiceClient(conn),
    }, nil
}

func (c *PythonClient) ProcessChat(ctx context.Context, req *pb.ChatRequest) (*pb.ChatResponse, error) {
    return c.client.ProcessChat(ctx, req)
}
```

#### JWT Middleware (`internal/middleware/auth.go`)

Validates JWT tokens:
- Extracts token from header
- Validates signature
- Sets user context
- Returns 401 for invalid tokens

```go
func JWTAuth(secret string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            token := extractToken(r)
            if token == "" {
                http.Error(w, "Unauthorized", http.StatusUnauthorized)
                return
            }
            
            claims, err := validateToken(token, secret)
            if err != nil {
                http.Error(w, "Invalid token", http.StatusUnauthorized)
                return
            }
            
            ctx := context.WithValue(r.Context(), "user", claims)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

#### Configuration (`internal/config/config.go`)

Environment-based configuration:

```go
type Config struct {
    Port             int    `env:"PORT" envDefault:"8080"`
    PythonServiceAddr string `env:"PYTHON_SERVICE_ADDR" envDefault:"localhost:50051"`
    JWTSecret        string `env:"JWT_SECRET"`
    SupabaseURL      string `env:"SUPABASE_URL"`
    SupabaseKey      string `env:"SUPABASE_KEY"`
    LogLevel         string `env:"LOG_LEVEL" envDefault:"info"`
}

func Load() (*Config, error) {
    var cfg Config
    if err := env.Parse(&cfg); err != nil {
        return nil, err
    }
    return &cfg, nil
}
```

### Testing

**Unit Tests:**
```bash
cd backend/go
go test ./internal/api/... -v
go test ./internal/middleware/... -v
go test ./internal/websocket/... -v
```

**Integration Tests:**
```bash
# Start dependencies
docker-compose up -d

# Run integration tests
go test ./... -tags=integration
```

### Building

```bash
cd backend/go

# Development
go build ./cmd/gateway

# Production (optimized)
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gateway ./cmd/gateway

# Docker
docker build -t neuronai/gateway:latest .
```

---

## Python AI Service

### Architecture

```
main.py                  # Entry point

src/neuronai/
├── __init__.py
├── config/
│   └── settings.py      # Configuration
├── grpc/
│   ├── server.py        # gRPC server
│   ├── neuronai_pb2.py      # Generated protobuf
│   └── neuronai_pb2_grpc.py # Generated gRPC
├── agents/
│   └── orchestrator.py  # Agent coordination
├── models/
│   └── database.py      # Data models
└── api/
    └── auth.py          # JWT validation
```

### Key Components

#### gRPC Server (`src/neuronai/grpc/server.py`)

Implements AIService and SwarmOrchestrator:

```python
import asyncio
import grpc
from concurrent import futures

from neuronai.grpc import neuronai_pb2, neuronai_pb2_grpc
from neuronai.agents.orchestrator import Orchestrator
from neuronai.config.settings import Settings

class AIServiceServicer(neuronai_pb2_grpc.AIServiceServicer):
    def __init__(self):
        self.orchestrator = Orchestrator()
        self.settings = Settings()
    
    async def ProcessChat(
        self, 
        request: neuronai_pb2.ChatRequest, 
        context: grpc.ServicerContext
    ) -> neuronai_pb2.ChatResponse:
        """Process a chat message."""
        try:
            result = await self.orchestrator.process_chat(request)
            return self._build_response(result)
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            raise
    
    async def ProcessStream(
        self, 
        request_iterator, 
        context: grpc.ServicerContext
    ):
        """Process streaming requests."""
        async for request in request_iterator:
            async for chunk in self.orchestrator.stream_chat(request):
                yield self._build_stream_response(chunk)

async def serve():
    server = grpc.aio.server(futures.ThreadPoolExecutor(max_workers=10))
    neuronai_pb2_grpc.add_AIServiceServicer_to_server(AIServiceServicer(), server)
    
    server.add_insecure_port('[::]:50051')
    await server.start()
    print("gRPC server started on port 50051")
    
    await server.wait_for_termination()

if __name__ == '__main__':
    asyncio.run(serve())
```

#### Agent Orchestrator (`src/neuronai/agents/orchestrator.py`)

Coordinates multiple AI agents:

```python
from typing import List, Dict, Any
from enum import Enum

class AgentType(Enum):
    ORCHESTRATOR = "orchestrator"
    RESEARCHER = "researcher"
    WRITER = "writer"
    CODE = "code"
    IMAGE = "image"

class Orchestrator:
    def __init__(self):
        self.agents: Dict[AgentType, BaseAgent] = {
            AgentType.RESEARCHER: ResearcherAgent(),
            AgentType.WRITER: WriterAgent(),
            AgentType.CODE: CodeAgent(),
            AgentType.IMAGE: ImageAgent(),
        }
        self.llm_client = LLMClient()
    
    async def process_chat(self, request) -> Dict[str, Any]:
        """Process chat request through appropriate agents."""
        # Determine required agents based on content
        required_agents = self._determine_agents(request.content)
        
        # Execute agent pipeline
        context = {"request": request}
        for agent_type in required_agents:
            agent = self.agents[agent_type]
            result = await agent.execute(context)
            context[agent_type.value] = result
        
        # Generate final response
        response = await self._generate_response(context)
        return response
    
    async def stream_chat(self, request):
        """Stream chat response in chunks."""
        async for chunk in self.llm_client.stream_completion(request.content):
            yield {
                "chunk": chunk,
                "is_final": False
            }
        
        yield {
            "chunk": "",
            "is_final": True
        }
    
    def _determine_agents(self, content: str) -> List[AgentType]:
        """Determine which agents are needed."""
        agents = [AgentType.ORCHESTRATOR]
        
        if self._is_research_query(content):
            agents.append(AgentType.RESEARCHER)
        
        if self._is_code_query(content):
            agents.append(AgentType.CODE)
        
        if self._is_image_query(content):
            agents.append(AgentType.IMAGE)
        
        agents.append(AgentType.WRITER)
        return agents
```

#### Configuration (`src/neuronai/config/settings.py`)

Pydantic-based configuration:

```python
from pydantic_settings import BaseSettings
from pydantic import Field

class Settings(BaseSettings):
    """Application settings loaded from environment."""
    
    # Service
    port: int = Field(default=50051, alias="PORT")
    log_level: str = Field(default="info", alias="LOG_LEVEL")
    
    # Security
    jwt_secret: str = Field(alias="JWT_SECRET")
    
    # Database
    supabase_url: str = Field(alias="SUPABASE_URL")
    supabase_key: str = Field(alias="SUPABASE_KEY")
    
    # LLM APIs
    openai_api_key: str | None = Field(default=None, alias="OPENAI_API_KEY")
    claude_api_key: str | None = Field(default=None, alias="CLAUDE_API_KEY")
    default_llm_provider: str = Field(default="openai", alias="DEFAULT_LLM_PROVIDER")
    
    class Config:
        env_file = ".env"
        case_sensitive = False

settings = Settings()
```

#### Database Models (`src/neuronai/models/database.py`)

Pydantic models for Supabase:

```python
from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field

class Conversation(BaseModel):
    """Conversation model."""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    title: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class Message(BaseModel):
    """Message model."""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    conversation_id: str
    user_id: str
    content: str
    message_type: str = "text"
    agent_type: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class DatabaseClient:
    """Supabase database client."""
    
    def __init__(self, url: str, key: str):
        from supabase import create_client
        self.client = create_client(url, key)
    
    async def create_conversation(self, user_id: str, title: str) -> Conversation:
        """Create new conversation."""
        conversation = Conversation(user_id=user_id, title=title)
        result = self.client.table("conversations").insert(conversation.dict()).execute()
        return Conversation(**result.data[0])
    
    async def add_message(self, message: Message) -> Message:
        """Add message to conversation."""
        result = self.client.table("messages").insert(message.dict()).execute()
        return Message(**result.data[0])
    
    async def get_conversation_messages(
        self, 
        conversation_id: str
    ) -> List[Message]:
        """Get all messages in conversation."""
        result = self.client.table("messages")\
            .select("*")\
            .eq("conversation_id", conversation_id)\
            .order("created_at")\
            .execute()
        return [Message(**msg) for msg in result.data]
```

#### JWT Validation (`src/neuronai/api/auth.py`)

Token validation utilities:

```python
import jwt
from datetime import datetime
from typing import Dict, Any

class JWTValidator:
    """JWT token validator."""
    
    def __init__(self, secret: str):
        self.secret = secret
    
    def validate(self, token: str) -> Dict[str, Any]:
        """Validate JWT token and return claims."""
        try:
            claims = jwt.decode(
                token, 
                self.secret, 
                algorithms=["HS256"]
            )
            
            # Check expiration
            exp = claims.get("exp")
            if exp and datetime.utcnow().timestamp() > exp:
                raise ValueError("Token expired")
            
            return claims
        except jwt.InvalidTokenError as e:
            raise ValueError(f"Invalid token: {e}")
    
    def get_user_id(self, token: str) -> str:
        """Extract user ID from token."""
        claims = self.validate(token)
        return claims.get("sub") or claims.get("user_id")
```

### Testing

**Unit Tests:**
```bash
cd backend/python

# Run all tests
pytest

# Run with coverage
pytest --cov=src/neuronai --cov-report=html

# Run specific test
pytest tests/test_orchestrator.py::test_process_chat -v
```

**Test Example:**
```python
import pytest
from unittest.mock import Mock, AsyncMock

@pytest.fixture
def orchestrator():
    return Orchestrator()

@pytest.mark.asyncio
async def test_process_chat_simple(orchestrator):
    request = Mock()
    request.content = "Hello"
    
    result = await orchestrator.process_chat(request)
    
    assert "content" in result
    assert result["status"] == "completed"

@pytest.mark.asyncio
async def test_stream_chat(orchestrator):
    request = Mock()
    request.content = "Test"
    
    chunks = []
    async for chunk in orchestrator.stream_chat(request):
        chunks.append(chunk)
    
    assert len(chunks) > 0
    assert chunks[-1]["is_final"] is True
```

### Building

```bash
cd backend/python

# Install dependencies
uv pip install -e ".[dev]"

# Run type checking
mypy src/

# Run linting
ruff check .
ruff format .

# Build Docker image
docker build -t neuronai/python:latest -f Dockerfile .
```

## Inter-Service Communication

### gRPC Flow

```
Flutter App
    ↓ HTTP/WebSocket
Go Gateway
    ↓ gRPC
Python Service
    ↓ HTTP
LLM API (OpenAI/Claude)
```

### Protocol Buffer Schema

See [protobuf.md](protobuf.md) for complete schema documentation.

### Error Handling

**Go Gateway:**
```go
func (h *Handler) handleError(w http.ResponseWriter, err error, status int) {
    h.logger.Error("request failed", zap.Error(err))
    
    response := map[string]interface{}{
        "error": map[string]string{
            "code":    fmt.Sprintf("ERR_%d", status),
            "message": err.Error(),
        },
    }
    
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(response)
}
```

**Python Service:**
```python
async def ProcessChat(self, request, context):
    try:
        result = await self.orchestrator.process_chat(request)
        return result
    except ValueError as e:
        context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
        context.set_details(str(e))
        raise
    except Exception as e:
        logger.error("Processing failed", error=str(e))
        context.set_code(grpc.StatusCode.INTERNAL)
        context.set_details("Internal processing error")
        raise
```

## Performance Optimization

### Go Gateway

- Use connection pooling for gRPC
- Implement request timeouts
- Enable HTTP/2
- Use goroutines for concurrent processing

### Python Service

- Use `asyncio` for I/O operations
- Implement caching for LLM responses
- Use connection pooling for database
- Profile with `py-spy`

## Security Considerations

1. **JWT Validation** - Validate on both services
2. **Input Sanitization** - Sanitize all user inputs
3. **Rate Limiting** - Implement at gateway level
4. **Secrets Management** - Use environment variables
5. **Network Security** - Use internal networks for gRPC
6. **Logging** - Don't log sensitive data

## Deployment

See [deployment.md](deployment.md) for detailed deployment instructions.

## API Reference

See [api.md](api.md) for complete API documentation.
