package websocket

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/neuronai/backend/go/internal/grpc"
	pb "github.com/neuronai/backend/go/internal/grpc/pb"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 512 * 1024
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type Client struct {
	hub       *Hub
	conn      *websocket.Conn
	send      chan []byte
	userID    string
	sessionID string
}

type Hub struct {
	clients      map[*Client]bool
	broadcast    chan []byte
	register     chan *Client
	unregister   chan *Client
	pythonClient *grpc.PythonClient
	mu           sync.RWMutex
}

func NewHub(pythonClient *grpc.PythonClient) *Hub {
	return &Hub{
		clients:      make(map[*Client]bool),
		broadcast:    make(chan []byte),
		register:     make(chan *Client),
		unregister:   make(chan *Client),
		pythonClient: pythonClient,
	}
}

func (h *Hub) Run(ctx context.Context) {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mu.Unlock()

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.RUnlock()

		case <-ctx.Done():
			return
		}
	}
}

func (h *Hub) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	sessionID := r.URL.Query().Get("session_id")

	if userID == "" || sessionID == "" {
		http.Error(w, "Missing user_id or session_id", http.StatusBadRequest)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	client := &Client{
		hub:       h,
		conn:      conn,
		send:      make(chan []byte, 256),
		userID:    userID,
		sessionID: sessionID,
	}

	client.hub.register <- client

	go client.writePump()
	go client.readPump()
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		var req pb.ChatRequest
		if err := json.Unmarshal(message, &req); err != nil {
			log.Printf("Failed to unmarshal message: %v", err)
			continue
		}

		req.UserId = c.userID
		req.SessionId = c.sessionID

		go c.handleMessage(&req)
	}
}

func (c *Client) handleMessage(req *pb.ChatRequest) {
	stream, err := c.hub.pythonClient.ProcessStream(context.Background(), req)
	if err != nil {
		log.Printf("Failed to process stream: %v", err)
		return
	}
	defer stream.Close()

	for {
		resp, err := stream.Recv()
		if err != nil {
			return
		}

		data, err := json.Marshal(resp)
		if err != nil {
			log.Printf("Failed to marshal response: %v", err)
			continue
		}

		c.send <- data
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
