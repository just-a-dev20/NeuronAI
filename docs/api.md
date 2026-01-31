# NeuronAI API Documentation

## Base URL

```
Development: http://localhost:8080
Production: https://api.neuronai.app
```

## Authentication

All API requests (except `/health`) require a valid JWT token in the Authorization header:

```
Authorization: Bearer <jwt_token>
```

Tokens are obtained through Supabase Authentication.

## REST Endpoints

### Health Check

Check if the API gateway is running.

**Endpoint:** `GET /health`

**Authentication:** None

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0"
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `503 Service Unavailable` - Service is down

---

### Send Chat Message

Send a message to the AI assistant.

**Endpoint:** `POST /api/v1/chat`

**Authentication:** Required

**Request Body:**
```json
{
  "session_id": "uuid-string",
  "content": "Hello, how can you help me?",
  "message_type": "text",
  "attachments": [
    {
      "filename": "document.pdf",
      "mime_type": "application/pdf",
      "data": "base64-encoded-data"
    }
  ],
  "metadata": {
    "source": "mobile_app",
    "language": "en"
  }
}
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `session_id` | string | Yes | Unique conversation identifier |
| `content` | string | Yes | Message content |
| `message_type` | string | No | Type: `text`, `image`, `video`, `code` (default: `text`) |
| `attachments` | array | No | File attachments |
| `metadata` | object | No | Additional context |

**Response:**
```json
{
  "message_id": "uuid-string",
  "session_id": "uuid-string",
  "content": "I can help you with various tasks...",
  "message_type": "text",
  "agent_type": "orchestrator",
  "status": "completed",
  "timestamp": "2024-01-15T10:30:05Z",
  "is_final": true,
  "tool_calls": []
}
```

**Status Codes:**
- `200 OK` - Message processed successfully
- `400 Bad Request` - Invalid request body
- `401 Unauthorized` - Missing or invalid token
- `500 Internal Server Error` - Server error

---

### Stream Chat Message

Send a message and receive a streaming response.

**Endpoint:** `POST /api/v1/chat/stream`

**Authentication:** Required

**Request Body:** Same as `/api/v1/chat`

**Response:** Server-Sent Events (SSE) stream

```
data: {"chunk": "Hello", "is_final": false}

data: {"chunk": " there", "is_final": false}

data: {"chunk": "!", "is_final": true}
```

**Event Format:**
```json
{
  "chunk": "string",
  "is_final": boolean,
  "message_id": "uuid-string",
  "agent_type": "orchestrator"
}
```

**Status Codes:**
- `200 OK` - Stream started
- `401 Unauthorized` - Missing or invalid token

---

## WebSocket API

Connect to WebSocket for real-time bidirectional communication.

**Endpoint:** `ws://localhost:8080/ws`

**Authentication:** JWT token in query parameter
```
ws://localhost:8080/ws?token=<jwt_token>
```

### Connection

**Client → Server:**
```json
{
  "type": "auth",
  "token": "jwt_token"
}
```

### Send Message

**Client → Server:**
```json
{
  "type": "chat",
  "payload": {
    "session_id": "uuid-string",
    "content": "Hello!",
    "message_type": "text"
  }
}
```

### Receive Message

**Server → Client:**
```json
{
  "type": "chat_response",
  "payload": {
    "message_id": "uuid-string",
    "content": "Response text",
    "agent_type": "orchestrator",
    "is_final": true,
    "timestamp": "2024-01-15T10:30:05Z"
  }
}
```

### Stream Chunks

**Server → Client:**
```json
{
  "type": "stream_chunk",
  "payload": {
    "chunk": "partial text",
    "is_final": false,
    "message_id": "uuid-string"
  }
}
```

### Heartbeat

**Server → Client:**
```json
{
  "type": "heartbeat",
  "timestamp": "2024-01-15T10:30:10Z"
}
```

### Error Messages

**Server → Client:**
```json
{
  "type": "error",
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Authentication failed"
  }
}
```

**Error Codes:**
| Code | Description |
|------|-------------|
| `INVALID_TOKEN` | JWT token is invalid or expired |
| `RATE_LIMITED` | Too many requests |
| `AGENT_ERROR` | AI processing error |
| `TIMEOUT` | Request timed out |

---

## gRPC Services

Internal communication between Go gateway and Python service.

### AIService

```protobuf
service AIService {
  rpc ProcessChat(ChatRequest) returns (ChatResponse);
  rpc ProcessStream(stream StreamRequest) returns (stream StreamResponse);
  rpc ExecuteSwarmTask(SwarmTask) returns (stream SwarmState);
}
```

### SwarmOrchestrator

