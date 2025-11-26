package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/etamong/remote-midi-server/internal/auth"
	"github.com/etamong/remote-midi-server/internal/config"
	"github.com/etamong/remote-midi-server/internal/midi"
	"github.com/gorilla/websocket"
)

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

	token, ok := h.sessionManager.Login(loginReq.Password)
	if !ok {
		http.Error(w, "Invalid password", http.StatusUnauthorized)
		return
	}

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
	// Check authentication via cookie
	cookie, err := r.Cookie("session_token")
	if err != nil || !h.sessionManager.ValidateToken(cookie.Value) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Upgrade connection to WebSocket
	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}
	defer conn.Close()

	log.Printf("WebSocket client connected from %s", r.RemoteAddr)

	// Handle incoming messages
	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		var msg ButtonPressMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("Invalid message format: %v", err)
			continue
		}

		// Get current config
		cfg := h.configWatcher.Get()

		// Validate button index
		if msg.ButtonIndex < 0 || msg.ButtonIndex >= len(cfg.MIDI.Buttons) {
			log.Printf("Invalid button index: %d", msg.ButtonIndex)
			continue
		}

		// Send MIDI note
		button := cfg.MIDI.Buttons[msg.ButtonIndex]
		if err := h.midiClient.SendNote(button.Note, cfg.MIDI.Velocity, 100*time.Millisecond); err != nil {
			log.Printf("Failed to send MIDI note: %v", err)
			continue
		}

		log.Printf("Button %d pressed: note=%d label=%s", msg.ButtonIndex, button.Note, button.Label)

		// Send acknowledgment
		ack := map[string]interface{}{
			"status":      "ok",
			"buttonIndex": msg.ButtonIndex,
			"note":        button.Note,
		}
		if err := conn.WriteJSON(ack); err != nil {
			log.Printf("Failed to send acknowledgment: %v", err)
			break
		}
	}

	log.Printf("WebSocket client disconnected")
}
