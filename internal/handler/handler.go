package handler

import (
	"encoding/json"
	"log"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/etamong/remote-midi-server/internal/auth"
	"github.com/etamong/remote-midi-server/internal/config"
	"github.com/etamong/remote-midi-server/internal/midi"
	"github.com/gorilla/websocket"
)

// getClientIP extracts the real client IP from the request
func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header (for proxied requests)
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		ips := strings.Split(xff, ",")
		if len(ips) > 0 {
			return strings.TrimSpace(ips[0])
		}
	}

	// Check X-Real-IP header
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}

	// Fall back to RemoteAddr
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return ip
}

type Handler struct {
	configWatcher  *config.Watcher
	midiClient     *midi.Client
	sessionManager *auth.SessionManager
	upgrader       websocket.Upgrader
}

type ButtonPressMessage struct {
	ButtonIndex int `json:"buttonIndex"`
}

type ConfigResponse struct {
	Buttons []config.ButtonConfig `json:"buttons"`
}

func New(configWatcher *config.Watcher, midiClient *midi.Client, sessionManager *auth.SessionManager) *Handler {
	return &Handler{
		configWatcher:  configWatcher,
		midiClient:     midiClient,
		sessionManager: sessionManager,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				// Allow all origins for simplicity
				// In production, you might want to check the origin
				return true
			},
		},
	}
}

func (h *Handler) HandleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var loginReq struct {
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&loginReq); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	clientIP := getClientIP(r)
	token, ok := h.sessionManager.Login(loginReq.Password)
	if !ok {
		log.Printf("[%s] Login failed: invalid password", clientIP)
		http.Error(w, "Invalid password", http.StatusUnauthorized)
		return
	}

	log.Printf("[%s] Login successful", clientIP)

	// Set session cookie
	http.SetCookie(w, &http.Cookie{
		Name:     "session_token",
		Value:    token,
		Path:     "/",
		MaxAge:   86400, // 24 hours
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
	})

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (h *Handler) HandleLogout(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("session_token")
	if err == nil {
		h.sessionManager.Logout(cookie.Value)
	}

	http.SetCookie(w, &http.Cookie{
		Name:   "session_token",
		Value:  "",
		Path:   "/",
		MaxAge: -1,
	})

	http.Redirect(w, r, "/login.html", http.StatusFound)
}

func (h *Handler) HandleConfig(w http.ResponseWriter, r *http.Request) {
	cfg := h.configWatcher.Get()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ConfigResponse{
		Buttons: cfg.MIDI.Buttons,
	})
}

func (h *Handler) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	clientIP := getClientIP(r)

	// Check authentication via cookie
	cookie, err := r.Cookie("session_token")
	if err != nil || !h.sessionManager.ValidateToken(cookie.Value) {
		log.Printf("[%s] WebSocket unauthorized", clientIP)
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Upgrade connection to WebSocket
	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[%s] WebSocket upgrade error: %v", clientIP, err)
		return
	}
	defer conn.Close()

	log.Printf("[%s] WebSocket connected", clientIP)

	// Handle incoming messages
	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[%s] WebSocket error: %v", clientIP, err)
			}
			break
		}

		var msg ButtonPressMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("[%s] Invalid message format: %v", clientIP, err)
			continue
		}

		// Get current config
		cfg := h.configWatcher.Get()

		// Validate button index
		if msg.ButtonIndex < 0 || msg.ButtonIndex >= len(cfg.MIDI.Buttons) {
			log.Printf("[%s] Invalid button index: %d", clientIP, msg.ButtonIndex)
			continue
		}

		// Send MIDI note
		button := cfg.MIDI.Buttons[msg.ButtonIndex]
		velocity := button.GetVelocity(cfg.MIDI.Velocity)
		if err := h.midiClient.SendNote(button.Note, velocity, 100*time.Millisecond); err != nil {
			log.Printf("[%s] Failed to send MIDI note: %v", clientIP, err)
			continue
		}

		log.Printf("[%s] Button %d pressed: note=%d velocity=%d label=%s", clientIP, msg.ButtonIndex, button.Note, velocity, button.Label)

		// Send acknowledgment
		ack := map[string]interface{}{
			"status":      "ok",
			"buttonIndex": msg.ButtonIndex,
			"note":        button.Note,
		}
		if err := conn.WriteJSON(ack); err != nil {
			log.Printf("[%s] Failed to send acknowledgment: %v", clientIP, err)
			break
		}
	}

	log.Printf("[%s] WebSocket disconnected", clientIP)
}
