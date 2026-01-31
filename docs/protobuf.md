# NeuronAI Protocol Buffer Documentation

## Overview

NeuronAI uses Protocol Buffers (protobuf) for communication between the Go API Gateway and Python AI Service via gRPC.

## Schema Definition

**File:** `proto/neuronai.proto`

```protobuf
syntax = "proto3";

package neuronai;

option go_package = "github.com/neuronai/backend/go/internal/grpc/pb";

import "google/protobuf/timestamp.proto";
```

## Enums

### AgentType

Defines the types of AI agents available in the system.

```protobuf
enum AgentType {
  AGENT_TYPE_UNSPECIFIED = 0;   // Default/unknown agent
  AGENT_TYPE_ORCHESTRATOR = 1;  // Task coordinator
  AGENT_TYPE_RESEARCHER = 2;    // Information gathering
  AGENT_TYPE_WRITER = 3;        // Content creation
  AGENT_TYPE_CODE = 4;          // Programming tasks
  AGENT_TYPE_IMAGE = 5;         // Image generation
  AGENT_TYPE_VIDEO = 6;         // Video processing
}
```

**Usage:**
- `ORCHESTRATOR` - Coordinates multi-agent tasks
- `RESEARCHER` - Searches and analyzes information
- `WRITER` - Generates text content
- `CODE` - Handles programming queries
- `IMAGE` - Generates or processes images
- `VIDEO` - Processes or generates video

### MessageType

Defines the types of messages that can be exchanged.

```protobuf
enum MessageType {
  MESSAGE_TYPE_UNSPECIFIED = 0;    // Default/unknown type
  MESSAGE_TYPE_TEXT = 1;           // Plain text
  MESSAGE_TYPE_IMAGE = 2;          // Image content
  MESSAGE_TYPE_VIDEO = 3;          // Video content
  MESSAGE_TYPE_CODE = 4;           // Code snippet
  MESSAGE_TYPE_TOOL_CALL = 5;      // Tool invocation
  MESSAGE_TYPE_TOOL_RESULT = 6;    // Tool output
}
```

### TaskStatus

Defines the status of a task in the swarm.

```protobuf
enum TaskStatus {
  TASK_STATUS_UNSPECIFIED = 0;   // Unknown status
  TASK_STATUS_PENDING = 1;       // Waiting to start
  TASK_STATUS_IN_PROGRESS = 2;   // Currently executing
  TASK_STATUS_COMPLETED = 3;     // Successfully finished
  TASK_STATUS_FAILED = 4;        // Error occurred
  TASK_STATUS_CANCELLED = 5;     // Manually cancelled
}
```

## Messages

### ChatRequest

Request message for chat interactions.

```protobuf
message ChatRequest {
  string session_id = 1;                    // Conversation identifier
  string user_id = 2;                       // User identifier
  string content = 3;                       // Message content
  MessageType message_type = 4;             // Type of message
  repeated Attachment attachments = 5;      // File attachments
  map<string, string> metadata = 6;         // Additional context
}
```

**Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `session_id` | string | Yes | Unique conversation identifier (UUID) |
| `user_id` | string | Yes | User identifier from JWT token |
| `content` | string | Yes | Message text content |
| `message_type` | MessageType | No | Type: TEXT, IMAGE, CODE, etc. |
| `attachments` | Attachment[] | No | Files attached to message |
| `metadata` | map<string,string> | No | Custom key-value pairs |

