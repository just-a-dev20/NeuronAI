# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the NeuronAI project.

## What is an ADR?

An Architecture Decision Record (ADR) is a document that describes a significant architectural decision made for a project. Each ADR captures:
- The context of the decision
- The decision itself
- The consequences and trade-offs of the decision

## ADR Template

```markdown
# [Title]

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
What is the issue that we're seeing that is motivating this decision or change?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult to do because of this change?
```

## ADRs

### ADR-001: Microservices Architecture

**Status:** Accepted

**Context:**
The NeuronAI project requires:
- Separate services for different concerns (API Gateway, AI processing)
- Independent scaling of components
- Technology diversity (Go for gateway, Python for AI)
- Isolation of failures between components

**Decision:**
Implement a microservices architecture with three main services:
1. Go API Gateway - Handles HTTP/WebSocket routing and authentication
2. Python AI Service - Handles LLM interactions and agent orchestration
3. Flutter Frontend - Cross-platform client application

**Consequences:**
- **Positive:**
  - Independent deployment and scaling of services
  - Language specialization (Go for performance, Python for AI libraries)
  - Clear separation of concerns
  - Team can work on services independently
- **Negative:**
  - Increased deployment complexity
  - Network latency between services
  - Need for inter-service communication (gRPC)

### ADR-002: gRPC for Inter-Service Communication

**Status:** Accepted

**Context:**
Services need to communicate with each other efficiently. Options considered:
- REST API over HTTP
- gRPC over HTTP/2
- Message queue (RabbitMQ, Kafka)

**Decision:**
Use gRPC for inter-service communication between Go gateway and Python AI service.

**Consequences:**
- **Positive:**
  - Better performance with binary serialization
  - Built-in code generation from protobuf definitions
  - Streaming support out-of-the-box
  - Type safety across services
- **Negative:**
  - Learning curve for team
  - More complex debugging than REST
  - Less human-readable than JSON

### ADR-003: WebSocket for Real-Time Communication

**Status:** Accepted

**Context:**
AI responses need to be streamed to users in real-time. Options:
- Server-Sent Events (SSE)
- WebSocket
- Long polling

**Decision:**
Use WebSocket for bi-directional real-time communication between client and server.

**Consequences:**
- **Positive:**
  - Low latency for streaming responses
  - Bi-directional communication
  - Widely supported across browsers
  - Efficient for frequent message exchange
- **Negative:**
  - More complex connection management
  - Need for reconnection logic
  - Potential issues with some proxy servers

### ADR-004: Provider Pattern for State Management

**Status:** Accepted

**Context:**
Flutter application needs state management for authentication, chat sessions, settings. Options:
- setState (Flutter built-in)
- Provider
- Riverpod
- BLoC
- Redux

**Decision:**
Use Provider package for state management.

**Consequences:**
- **Positive:**
  - Official Flutter team recommendation
  - Simple and easy to understand
  - Good performance with Selector
  - Well-documented
  - No boilerplate compared to BLoC
- **Negative:**
  - Less powerful than Riverpod for complex state
  - Provider can be nested deep
  - May need additional packages for async state

### ADR-005: Supabase for Backend Services

**Status:** Accepted

**Context:**
Need managed backend services for:
- User authentication
- Database storage
- File storage
- Real-time subscriptions

Options:
- Firebase
- Supabase
- Custom implementation (PostgreSQL, S3, custom auth)

**Decision:**
Use Supabase as managed backend service provider.

**Consequences:**
- **Positive:**
  - Open-source and self-hostable
  - PostgreSQL under the hood (standard SQL)
  - Built-in authentication and authorization
  - Real-time subscriptions included
  - Good free tier for development
  - Single platform for multiple needs
- **Negative:**
  - Smaller community than Firebase
  - Newer than Firebase (potential stability concerns)
  - Documentation less comprehensive
  - Vendor lock-in concerns

### ADR-006: Swarm Agent Architecture

**Status:** Accepted

**Context:**
AI assistant needs to handle multiple types of tasks:
- General chat
- Code generation
- Research
- Image/Video processing

Options:
- Single monolithic agent with conditional logic
- Multiple specialized agents with orchestrator
- LLM routing (function calling)

**Decision:**
Implement swarm architecture with multiple specialized agents coordinated by an orchestrator.

**Consequences:**
- **Positive:**
  - Each agent can be optimized for its task
  - Easy to add new agent types
  - Better separation of concerns
  - Can work on complex tasks collaboratively
  - Clear role definition
- **Negative:**
  - Increased complexity in coordination
  - More moving parts to test
  - Performance overhead for agent communication
  - Need for state synchronization

### ADR-007: JWT Authentication

**Status:** Accepted

**Context:**
Need secure authentication for API access. Options:
- Session-based authentication
- JWT (JSON Web Token)
- OAuth 2.0
- API keys

**Decision:**
Use JWT for authentication with refresh token support.

**Consequences:**
- **Positive:**
  - Stateless (no server-side session storage)
  - Can be used across microservices
  - Standard and well-documented
  - Support for claims and expiration
  - Easy to implement in Go and Python
- **Negative:**
  - Token can be stolen (need HTTPS)
  - Revocation is challenging without database
  - Need to manage refresh tokens
  - Token size can be large with many claims

### ADR-008: Docker and Docker Compose

**Status:** Accepted

**Context:**
Need consistent development and deployment environments. Options:
- Manual setup on each machine
- Vagrant or similar VM tools
- Docker containers
- Kubernetes

**Decision:**
Use Docker for containerization and Docker Compose for local development and simple deployments.

**Consequences:**
- **Positive:**
  - Consistent environments across development, testing, production
  - Easy to onboard new developers
  - Simplifies dependency management
  - Can run multiple services easily
  - Good documentation (docker-compose.yml as environment spec)
- **Negative:**
  - Additional learning curve
  - Image size optimization required
  - Not ideal for complex production orchestration (use Kubernetes)

### ADR-009: Flutter Multi-Platform Target

**Status:** Accepted

**Context:**
Need to support multiple platforms. Options:
- Separate native apps (iOS, Android, Web, Desktop)
- React Native
- Flutter
- Electron + native mobile

**Decision:**
Use Flutter as the framework targeting:
- Android (primary mobile)
- Linux (primary desktop)
- iOS (future)
- Windows/macOS (future)

**Consequences:**
- **Positive:**
  - Single codebase for multiple platforms
  - Hot reload for fast development
  - Native performance and look-and-feel
  - Strong community and growing ecosystem
  - Good testing support
- **Negative:**
  - Smaller community than React Native
  - Some platform-specific features need platform channels
  - App size larger than native
  - Not all platform features supported equally
