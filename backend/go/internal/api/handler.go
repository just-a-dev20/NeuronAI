package api

import (
	"encoding/json"
	"net/http"

	"github.com/neuronai/backend/go/internal/config"
	"github.com/neuronai/backend/go/internal/grpc"
	pb "github.com/neuronai/backend/go/internal/grpc/pb"
	"github.com/neuronai/backend/go/internal/middleware"
	"github.com/neuronai/backend/go/internal/websocket"
)

type Handler struct {
	pythonClient *grpc.PythonClient
	wsHub        *websocket.Hub
	config       *config.Config
}

func NewHandler(pythonClient *grpc.PythonClient, wsHub *websocket.Hub, cfg *config.Config) *Handler {
	return &Handler{
		pythonClient: pythonClient,
		wsHub:        wsHub,
		config:       cfg,
	}
}

func (h *Handler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	response := map[string]string{
		"status":  "healthy",
		"service": "gateway",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *Handler) Chat(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := middleware.GetClaims(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req ChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	req.UserID = claims.UserID

	grpcReq := &grpc.ChatRequest{
		SessionID:   req.SessionID,
		UserID:      req.UserID,
		Content:     req.Content,
		MessageType: req.MessageType,
		Metadata:    req.Metadata,
	}

	resp, err := h.pythonClient.ProcessChat(r.Context(), grpcReq)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (h *Handler) StreamChat(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := middleware.GetClaims(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req ChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	req.UserID = claims.UserID

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

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

	stream, err := h.pythonClient.ProcessStream(r.Context(), pbReq)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer stream.Close()

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming not supported", http.StatusInternalServerError)
		return
	}

	for {
		msg, err := stream.Recv()
		if err != nil {
			return
		}

		data, _ := json.Marshal(msg)
		w.Write([]byte("data: "))
		w.Write(data)
		w.Write([]byte("\n\n"))
		flusher.Flush()
	}
}

type ChatRequest struct {
	SessionID   string            `json:"session_id"`
	UserID      string            `json:"user_id"`
	Content     string            `json:"content"`
	MessageType string            `json:"message_type"`
	Metadata    map[string]string `json:"metadata"`
}
