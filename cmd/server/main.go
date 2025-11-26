package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/etamong/remote-midi-server/internal/auth"
	"github.com/etamong/remote-midi-server/internal/config"
	"github.com/etamong/remote-midi-server/internal/handler"
	"github.com/etamong/remote-midi-server/internal/midi"
)

func main() {
	configPath := flag.String("config", "config.yaml", "Path to configuration file")
	flag.Parse()

	// Load configuration
	cfg, err := config.Load(*configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	log.Printf("Starting Remote MIDI Server on port %d", cfg.Server.Port)
	log.Printf("MIDI Port: %s, Channel: %d", cfg.MIDI.PortName, cfg.MIDI.Channel)

	// Initialize MIDI client
	midiClient, err := midi.New(cfg.MIDI.PortName, cfg.MIDI.Channel)
	if err != nil {
		log.Fatalf("Failed to initialize MIDI client: %v", err)
	}
	defer midiClient.Close()

	// Initialize session manager
	sessionManager := auth.NewSessionManager(cfg.Server.Password)

	// Initialize HTTP handler
	h := handler.New(cfg, midiClient, sessionManager)

	// Setup HTTP routes
	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("/api/login", h.HandleLogin)
	mux.HandleFunc("/login.html", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "web/static/login.html")
	})

	// Protected routes
	mux.HandleFunc("/", sessionManager.RequireAuth(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "web/index.html")
	}))
	mux.HandleFunc("/api/config", sessionManager.RequireAuth(h.HandleConfig))
	mux.HandleFunc("/api/logout", sessionManager.RequireAuth(h.HandleLogout))
	mux.HandleFunc("/ws", h.HandleWebSocket) // WebSocket handles auth internally

	// Serve static files
	fs := http.FileServer(http.Dir("web/static"))
	mux.Handle("/static/", http.StripPrefix("/static/", fs))

	// Start server
	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	server := &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	// Graceful shutdown
	go func() {
		sigint := make(chan os.Signal, 1)
		signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
		<-sigint

		log.Println("Shutting down server...")
		midiClient.Close()
		os.Exit(0)
	}()

	log.Printf("Server listening on http://localhost%s", addr)
	log.Printf("Login with password: %s", cfg.Server.Password)

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
}
