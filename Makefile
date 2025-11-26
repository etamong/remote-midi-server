.PHONY: build run install clean help

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

# Show help
help:
	@echo "Remote MIDI Server - Makefile commands:"
	@echo "  make build   - Build the server binary"
	@echo "  make run     - Run the server"
	@echo "  make install - Install Go dependencies"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make help    - Show this help message"
