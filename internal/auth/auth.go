package auth

import (
	"crypto/rand"
	"encoding/base64"
	"net/http"
	"sync"
	"time"
)

type SessionManager struct {
	password string
	sessions map[string]time.Time
	mu       sync.RWMutex
}

func NewSessionManager(password string) *SessionManager {
	sm := &SessionManager{
		password: password,
		sessions: make(map[string]time.Time),
	}

	// Clean up expired sessions every hour
	go sm.cleanupExpiredSessions()

	return sm
}

func (sm *SessionManager) Login(password string) (string, bool) {
	if password != sm.password {
		return "", false
	}

	// Generate session token
	token := sm.generateToken()
	sm.mu.Lock()
	sm.sessions[token] = time.Now().Add(24 * time.Hour) // 24 hour expiry
	sm.mu.Unlock()

	return token, true
}

func (sm *SessionManager) ValidateToken(token string) bool {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	expiry, exists := sm.sessions[token]
	if !exists {
		return false
	}

	return time.Now().Before(expiry)
}

func (sm *SessionManager) Logout(token string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	delete(sm.sessions, token)
}

func (sm *SessionManager) generateToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)
}

func (sm *SessionManager) cleanupExpiredSessions() {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for range ticker.C {
		sm.mu.Lock()
		for token, expiry := range sm.sessions {
			if time.Now().After(expiry) {
				delete(sm.sessions, token)
			}
		}
		sm.mu.Unlock()
	}
}

// Middleware to check authentication
func (sm *SessionManager) RequireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Check for session cookie
		cookie, err := r.Cookie("session_token")
		if err != nil || !sm.ValidateToken(cookie.Value) {
			http.Redirect(w, r, "/login.html", http.StatusFound)
			return
		}

		next(w, r)
	}
}
