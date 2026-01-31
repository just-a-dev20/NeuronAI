package grpc

import (
	"context"
	"fmt"
	"io"

	pb "github.com/neuronai/backend/go/internal/grpc/pb"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type PythonClient struct {
	conn   *grpc.ClientConn
	client pb.AIServiceClient
}

type StreamClient struct {
	stream pb.AIService_ProcessStreamClient
}

func NewPythonClient(addr string) (*PythonClient, error) {
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Python service: %w", err)
	}

	return &PythonClient{
		conn:   conn,
		client: pb.NewAIServiceClient(conn),
	}, nil
}

func (c *PythonClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

func (c *PythonClient) ProcessChat(ctx context.Context, req *ChatRequest) (*ChatResponse, error) {
	pbReq := &pb.ChatRequest{
		SessionId: req.SessionID,
		UserId:    req.UserID,
		Content:   req.Content,
		Metadata:  req.Metadata,
	}

	if req.MessageType != "" {
		switch req.MessageType {
		case "text":
			pbReq.MessageType = pb.MessageType_MESSAGE_TYPE_TEXT
		case "image":
			pbReq.MessageType = pb.MessageType_MESSAGE_TYPE_IMAGE
		case "video":
			pbReq.MessageType = pb.MessageType_MESSAGE_TYPE_VIDEO
		case "code":
			pbReq.MessageType = pb.MessageType_MESSAGE_TYPE_CODE
		}
	}

	resp, err := c.client.ProcessChat(ctx, pbReq)
	if err != nil {
		return nil, fmt.Errorf("failed to process chat: %w", err)
	}

	return &ChatResponse{
		MessageID: resp.MessageId,
		SessionID: resp.SessionId,
		Content:   resp.Content,
		AgentType: resp.AgentType.String(),
		Status:    resp.Status.String(),
		IsFinal:   resp.IsFinal,
	}, nil
}

func (c *PythonClient) ProcessStream(ctx context.Context, req *pb.ChatRequest) (*StreamClient, error) {
	stream, err := c.client.ProcessStream(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to start stream: %w", err)
	}

	if err := stream.Send(&pb.StreamRequest{
		SessionId: req.SessionId,
		UserId:    req.UserId,
		Payload: &pb.StreamRequest_Chat{
			Chat: req,
		},
	}); err != nil {
		return nil, fmt.Errorf("failed to send initial request: %w", err)
	}

	return &StreamClient{stream: stream}, nil
}

func (s *StreamClient) Recv() (*pb.ChatResponse, error) {
	resp, err := s.stream.Recv()
	if err != nil {
		if err == io.EOF {
			return nil, err
		}
		return nil, fmt.Errorf("stream receive error: %w", err)
	}

	return resp.GetChat(), nil
}

func (s *StreamClient) Close() error {
	return s.stream.CloseSend()
}

type ChatRequest struct {
	SessionID   string
	UserID      string
	Content     string
	MessageType string
	Metadata    map[string]string
}

type ChatResponse struct {
	MessageID string
	SessionID string
	Content   string
	AgentType string
	Status    string
	IsFinal   bool
}
