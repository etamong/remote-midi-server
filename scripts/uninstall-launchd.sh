#!/bin/bash
set -e

# Remote MIDI Server - macOS LaunchAgent 제거 스크립트

PLIST_NAME="com.etamong.remote-midi-server.plist"
INSTALL_BIN="/usr/local/bin"
INSTALL_SHARE="/usr/local/share/remote-midi-server"
INSTALL_LOG="/usr/local/var/log"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

echo "=== Remote MIDI Server LaunchAgent 제거 ==="
echo ""

# 서비스 중지
if launchctl list | grep -q "com.etamong.remote-midi-server"; then
    echo "[1/4] 서비스 중지 중..."
    launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
else
    echo "[1/4] 서비스가 실행 중이 아님 (skip)"
fi

# LaunchAgent 제거
echo "[2/4] LaunchAgent 제거 중..."
rm -f "$LAUNCH_AGENTS/$PLIST_NAME"

# 바이너리 제거
echo "[3/4] 바이너리 제거 중..."
sudo rm -f "$INSTALL_BIN/remote-midi-server"

# 데이터 디렉토리 제거
echo "[4/4] 데이터 디렉토리 제거 중..."
sudo rm -rf "$INSTALL_SHARE"

echo ""
echo "=== 제거 완료 ==="
echo ""
echo "로그 파일은 유지됩니다: $INSTALL_LOG/remote-midi-server*.log"
echo "로그도 삭제하려면: sudo rm -f $INSTALL_LOG/remote-midi-server*.log"
