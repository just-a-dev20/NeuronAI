package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/neuronai/backend/go/internal/api"
	"github.com/neuronai/backend/go/internal/config"
	"github.com/neuronai/backend/go/internal/grpc"
	"github.com/neuronai/backend/go/internal/websocket"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	pythonClient, err := grpc.NewPythonClient(cfg.PythonServiceAddr)
	if err != nil {
		log.Fatalf("Failed to connect to Python service: %v", err)
	}
	defer pythonClient.Close()

	wsHub := websocket.NewHub(pythonClient)
	go wsHub.Run(ctx)

	apiHandler := api.NewHandler(pythonClient, wsHub, cfg)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", apiHandler.HealthCheck)
	mux.HandleFunc("/api/v1/chat", apiHandler.Chat)
	mux.HandleFunc("/api/v1/chat/stream", apiHandler.StreamChat)
	mux.HandleFunc("/ws", wsHub.HandleWebSocket)

	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		log.Printf("Starting server on port %d", cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	<-sigChan
	log.Println("Shutting down server...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("Server shutdown error: %v", err)
	}

	cancel()
	log.Println("Server stopped")
}
