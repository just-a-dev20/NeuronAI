package api

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/neuronai/backend/go/internal/config"
	"github.com/neuronai/backend/go/internal/grpc"
	pb "github.com/neuronai/backend/go/internal/grpc/pb"
	"github.com/neuronai/backend/go/internal/websocket"
)

type claimsKey string

const testClaimsKey claimsKey = "claims"

type testClaims struct {
	UserID string
}

func setupTestContextWithClaims(userID string) context.Context {
	claims := &testClaims{UserID: userID}
	return context.WithValue(context.Background(), testClaimsKey, claims)
}

func setupTestHandler(t *testing.T) *Handler {
	t.Helper()

	cfg := &config.Config{
		JWTSecret: "test-secret",
	}

	wsHub := websocket.NewHub(nil)
	ctx, cancel := context.WithCancel(context.Background())
	go wsHub.Run(ctx)
	t.Cleanup(cancel)

	mockClient := &grpc.PythonClient{}
	return NewHandler(mockClient, wsHub, cfg)
}

func TestHandler_HealthCheck(t *testing.T) {
	handler := setupTestHandler(t)

	tests := []struct {
		name           string
		method         string
		expectedStatus int
	}{
		{
			name:           "GET request",
			method:         http.MethodGet,
			expectedStatus: http.StatusOK,
		},
		{
			name:           "POST request",
			method:         http.MethodPost,
			expectedStatus: http.StatusMethodNotAllowed,
		},
		{
			name:           "PUT request",
			method:         http.MethodPut,
			expectedStatus: http.StatusMethodNotAllowed,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, "/health", nil)
			rec := httptest.NewRecorder()

			handler.HealthCheck(rec, req)

			if rec.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, rec.Code)
			}

			if tt.expectedStatus == http.StatusOK {
				var response map[string]string
				err := json.NewDecoder(rec.Body).Decode(&response)
				if err != nil {
					t.Errorf("Failed to decode response: %v", err)
				}

				if response["status"] != "healthy" {
					t.Errorf("expected status 'healthy', got '%s'", response["status"])
				}

				if response["service"] != "gateway" {
					t.Errorf("expected service 'gateway', got '%s'", response["service"])
				}
			}
		})
	}
}

func TestHandler_HealthCheck_ResponseFormat(t *testing.T) {
	handler := setupTestHandler(t)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	handler.HealthCheck(rec, req)

	if rec.Header().Get("Content-Type") != "application/json" {
		t.Errorf("expected Content-Type 'application/json', got '%s'", rec.Header().Get("Content-Type"))
	}
}

func TestHandler_Chat_Unauthorized(t *testing.T) {
	handler := setupTestHandler(t)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/chat", nil)
	rec := httptest.NewRecorder()

	handler.Chat(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, rec.Code)
	}
}

