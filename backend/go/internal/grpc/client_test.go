package grpc

import (
	"context"
	"net"
	"testing"
	"time"

	pb "github.com/neuronai/backend/go/internal/grpc/pb"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/test/bufconn"
)

const bufSize = 1024 * 1024

type mockAIService struct {
	pb.UnimplementedAIServiceServer
}

func (m *mockAIService) ProcessChat(ctx context.Context, req *pb.ChatRequest) (*pb.ChatResponse, error) {
	return &pb.ChatResponse{
		MessageId: "test-message-id",
		SessionId: req.SessionId,
		Content:   "Test response",
		AgentType: pb.AgentType_AGENT_TYPE_ORCHESTRATOR,
		Status:    pb.TaskStatus_TASK_STATUS_COMPLETED,
		IsFinal:   true,
	}, nil
}

func (m *mockAIService) ExecuteSwarmTask(req *pb.SwarmTask, stream pb.AIService_ExecuteSwarmTaskServer) error {
	stream.Send(&pb.SwarmState{
		SessionId: req.SessionId,
	})
	return nil
}

func (m *mockAIService) ProcessStream(stream pb.AIService_ProcessStreamServer) error {
	for {
		req, err := stream.Recv()
		if err != nil {
			return err
		}

		resp := &pb.StreamResponse{
			SessionId: req.SessionId,
			Payload: &pb.StreamResponse_Chat{
				Chat: &pb.ChatResponse{
					MessageId: "stream-message-id",
					SessionId: req.GetChat().SessionId,
					Content:   "Stream response",
					AgentType: pb.AgentType_AGENT_TYPE_ORCHESTRATOR,
					Status:    pb.TaskStatus_TASK_STATUS_COMPLETED,
					IsFinal:   true,
				},
			},
		}

		if err := stream.Send(resp); err != nil {
			return err
		}
	}
}

func setupMockServer(t *testing.T, lis *bufconn.Listener) *grpc.Server {
	t.Helper()

	s := grpc.NewServer()
	pb.RegisterAIServiceServer(s, &mockAIService{})
	go func() {
		if err := s.Serve(lis); err != nil {
			t.Errorf("Server error: %v", err)
		}
	}()

	return s
}

func dialer(lis *bufconn.Listener) func(context.Context, string) (net.Conn, error) {
	return func(context.Context, string) (net.Conn, error) {
		return lis.Dial()
	}
}

func TestNewPythonClient_Connection(t *testing.T) {
	lis := bufconn.Listen(bufSize)
	s := setupMockServer(t, lis)
	defer s.Stop()

	conn, err := grpc.NewClient("passthrough://bufnet",
		grpc.WithContextDialer(dialer(lis)),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("Failed to dial mock server: %v", err)
	}
	defer conn.Close()

	client := &PythonClient{
		conn:   conn,
		client: pb.NewAIServiceClient(conn),
	}

	if client.client == nil {
		t.Error("Expected gRPC client to be initialized")
	}
}

func TestPythonClient_Close(t *testing.T) {
	lis := bufconn.Listen(bufSize)
	s := setupMockServer(t, lis)
	defer s.Stop()

	conn, err := grpc.NewClient("passthrough://bufnet",
		grpc.WithContextDialer(dialer(lis)),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("Failed to dial mock server: %v", err)
	}

	client := &PythonClient{
		conn:   conn,
		client: pb.NewAIServiceClient(conn),
	}

	err = client.Close()
	if err != nil {
		t.Errorf("Expected no error closing client, got: %v", err)
	}

	err = client.Close()
	if err != nil {
		t.Logf("Error closing already closed client: %v (this is expected)", err)
	}
}