**Example:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user-123",
  "content": "Explain quantum computing",
  "message_type": "TEXT",
  "metadata": {
    "source": "mobile_app",
    "language": "en"
  }
}
```

### ChatResponse

Response message from AI service.

```protobuf
message ChatResponse {
  string message_id = 1;                    // Unique message ID
  string session_id = 2;                    // Conversation ID
  string content = 3;                       // Response content
  MessageType message_type = 4;             // Response type
  AgentType agent_type = 5;                 // Agent that generated response
  TaskStatus status = 6;                    // Processing status
  google.protobuf.Timestamp timestamp = 7;  // Response time
  bool is_final = 8;                        // Final chunk flag
  repeated ToolCall tool_calls = 9;         // Tool invocations
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `message_id` | string | Unique identifier for this response |
| `session_id` | string | Conversation identifier |
| `content` | string | AI-generated response text |
| `message_type` | MessageType | Type of response content |
| `agent_type` | AgentType | Which agent generated this |
| `status` | TaskStatus | Current processing status |
| `timestamp` | Timestamp | When response was generated |
| `is_final` | bool | True if this is the final chunk |
| `tool_calls` | ToolCall[] | Any tools invoked during processing |

**Example:**
```json
{
  "message_id": "msg-456",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "content": "Quantum computing uses quantum bits...",
  "message_type": "TEXT",
  "agent_type": "RESEARCHER",
  "status": "COMPLETED",
  "timestamp": "2024-01-15T10:30:05Z",
  "is_final": true,
  "tool_calls": []
}
```

### Attachment

File attachment for messages.

```protobuf
message Attachment {
  string id = 1;           // Unique attachment ID
  string filename = 2;     // Original filename
  string mime_type = 3;    // MIME type (e.g., "image/png")
  bytes data = 4;          // Binary content (for small files)
  string url = 5;          // Storage URL (for large files)
}
```

**Usage Notes:**
- Use `data` for files < 1MB
- Use `url` for larger files stored in Supabase/S3
- Common MIME types: `image/png`, `image/jpeg`, `application/pdf`, `text/plain`

### ToolCall

Represents a tool invocation by an agent.

```protobuf
message ToolCall {
  string id = 1;           // Unique call ID
  string name = 2;         // Tool name (e.g., "search", "calculator")
  string arguments = 3;    // JSON-encoded arguments
  string result = 4;       // Tool output
}
```

**Example:**
```json
{
  "id": "call-789",
  "name": "web_search",
  "arguments": "{\"query\": \"quantum computing basics\"}",
  "result": "Found 5 relevant results..."
}
```

### SwarmTask

Task definition for multi-agent coordination.

```protobuf
message SwarmTask {
  string task_id = 1;                       // Unique task ID
  string session_id = 2;                    // Session context
  string description = 3;                   // Task description
  repeated string required_agents = 4;      // Required agent types
  map<string, string> context = 5;          // Shared context
  TaskStatus status = 6;                    // Current status
  google.protobuf.Timestamp created_at = 7; // Creation time
  google.protobuf.Timestamp updated_at = 8; // Last update time
}
```

**Usage:**
- Orchestrator creates tasks for complex queries
- Multiple agents collaborate on task execution
- Status updates track progress

### SwarmState

Current state of the agent swarm.

```protobuf
message SwarmState {
  string session_id = 1;                    // Session identifier
  repeated AgentState agents = 2;           // All agent states
  SwarmTask current_task = 3;               // Active task
  map<string, string> shared_context = 4;   // Shared memory
}
```

### AgentState

Individual agent status.

```protobuf
message AgentState {
  string agent_id = 1;                 // Unique agent ID
  AgentType agent_type = 2;            // Agent type
  string status = 3;                   // Status string
  string current_task = 4;             // Task being processed
  map<string, string> memory = 5;      // Agent memory/context
}
```

### StreamRequest

Streaming request message.

```protobuf
message StreamRequest {
  string session_id = 1;     // Session identifier
  string user_id = 2;        // User identifier
  oneof payload {
    ChatRequest chat = 3;    // Chat message
    bytes audio_data = 4;    // Audio stream (future)
  }
}
```

**Note:** Uses `oneof` to support multiple payload types.

### StreamResponse

Streaming response message.

```protobuf
message StreamResponse {
  string session_id = 1;              // Session identifier
  oneof payload {
    ChatResponse chat = 2;            // Chat chunk
    bytes audio_data = 3;             // Audio response (future)
    SwarmState swarm_update = 4;      // Swarm state update
  }
  bool is_heartbeat = 5;              // Keepalive flag
}
```

**Streaming Behavior:**
- `chat` - Text chunks for streaming responses
- `swarm_update` - Agent coordination updates
- `is_heartbeat` - Connection keepalive (every 30s)

### GetSwarmStateRequest

Request to retrieve swarm state.

```protobuf
message GetSwarmStateRequest {
  string session_id = 1;    // Session to query
}
```

## Services

### AIService

Main AI processing service.

```protobuf
service AIService {
  // Single request-response chat
  rpc ProcessChat(ChatRequest) returns (ChatResponse);
  
  // Bidirectional streaming chat
  rpc ProcessStream(stream StreamRequest) returns (stream StreamResponse);
  
  // Execute multi-agent task
  rpc ExecuteSwarmTask(SwarmTask) returns (stream SwarmState);
}
```

#### ProcessChat

Simple request-response chat processing.

**Request:** `ChatRequest`
**Response:** `ChatResponse`

**Use Case:** Simple queries, short responses

**Example (Go client):**
```go
resp, err := client.ProcessChat(ctx, &pb.ChatRequest{
    SessionId: "session-123",
    UserId:    "user-456",
    Content:   "Hello",
    MessageType: pb.MessageType_MESSAGE_TYPE_TEXT,
})
```

#### ProcessStream

Bidirectional streaming for real-time chat.

**Request Stream:** `StreamRequest`
**Response Stream:** `StreamResponse`

**Use Case:** Long responses, real-time updates, voice (future)

**Example (Go client):**
```go
stream, err := client.ProcessStream(ctx)

// Send request
go func() {
    stream.Send(&pb.StreamRequest{
        SessionId: "session-123",
        Payload: &pb.StreamRequest_Chat{
            Chat: &pb.ChatRequest{Content: "Hello"},
        },
    })
    stream.CloseSend()
}()

// Receive responses
for {
    resp, err := stream.Recv()
    if err == io.EOF {
        break
    }
    fmt.Println(resp.GetChat().Content)
}
```

#### ExecuteSwarmTask

Execute complex tasks with multiple agents.

**Request:** `SwarmTask`
**Response Stream:** `SwarmState`

**Use Case:** Research, multi-step tasks, complex queries

**Example (Go client):**
```go
task := &pb.SwarmTask{
    TaskId:      "task-789",
    SessionId:   "session-123",
    Description: "Research quantum computing",
    RequiredAgents: []string{"RESEARCHER", "WRITER"},
}

stream, err := client.ExecuteSwarmTask(ctx, task)
for {
    state, err := stream.Recv()
    // Monitor agent progress
}
```

### SwarmOrchestrator

Agent coordination and management service.

```protobuf
service SwarmOrchestrator {
  // Register agent with swarm
  rpc RegisterAgent(AgentState) returns (AgentState);
  
  // Update swarm state
  rpc UpdateSwarmState(SwarmState) returns (SwarmState);
  
  // Get current swarm state
  rpc GetSwarmState(GetSwarmStateRequest) returns (SwarmState);
}
```

#### RegisterAgent

Register a new agent in the swarm.

**Request:** `AgentState`
**Response:** `AgentState` (with assigned ID)

#### UpdateSwarmState

Update the shared swarm state.

**Request:** `SwarmState`
**Response:** `SwarmState` (updated)

#### GetSwarmState

Retrieve current swarm state.

**Request:** `GetSwarmStateRequest`
**Response:** `SwarmState`

## Code Generation

### Go

Generate Go code from proto file:

```bash
cd proto
protoc \
    --go_out=../backend/go/internal/grpc/pb \
    --go-grpc_out=../backend/go/internal/grpc/pb \
    neuronai.proto
```

**Generated Files:**
- `neuronai.pb.go` - Message structs
- `neuronai_grpc.pb.go` - gRPC client/server interfaces

**Usage:**
```go
import pb "github.com/neuronai/backend/go/internal/grpc/pb"

// Create client
conn, _ := grpc.Dial("localhost:50051", grpc.WithInsecure())
client := pb.NewAIServiceClient(conn)

// Make request
resp, _ := client.ProcessChat(ctx, &pb.ChatRequest{
    Content: "Hello",
})
```

### Python

Generate Python code from proto file:

```bash
cd proto
python -m grpc_tools.protoc \
    -I. \
    --python_out=../backend/python/src/neuronai/grpc \
    --grpc_python_out=../backend/python/src/neuronai/grpc \
    neuronai.proto
```

**Generated Files:**
- `neuronai_pb2.py` - Message classes
- `neuronai_pb2_grpc.py` - gRPC servicer and stub

**Usage:**
```python
from neuronai.grpc import neuronai_pb2, neuronai_pb2_grpc

class AIServiceServicer(neuronai_pb2_grpc.AIServiceServicer):
    async def ProcessChat(self, request, context):
        # Process request
        return neuronai_pb2.ChatResponse(
            content="Response",
            status=neuronai_pb2.TaskStatus.TASK_STATUS_COMPLETED
        )

# Start server
server = grpc.aio.server()
neuronai_pb2_grpc.add_AIServiceServicer_to_server(
    AIServiceServicer(), server
)
```

## Best Practices

### 1. Field Numbers

- Never reuse field numbers
- Reserve deleted field numbers
- Use 1-15 for frequently set fields (1 byte encoding)

### 2. Backward Compatibility

- Never change field numbers
- Never change field types
- Only add optional fields
- Use `reserved` for deleted fields

```protobuf
message Example {
  reserved 2, 15, 9 to 11;
  reserved "foo", "bar";
  
  string name = 1;
  int32 id = 3;  // Skipped 2 (reserved)
}
```

### 3. Default Values

- Numeric: `0`
- String: `""`
- Bool: `false`
- Enum: first value (0)
- Message: not set

### 4. Validation

Always validate required fields:

```go
if request.SessionId == "" {
    return nil, status.Error(codes.InvalidArgument, "session_id required")
}
```

### 5. Timestamps

Use `google.protobuf.Timestamp` for time fields:

```protobuf
import "google/protobuf/timestamp.proto";

google.protobuf.Timestamp created_at = 1;
```

## Versioning

Current schema version: **v1.0.0**

**Version History:**
- v1.0.0 (2024-01-15) - Initial schema

**Future Changes:**
- Add voice/audio support
- Add file upload streaming
- Add agent marketplace

## Additional Resources

- [Protocol Buffers Guide](https://developers.google.com/protocol-buffers)
- [gRPC Documentation](https://grpc.io/docs/)
- [Protobuf Style Guide](https://developers.google.com/protocol-buffers/docs/style)
- [Language Guide (proto3)](https://developers.google.com/protocol-buffers/docs/proto3)
