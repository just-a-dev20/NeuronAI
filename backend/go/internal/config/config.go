package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	Port              int
	PythonServiceAddr string
	JWTSecret         string
	Environment       string
	MaxRequestSize    int64
}

func Load() (*Config, error) {
	port, err := strconv.Atoi(getEnv("PORT", "8080"))
	if err != nil {
		return nil, fmt.Errorf("invalid PORT: %w", err)
	}

	maxSize, err := strconv.ParseInt(getEnv("MAX_REQUEST_SIZE", "10485760"), 10, 64)
	if err != nil {
		return nil, fmt.Errorf("invalid MAX_REQUEST_SIZE: %w", err)
	}

	jwtSecret := getEnv("JWT_SECRET", "")
	if jwtSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}

	return &Config{
		Port:              port,
		PythonServiceAddr: getEnv("PYTHON_SERVICE_ADDR", "localhost:50051"),
		JWTSecret:         jwtSecret,
		Environment:       getEnv("ENVIRONMENT", "development"),
		MaxRequestSize:    maxSize,
	}, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