func TestPythonClient_ProcessChat(t *testing.T) {
	lis := bufconn.Listen(bufSize)
	s := setupMockServer(t, lis)
	defer s.Stop()

	conn, err := grpc.NewClient("passthrough://bufnet",
		grpc.WithContextDialer(dialer(lis)),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("Failed to dial mock server: %v", err)
	}
	defer conn.Close()

	client := &PythonClient{
		conn:   conn,
		client: pb.NewAIServiceClient(conn),
	}

	tests := []struct {
		name          string
		req           *ChatRequest
		wantErr       bool
		wantContent   string
		wantAgentType string
	}{
		{
			name: "successful chat request",
			req: &ChatRequest{
				SessionID:   "session-123",
				UserID:      "user-123",
				Content:     "Hello",
				MessageType: "text",
				Metadata:    map[string]string{"key": "value"},
			},
			wantErr:       false,
			wantContent:   "Test response",
			wantAgentType: "AGENT_TYPE_ORCHESTRATOR",
		},
		{
			name: "chat request with image type",
			req: &ChatRequest{
				SessionID:   "session-123",
				UserID:      "user-123",
				Content:     "Describe this image",
				MessageType: "image",
			},
			wantErr:       false,
			wantContent:   "Test response",
			wantAgentType: "AGENT_TYPE_ORCHESTRATOR",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			resp, err := client.ProcessChat(ctx, tt.req)
			if (err != nil) != tt.wantErr {
				t.Errorf("ProcessChat() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				if resp.Content != tt.wantContent {
					t.Errorf("Expected content %s, got %s", tt.wantContent, resp.Content)
				}
				if resp.AgentType != tt.wantAgentType {
					t.Errorf("Expected agent type %s, got %s", tt.wantAgentType, resp.AgentType)
				}
			}
		})
	}
}

func TestPythonClient_ProcessStream(t *testing.T) {
	lis := bufconn.Listen(bufSize)
	s := setupMockServer(t, lis)
	defer s.Stop()

	conn, err := grpc.NewClient("passthrough://bufnet",
		grpc.WithContextDialer(dialer(lis)),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("Failed to dial mock server: %v", err)
	}
	defer conn.Close()

	client := &PythonClient{
		conn:   conn,
		client: pb.NewAIServiceClient(conn),
	}

	t.Run("successful stream", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		pbReq := &pb.ChatRequest{
			SessionId: "session-123",
			UserId:    "user-123",
			Content:   "Hello",
		}

		streamClient, err := client.ProcessStream(ctx, pbReq)
		if err != nil {
			t.Fatalf("Failed to start stream: %v", err)
		}
		defer streamClient.Close()

		msg, err := streamClient.Recv()
		if err != nil {
			t.Fatalf("Failed to receive message: %v", err)
		}

		if msg.Content != "Stream response" {
			t.Errorf("Expected content 'Stream response', got %s", msg.Content)
		}

		streamClient.Close()
	})
}

func TestStreamClient_Recv(t *testing.T) {
	lis := bufconn.Listen(bufSize)
	s := setupMockServer(t, lis)
	defer s.Stop()

	conn, err := grpc.NewClient("passthrough://bufnet",
		grpc.WithContextDialer(dialer(lis)),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("Failed to dial mock server: %v", err)
	}
	defer conn.Close()

	client := &PythonClient{
		conn:   conn,
		client: pb.NewAIServiceClient(conn),
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	pbReq := &pb.ChatRequest{
		SessionId: "session-123",
		UserId:    "user-123",
		Content:   "Hello",
	}

	streamClient, err := client.ProcessStream(ctx, pbReq)
	if err != nil {
		t.Fatalf("Failed to start stream: %v", err)
	}
	defer streamClient.Close()

	msg, err := streamClient.Recv()
	if err != nil {
		t.Fatalf("Failed to receive message: %v", err)
	}

	if msg == nil {
		t.Fatal("Expected non-nil message")
	}

	if msg.Content == "" {
		t.Error("Expected non-empty content")
	}
}

func TestMessageTypeConversion(t *testing.T) {
	lis := bufconn.Listen(bufSize)
	s := setupMockServer(t, lis)
	defer s.Stop()

	conn, err := grpc.NewClient("passthrough://bufnet",
		grpc.WithContextDialer(dialer(lis)),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("Failed to dial mock server: %v", err)
	}
	defer conn.Close()

	client := &PythonClient{
		conn:   conn,
		client: pb.NewAIServiceClient(conn),
	}

	tests := []struct {
		name    string
		msgType string
	}{
		{"text message", "text"},
		{"image message", "image"},
		{"video message", "video"},
		{"code message", "code"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			req := &ChatRequest{
				SessionID:   "session-123",
				UserID:      "user-123",
				Content:     "Test",
				MessageType: tt.msgType,
			}

			_, err := client.ProcessChat(ctx, req)
			if err != nil {
				t.Errorf("ProcessChat() error = %v", err)
			}
		})
	}
}
