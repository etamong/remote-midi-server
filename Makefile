.PHONY: build run install clean docker-build docker-run docker-stop docker-logs help

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

# Show help
help:
	@echo "Remote MIDI Server - Makefile commands:"
	@echo ""
	@echo "Local development:"
	@echo "  make build        - Build the server binary"
	@echo "  make run          - Run the server locally"
	@echo "  make install      - Install Go dependencies"
	@echo "  make clean        - Clean build artifacts"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-run   - Run with Docker Compose"
	@echo "  make docker-stop  - Stop Docker container"
	@echo "  make docker-logs  - View Docker container logs"
	@echo ""
	@echo "  make help         - Show this help message"
