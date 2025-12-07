#!/bin/bash
set -e

# Remote MIDI Server - macOS LaunchAgent 설치 스크립트

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLIST_NAME="com.etamong.remote-midi-server.plist"
INSTALL_BIN="/usr/local/bin"
INSTALL_SHARE="/usr/local/share/remote-midi-server"
INSTALL_LOG="/usr/local/var/log"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

echo "=== Remote MIDI Server LaunchAgent 설치 ==="
echo ""

# 기존 서비스 중지
if launchctl list | grep -q "com.etamong.remote-midi-server"; then
    echo "[1/6] 기존 서비스 중지 중..."
    launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
else
    echo "[1/6] 기존 서비스 없음 (skip)"
fi

# 바이너리 빌드
echo "[2/6] 바이너리 빌드 중..."
cd "$PROJECT_DIR"
go build -o remote-midi-server cmd/server/main.go

# 디렉토리 생성
echo "[3/6] 설치 디렉토리 생성 중..."
sudo mkdir -p "$INSTALL_BIN"
sudo mkdir -p "$INSTALL_SHARE"
sudo mkdir -p "$INSTALL_LOG"

# 로그 파일 생성 (launchd가 쓸 수 있도록)
sudo touch "$INSTALL_LOG/remote-midi-server.log"
sudo touch "$INSTALL_LOG/remote-midi-server.error.log"
sudo chown "$USER" "$INSTALL_LOG/remote-midi-server.log" "$INSTALL_LOG/remote-midi-server.error.log"

# 파일 복사
echo "[4/6] 파일 설치 중..."
sudo cp "$PROJECT_DIR/remote-midi-server" "$INSTALL_BIN/"
sudo cp -r "$PROJECT_DIR/web" "$INSTALL_SHARE/"
sudo cp "$PROJECT_DIR/config.yaml" "$INSTALL_SHARE/"

# 권한 설정
sudo chmod +x "$INSTALL_BIN/remote-midi-server"
sudo chmod -R a+rX "$INSTALL_SHARE"

# LaunchAgent 등록
echo "[5/6] LaunchAgent 등록 중..."
mkdir -p "$LAUNCH_AGENTS"
cp "$PROJECT_DIR/$PLIST_NAME" "$LAUNCH_AGENTS/"

# 서비스 시작
echo "[6/6] 서비스 시작 중..."
launchctl load "$LAUNCH_AGENTS/$PLIST_NAME"

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "설치 경로:"
echo "  - 바이너리: $INSTALL_BIN/remote-midi-server"
echo "  - 웹 파일:  $INSTALL_SHARE/"
echo "  - 로그:     $INSTALL_LOG/remote-midi-server.log"
echo ""
echo "서비스 관리:"
echo "  - 상태 확인: launchctl list | grep remote-midi"
echo "  - 중지:      launchctl unload ~/Library/LaunchAgents/$PLIST_NAME"
echo "  - 시작:      launchctl load ~/Library/LaunchAgents/$PLIST_NAME"
echo "  - 로그:      tail -f $INSTALL_LOG/remote-midi-server.log"
echo ""
echo "웹 접속: http://localhost:8080"
