#!/bin/bash
set -e

# Remote MIDI Server 관리 스크립트

PLIST_NAME="com.etamong.remote-midi-server.plist"
INSTALL_BIN="/usr/local/bin/remote-midi-server"
INSTALL_SHARE="/usr/local/share/remote-midi-server"
CONFIG_FILE="$INSTALL_SHARE/config.yaml"
LOG_FILE="/usr/local/var/log/remote-midi-server.log"
ERROR_LOG="/usr/local/var/log/remote-midi-server.error.log"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}=== Remote MIDI Server 관리 ===${NC}"
    echo ""
}

print_status() {
    if launchctl list | grep -q "com.etamong.remote-midi-server"; then
        local pid=$(launchctl list | grep "com.etamong.remote-midi-server" | awk '{print $1}')
        local exit_code=$(launchctl list | grep "com.etamong.remote-midi-server" | awk '{print $2}')
        # PID가 숫자이면 실행 중, "-"이면 중지됨
        if [ "$pid" != "-" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then
            echo -e "상태: ${GREEN}실행 중${NC} (PID: $pid)"
        else
            echo -e "상태: ${RED}중지됨${NC} (Exit: $exit_code)"
        fi
    else
        echo -e "상태: ${YELLOW}설치되지 않음${NC}"
    fi
}

cmd_status() {
    print_header
    print_status
    echo ""
    if [ -f "$CONFIG_FILE" ]; then
        echo "설정 파일: $CONFIG_FILE"
        echo "포트: $(grep -E '^\s+port:' "$CONFIG_FILE" | head -1 | awk '{print $2}')"
        echo "MIDI 포트: $(grep -E '^\s+port_name:' "$CONFIG_FILE" | awk -F'"' '{print $2}')"
    fi
    echo ""
}

cmd_start() {
    echo "서비스 시작 중..."
    if [ -f "$LAUNCH_AGENTS/$PLIST_NAME" ]; then
        launchctl load "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
        sleep 1
        print_status
    else
        echo -e "${RED}오류: LaunchAgent가 설치되지 않았습니다.${NC}"
        echo "먼저 ./scripts/install-launchd.sh 를 실행하세요."
        exit 1
    fi
}

cmd_stop() {
    echo "서비스 중지 중..."
    launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
    sleep 1
    print_status
}

cmd_restart() {
    echo "서비스 재시작 중..."
    launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
    sleep 1
    launchctl load "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
    sleep 1
    print_status
}

cmd_logs() {
    echo "로그 보기 (Ctrl+C로 종료)..."
    echo ""
    tail -f "$LOG_FILE" "$ERROR_LOG" 2>/dev/null
}

cmd_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}오류: 설정 파일이 없습니다.${NC}"
        exit 1
    fi

    echo ""
    echo -e "${BLUE}=== 설정 수정 ===${NC}"
    echo ""
    echo "현재 설정:"
    echo "─────────────────────────────────"
    cat "$CONFIG_FILE"
    echo "─────────────────────────────────"
    echo ""
    echo "무엇을 수정하시겠습니까?"
    echo ""
    echo "  1) 서버 포트"
    echo "  2) 비밀번호"
    echo "  3) MIDI 포트 이름"
    echo "  4) MIDI 채널"
    echo "  5) 버튼 설정"
    echo "  6) 설정 파일 직접 편집"
    echo "  0) 취소"
    echo ""
    read -p "선택 [0-6]: " choice

    case $choice in
        1)
            read -p "새 포트 번호: " new_port
            sudo sed -i '' "s/port: [0-9]*/port: $new_port/" "$CONFIG_FILE"
            echo -e "${GREEN}포트가 $new_port 로 변경되었습니다.${NC}"
            ;;
        2)
            read -p "새 비밀번호: " new_pass
            sudo sed -i '' "s/password: \".*\"/password: \"$new_pass\"/" "$CONFIG_FILE"
            echo -e "${GREEN}비밀번호가 변경되었습니다.${NC}"
            ;;
        3)
            read -p "새 MIDI 포트 이름: " new_midi
            sudo sed -i '' "s/port_name: \".*\"/port_name: \"$new_midi\"/" "$CONFIG_FILE"
            echo -e "${GREEN}MIDI 포트 이름이 변경되었습니다.${NC}"
            ;;
        4)
            read -p "새 MIDI 채널 (0-15): " new_channel
            sudo sed -i '' "s/channel: [0-9]*/channel: $new_channel/" "$CONFIG_FILE"
            echo -e "${GREEN}MIDI 채널이 $new_channel 로 변경되었습니다.${NC}"
            ;;
        5)
            echo ""
            echo "버튼 설정은 직접 편집이 필요합니다."
            read -p "편집기로 열까요? [y/N]: " yn
            if [[ $yn =~ ^[Yy]$ ]]; then
                sudo ${EDITOR:-nano} "$CONFIG_FILE"
            fi
            ;;
        6)
            sudo ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        0)
            echo "취소되었습니다."
            return
            ;;
        *)
            echo "잘못된 선택입니다."
            return
            ;;
    esac

    echo ""
    read -p "서비스를 재시작하시겠습니까? [Y/n]: " restart
    if [[ ! $restart =~ ^[Nn]$ ]]; then
        cmd_restart
    fi
}

cmd_help() {
    echo "사용법: $0 <명령>"
    echo ""
    echo "명령:"
    echo "  status    서비스 상태 확인"
    echo "  start     서비스 시작"
    echo "  stop      서비스 중지"
    echo "  restart   서비스 재시작"
    echo "  logs      로그 보기"
    echo "  config    설정 수정"
    echo "  help      도움말"
    echo ""
}

# 메인
case "${1:-}" in
    status)
        cmd_status
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    logs)
        cmd_logs
        ;;
    config)
        cmd_config
        ;;
    help|--help|-h)
        cmd_help
        ;;
    "")
        print_header
        print_status
        echo ""
        cmd_help
        ;;
    *)
        echo "알 수 없는 명령: $1"
        cmd_help
        exit 1
        ;;
esac
