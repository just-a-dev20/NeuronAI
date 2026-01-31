package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestJWTAuth(t *testing.T) {
	secret := "test-secret-key"

	tests := []struct {
		name           string
		authHeader     string
		expectedStatus int
	}{
		{
			name:           "missing authorization header",
			authHeader:     "",
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "invalid authorization header format",
			authHeader:     "InvalidFormat token123",
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "invalid bearer format",
			authHeader:     "Basic token123",
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "invalid token",
			authHeader:     "Bearer invalid-token",
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "valid token",
			authHeader:     generateValidToken(t, secret),
			expectedStatus: http.StatusOK,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := JWTAuth(secret)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
			}))

			req := httptest.NewRequest(http.MethodGet, "/", nil)
			if tt.authHeader != "" {
				req.Header.Set("Authorization", tt.authHeader)
			}
			rec := httptest.NewRecorder()

			handler.ServeHTTP(rec, req)

			if rec.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, rec.Code)
			}
		})
	}
}

func TestJWTAuth_ContextClaims(t *testing.T) {
	secret := "test-secret-key"
	userID := "user-123"
	email := "test@example.com"

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, Claims{
		UserID: userID,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
		},
	})
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatal(err)
	}

	handler := JWTAuth(secret)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := GetClaims(r.Context())
		if !ok {
			http.Error(w, "No claims found", http.StatusInternalServerError)
			return
		}

		if claims.UserID != userID {
			t.Errorf("expected user_id %s, got %s", userID, claims.UserID)
		}

		if claims.Email != email {
			t.Errorf("expected email %s, got %s", email, claims.Email)
		}

		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+tokenString)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, rec.Code)
	}
}

func TestCORS(t *testing.T) {
	handler := CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

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
			expectedStatus: http.StatusOK,
		},
		{
			name:           "OPTIONS request",
			method:         http.MethodOptions,
			expectedStatus: http.StatusNoContent,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, "/", nil)
			rec := httptest.NewRecorder()

			handler.ServeHTTP(rec, req)

			if rec.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, rec.Code)
			}

			if rec.Header().Get("Access-Control-Allow-Origin") != "*" {
				t.Error("expected Access-Control-Allow-Origin header to be *")
			}

			expectedMethods := "GET, POST, PUT, DELETE, OPTIONS"
			if rec.Header().Get("Access-Control-Allow-Methods") != expectedMethods {
				t.Errorf("expected Access-Control-Allow-Methods %s, got %s", expectedMethods, rec.Header().Get("Access-Control-Allow-Methods"))
			}
		})
	}
}

func TestRequestLogger(t *testing.T) {
	handler := RequestLogger(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test/path", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, rec.Code)
	}
}

func TestGetClaims(t *testing.T) {
	tests := []struct {
		name     string
		ctx      context.Context
		wantOK   bool
		wantUser string
	}{
		{
			name:     "context without claims",
			ctx:      context.Background(),
			wantOK:   false,
			wantUser: "",
		},
		{
			name: "context with claims",
			ctx: context.WithValue(context.Background(), claimsContextKey, &Claims{
				UserID: "user-123",
				Email:  "test@example.com",
			}),
			wantOK:   true,
			wantUser: "user-123",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			claims, ok := GetClaims(tt.ctx)
			if ok != tt.wantOK {
				t.Errorf("expected ok %v, got %v", tt.wantOK, ok)
			}
			if ok && claims.UserID != tt.wantUser {
				t.Errorf("expected user_id %s, got %s", tt.wantUser, claims.UserID)
			}
		})
	}
}

func generateValidToken(t *testing.T, secret string) string {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, Claims{
		UserID: "test-user",
		Email:  "test@example.com",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
		},
	})
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("Failed to sign token: %v", err)
	}
	return "Bearer " + tokenString
}