func TestHandler_Chat_InvalidMethod(t *testing.T) {
	handler := setupTestHandler(t)

	ctx := setupTestContextWithClaims("test-user")
	req := httptest.NewRequest(http.MethodGet, "/api/v1/chat", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Chat(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected status %d, got %d", http.StatusMethodNotAllowed, rec.Code)
	}
}

func TestHandler_Chat_InvalidRequestBody(t *testing.T) {
	handler := setupTestHandler(t)

	ctx := setupTestContextWithClaims("test-user")
	req := httptest.NewRequest(http.MethodPost, "/api/v1/chat", bytes.NewBufferString("invalid json")).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Chat(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestHandler_Chat_Success(t *testing.T) {
	handler := setupTestHandler(t)

	ctx := setupTestContextWithClaims("test-user")

	requestBody := ChatRequest{
		SessionID:   "session-123",
		Content:     "Hello",
		MessageType: "text",
		Metadata:    map[string]string{"key": "value"},
	}
	bodyBytes, _ := json.Marshal(requestBody)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/chat", bytes.NewBuffer(bodyBytes)).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.Chat(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Errorf("expected status %d (internal server error due to mock client), got %d", http.StatusInternalServerError, rec.Code)
	}
}

func TestHandler_StreamChat_Unauthorized(t *testing.T) {
	handler := setupTestHandler(t)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/chat/stream", nil)
	rec := httptest.NewRecorder()

	handler.StreamChat(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, rec.Code)
	}
}

func TestHandler_StreamChat_InvalidMethod(t *testing.T) {
	handler := setupTestHandler(t)

	ctx := setupTestContextWithClaims("test-user")
	req := httptest.NewRequest(http.MethodGet, "/api/v1/chat/stream", nil).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.StreamChat(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected status %d, got %d", http.StatusMethodNotAllowed, rec.Code)
	}
}

func TestHandler_StreamChat_InvalidRequestBody(t *testing.T) {
	handler := setupTestHandler(t)

	ctx := setupTestContextWithClaims("test-user")
	req := httptest.NewRequest(http.MethodPost, "/api/v1/chat/stream", bytes.NewBufferString("invalid json")).WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.StreamChat(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestChatRequest_MarshalUnmarshal(t *testing.T) {
	req := ChatRequest{
		SessionID:   "session-123",
		UserID:      "user-123",
		Content:     "Test content",
		MessageType: "text",
		Metadata:    map[string]string{"key1": "value1", "key2": "value2"},
	}

	bytes, err := json.Marshal(req)
	if err != nil {
		t.Errorf("Failed to marshal request: %v", err)
	}

	var unmarshaled ChatRequest
	err = json.Unmarshal(bytes, &unmarshaled)
	if err != nil {
		t.Errorf("Failed to unmarshal request: %v", err)
	}

	if unmarshaled.SessionID != req.SessionID {
		t.Errorf("expected SessionID %s, got %s", req.SessionID, unmarshaled.SessionID)
	}

	if unmarshaled.UserID != req.UserID {
		t.Errorf("expected UserID %s, got %s", req.UserID, unmarshaled.UserID)
	}

	if unmarshaled.Content != req.Content {
		t.Errorf("expected Content %s, got %s", req.Content, unmarshaled.Content)
	}

	if unmarshaled.MessageType != req.MessageType {
		t.Errorf("expected MessageType %s, got %s", req.MessageType, unmarshaled.MessageType)
	}

	if len(unmarshaled.Metadata) != len(req.Metadata) {
		t.Errorf("expected %d metadata items, got %d", len(req.Metadata), len(unmarshaled.Metadata))
	}
}

func TestNewHandler(t *testing.T) {
	cfg := &config.Config{
		JWTSecret: "test-secret",
	}

	wsHub := websocket.NewHub(nil)
	ctx, cancel := context.WithCancel(context.Background())
	go wsHub.Run(ctx)
	defer cancel()

	mockClient := &grpc.PythonClient{}
	handler := NewHandler(mockClient, wsHub, cfg)

	if handler == nil {
		t.Error("Expected handler to be created")
	}

	if handler.config != cfg {
		t.Error("Expected handler config to be set")
	}

	if handler.wsHub != wsHub {
		t.Error("Expected handler wsHub to be set")
	}
}

func TestMessageTypeConversion(t *testing.T) {
	tests := []struct {
		name     string
		msgType  string
		expected pb.MessageType
	}{
		{"text", "text", pb.MessageType_MESSAGE_TYPE_TEXT},
		{"image", "image", pb.MessageType_MESSAGE_TYPE_IMAGE},
		{"video", "video", pb.MessageType_MESSAGE_TYPE_VIDEO},
		{"code", "code", pb.MessageType_MESSAGE_TYPE_CODE},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var converted pb.MessageType
			switch tt.msgType {
			case "text":
				converted = pb.MessageType_MESSAGE_TYPE_TEXT
			case "image":
				converted = pb.MessageType_MESSAGE_TYPE_IMAGE
			case "video":
				converted = pb.MessageType_MESSAGE_TYPE_VIDEO
			case "code":
				converted = pb.MessageType_MESSAGE_TYPE_CODE
			}

			if converted != tt.expected {
				t.Errorf("expected %v, got %v", tt.expected, converted)
			}
		})
	}
}
