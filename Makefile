.PHONY: build run install clean docker-build docker-run docker-stop docker-logs \
       service-install service-uninstall service-status service-start service-stop \
       service-restart service-logs service-config service-update help

# Build the server binary
build:
	@echo "Building server..."
	go build -o bin/remote-midi-server cmd/server/main.go

# Run the server
run:
	@echo "Starting server..."
	go run cmd/server/main.go

# Install dependencies
install:
	@echo "Installing dependencies..."
	@if [ "$$(uname)" = "Darwin" ]; then \
		if command -v brew >/dev/null 2>&1; then \
			if ! brew list rtmidi >/dev/null 2>&1; then \
				echo "Installing rtmidi via Homebrew..."; \
				brew install rtmidi; \
			else \
				echo "rtmidi already installed"; \
			fi \
		else \
			echo "Warning: Homebrew not found. Please install rtmidi manually."; \
		fi \
	fi
	go mod download
	go mod tidy

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -rf bin/

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t remote-midi-server:latest .

# Run with Docker Compose
docker-run:
	@echo "Starting Docker container..."
	docker-compose up -d

# Stop Docker container
docker-stop:
	@echo "Stopping Docker container..."
	docker-compose down

# View Docker logs
docker-logs:
	@echo "Showing Docker logs..."
	docker-compose logs -f

# === macOS launchd Service ===

# Install as launchd service
service-install:
	@./scripts/install-launchd.sh

# Uninstall launchd service
service-uninstall:
	@./scripts/uninstall-launchd.sh

# Show service status
service-status:
	@./scripts/manage.sh status

# Start service
service-start:
	@./scripts/manage.sh start

# Stop service
service-stop:
	@./scripts/manage.sh stop

# Restart service
service-restart:
	@./scripts/manage.sh restart

# View service logs
service-logs:
	@./scripts/manage.sh logs

# Edit service config
service-config:
	@./scripts/manage.sh config

# Update service binary
service-update:
	@./scripts/update.sh

# Show help
help:
	@echo "Remote MIDI Server - Makefile commands:"
	@echo ""
	@echo "Local development:"
	@echo "  make build          - Build the server binary"
	@echo "  make run            - Run the server locally"
	@echo "  make install        - Install Go dependencies"
	@echo "  make clean          - Clean build artifacts"
	@echo ""
	@echo "Docker (MIDI 미지원, 웹 UI 테스트용):"
	@echo "  make docker-build   - Build Docker image"
	@echo "  make docker-run     - Run with Docker Compose"
	@echo "  make docker-stop    - Stop Docker container"
	@echo "  make docker-logs    - View Docker container logs"
	@echo ""
	@echo "macOS launchd Service:"
	@echo "  make service-install   - Install as launchd service"
	@echo "  make service-uninstall - Uninstall launchd service"
	@echo "  make service-status    - Show service status"
	@echo "  make service-start     - Start service"
	@echo "  make service-stop      - Stop service"
	@echo "  make service-restart   - Restart service"
	@echo "  make service-logs      - View service logs"
	@echo "  make service-config    - Edit service config"
	@echo "  make service-update    - Update service binary"
	@echo ""
	@echo "  make help           - Show this help message"