```protobuf
service SwarmOrchestrator {
  rpc RegisterAgent(AgentState) returns (AgentState);
  rpc UpdateSwarmState(SwarmState) returns (SwarmState);
  rpc GetSwarmState(GetSwarmStateRequest) returns (SwarmState);
}
```

---

## Data Models

### Message Types

```typescript
enum MessageType {
  TEXT = "text",
  IMAGE = "image",
  VIDEO = "video",
  CODE = "code",
  TOOL_CALL = "tool_call",
  TOOL_RESULT = "tool_result"
}
```

### Agent Types

```typescript
enum AgentType {
  ORCHESTRATOR = "orchestrator",
  RESEARCHER = "researcher",
  WRITER = "writer",
  CODE = "code",
  IMAGE = "image",
  VIDEO = "video"
}
```

### Task Status

```typescript
enum TaskStatus {
  PENDING = "pending",
  IN_PROGRESS = "in_progress",
  COMPLETED = "completed",
  FAILED = "failed",
  CANCELLED = "cancelled"
}
```

### ChatRequest

```typescript
interface ChatRequest {
  session_id: string;
  user_id: string;
  content: string;
  message_type: MessageType;
  attachments: Attachment[];
  metadata: Record<string, string>;
}
```

### ChatResponse

```typescript
interface ChatResponse {
  message_id: string;
  session_id: string;
  content: string;
  message_type: MessageType;
  agent_type: AgentType;
  status: TaskStatus;
  timestamp: string; // ISO 8601
  is_final: boolean;
  tool_calls: ToolCall[];
}
```

### Attachment

```typescript
interface Attachment {
  id: string;
  filename: string;
  mime_type: string;
  data?: string; // base64
  url?: string;
}
```

### ToolCall

```typescript
interface ToolCall {
  id: string;
  name: string;
  arguments: string; // JSON string
  result?: string;
}
```

---

## Error Handling

### HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| `200` | OK | Successful request |
| `400` | Bad Request | Invalid input data |
| `401` | Unauthorized | Missing/invalid token |
| `403` | Forbidden | Insufficient permissions |
| `404` | Not Found | Resource not found |
| `429` | Too Many Requests | Rate limit exceeded |
| `500` | Internal Server Error | Server error |
| `503` | Service Unavailable | Service temporarily down |

### Error Response Format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "content",
      "issue": "required"
    }
  }
}
```

---

## Rate Limiting

Rate limits are applied per user:

- **REST API**: 100 requests per minute
- **WebSocket**: 10 messages per second
- **Streaming**: 1 concurrent stream per session

**Rate Limit Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705315800
```

---

## SDK Examples

### cURL

```bash
# Health check
curl http://localhost:8080/health

# Send chat message
curl -X POST http://localhost:8080/api/v1/chat \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "123e4567-e89b-12d3-a456-426614174000",
    "content": "Hello!",
    "message_type": "text"
  }'
```

### JavaScript/TypeScript

```typescript
// Using fetch
const response = await fetch('http://localhost:8080/api/v1/chat', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    session_id: sessionId,
    content: 'Hello!',
    message_type: 'text'
  })
});

const data = await response.json();
```

### Python

```python
import requests

response = requests.post(
    'http://localhost:8080/api/v1/chat',
    headers={'Authorization': f'Bearer {token}'},
    json={
        'session_id': session_id,
        'content': 'Hello!',
        'message_type': 'text'
    }
)

data = response.json()
```

---

## WebSocket Client Example

### JavaScript

```javascript
const ws = new WebSocket('ws://localhost:8080/ws?token=YOUR_JWT_TOKEN');

ws.onopen = () => {
  console.log('Connected');
  
  // Send a message
  ws.send(JSON.stringify({
    type: 'chat',
    payload: {
      session_id: 'uuid-string',
      content: 'Hello!',
      message_type: 'text'
    }
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Received:', data);
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};

ws.onclose = () => {
  console.log('Disconnected');
};
```

### Dart (Flutter)

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

final wsUrl = Uri.parse('ws://localhost:8080/ws?token=$token');
final channel = WebSocketChannel.connect(wsUrl);

// Send message
channel.sink.add(jsonEncode({
  'type': 'chat',
  'payload': {
    'session_id': sessionId,
    'content': 'Hello!',
    'message_type': 'text'
  }
}));

// Listen for messages
channel.stream.listen(
  (message) {
    final data = jsonDecode(message);
    print('Received: $data');
  },
  onError: (error) => print('Error: $error'),
  onDone: () => print('Connection closed'),
);
```

---

## Versioning

API versioning follows semantic versioning:

- Current version: `v1`
- Version is part of URL path: `/api/v1/`
- Breaking changes will increment version

## Changelog

### v1.0.0 (2024-01-15)
- Initial API release
- REST endpoints for chat
- WebSocket support
- JWT authentication
- Streaming responses
