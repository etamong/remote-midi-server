# Build stage
FROM golang:1.23-alpine AS builder

# Allow Go to download newer toolchain if needed
ENV GOTOOLCHAIN=auto

# Install build dependencies for CGO and MIDI support
RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    pkgconfig \
    alsa-lib-dev \
    git

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Set GOPATH and install Go 1.24 toolchain
ENV GOPATH=/go
RUN go install golang.org/dl/go1.24.10@latest
RUN /go/bin/go1.24.10 download

# Download dependencies with new toolchain
RUN /go/bin/go1.24.10 mod download

# Copy source code
COPY . .

# Update go.mod for Go 1.24 and build
RUN /go/bin/go1.24.10 mod tidy && \
    CGO_ENABLED=1 GOOS=linux /go/bin/go1.24.10 build -a -installsuffix cgo -o remote-midi-server cmd/server/main.go

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    alsa-lib \
    ca-certificates

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/remote-midi-server .

# Copy web files and config
COPY --from=builder /build/web ./web
COPY --from=builder /build/config.yaml .

# Expose port
EXPOSE 8080

# Run the server
CMD ["./remote-midi-server"]
