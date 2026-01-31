# NeuronAI Documentation

Welcome to the NeuronAI documentation! This comprehensive guide covers everything you need to know about building, deploying, and using NeuronAI.

## Quick Links

- [Architecture Overview](architecture.md) - System design and component interactions
- [API Reference](api.md) - REST and WebSocket API documentation
- [Development Guide](development.md) - Setup, coding standards, and workflows
- [Deployment Guide](deployment.md) - Production deployment instructions
- [Backend Documentation](backend.md) - Go and Python service details
- [Frontend Documentation](frontend.md) - Flutter app development
- [Protocol Buffers](protobuf.md) - gRPC schema documentation

## Documentation Structure

```
docs/
├── README.md              # This file - documentation index
├── architecture.md        # System architecture and design
├── api.md                # API documentation (REST/WebSocket)
├── development.md        # Development setup and guidelines
├── deployment.md         # Deployment and operations
├── backend.md           # Backend services documentation
├── frontend.md          # Frontend documentation
└── protobuf.md          # Protocol buffer schemas
```

## Getting Started

### New to NeuronAI?

1. Start with the [Architecture Overview](architecture.md) to understand the system
2. Follow the [Development Guide](development.md) to set up your environment
3. Review the [API Reference](api.md) to understand the interfaces

### Ready to Deploy?

1. Read the [Deployment Guide](deployment.md) for production setup
2. Review [Backend Documentation](backend.md) for service configuration
3. Check [Frontend Documentation](frontend.md) for app deployment

### Contributing?

1. Review the [Development Guide](development.md) for coding standards
2. Understand the [Protocol Buffers](protobuf.md) for API changes
3. Follow the testing guidelines in each component doc

## Overview

NeuronAI is a multi-platform AI assistant application with:

- **Cross-platform frontend** - Flutter (Android, iPad, Linux)
- **High-performance gateway** - Go (API, WebSocket, gRPC)
- **AI processing service** - Python (LLM integration, multi-agent swarm)
- **Real-time communication** - WebSocket and gRPC streaming
- **Modern infrastructure** - Docker, Supabase, CI/CD

## Key Features

- 🤖 Multi-agent AI swarm orchestration
- 💬 Real-time chat with streaming responses
- 📱 Cross-platform mobile and desktop support
- 🔒 JWT-based authentication
- 📎 File attachments (images, videos, documents)
- 🎨 Markdown and code syntax highlighting
- 🌐 REST and WebSocket APIs
- 🚀 Production-ready deployment

## Documentation Highlights

### Architecture
- System overview and component interactions
- Data flow diagrams
- Technology stack decisions
- Scalability considerations

### API Documentation
- Complete REST endpoint reference
- WebSocket protocol specification
- gRPC service definitions
- Authentication and error handling
- Code examples in multiple languages

### Development Guide
- Prerequisites and setup instructions
- Code standards (Go, Python, Flutter)
- Testing strategies
- Debugging techniques
- Troubleshooting common issues

### Deployment Guide
- Docker and Docker Compose setup
- Cloud deployment (AWS, GCP, Azure)
- SSL/TLS configuration
- Monitoring and logging
- Backup and recovery procedures

### Backend Documentation
- Go API Gateway implementation
- Python AI Service architecture
- gRPC communication patterns
- Database models and Supabase integration
- Performance optimization

### Frontend Documentation
- Flutter app architecture
- State management with Provider
- UI component documentation
- Platform-specific considerations
- Testing and building

### Protocol Buffers
- Complete schema reference
- Code generation instructions
- Best practices and versioning
- Service definitions

## Quick Commands

```bash
# Start development environment
docker-compose up -d

# Run all tests
./scripts/test-all.sh

# Build for production
./scripts/build-production.sh

# Deploy to production
./scripts/deploy.sh
```

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/neuronai/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/neuronai/discussions)
- **Documentation**: You're reading it! 📚

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**Last Updated**: January 2024  
**Version**: 1.0.0  
**Maintainers**: NeuronAI Team
