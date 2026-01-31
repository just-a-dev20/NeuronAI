# Multi-stage build for Go service
FROM golang:1.22-alpine AS go-builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY backend/go/go.mod backend/go/go.sum ./
RUN go mod download

# Copy source code
COPY backend/go/ .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gateway ./cmd/gateway

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=go-builder /app/gateway .

# Expose port
EXPOSE 8080

# Run the binary
CMD ["./gateway"]
