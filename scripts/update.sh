#!/bin/bash
set -e

# Remote MIDI Server 업데이트 스크립트

INSTALL_BIN="/usr/local/bin/remote-midi-server"
INSTALL_SHARE="/usr/local/share/remote-midi-server"
PLIST_NAME="com.etamong.remote-midi-server.plist"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
REPO_URL="https://github.com/etamong/remote-midi-server"
API_URL="https://api.github.com/repos/etamong/remote-midi-server/releases/latest"

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

get_current_version() {
    if [ -f "$INSTALL_BIN" ]; then
        # 바이너리에서 버전 정보 추출 시도
        echo "installed"
    else
        echo "none"
    fi
}

get_latest_version() {
    curl -s "$API_URL" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'
}

get_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

update_from_release() {
    echo -e "${BLUE}=== GitHub Release에서 업데이트 ===${NC}"
    echo ""

    local latest=$(get_latest_version)
    if [ -z "$latest" ]; then
        echo -e "${RED}오류: 최신 버전을 가져올 수 없습니다.${NC}"
        exit 1
    fi

    echo "최신 버전: $latest"
    echo ""

    local arch=$(get_arch)
    if [ "$arch" = "unknown" ]; then
        echo -e "${RED}오류: 지원되지 않는 아키텍처입니다.${NC}"
        exit 1
    fi

    local filename="remote-midi-server-darwin-${arch}.tar.gz"
    local download_url="$REPO_URL/releases/download/$latest/$filename"

    echo "다운로드: $filename"
    echo ""

    # 임시 디렉토리
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    # 다운로드
    echo "다운로드 중..."
    curl -L -o "$tmp_dir/$filename" "$download_url"

    # 압축 해제
    echo "압축 해제 중..."
    tar xzf "$tmp_dir/$filename" -C "$tmp_dir"

    # 서비스 중지
    echo "서비스 중지 중..."
    launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true

    # 파일 업데이트
    echo "파일 업데이트 중..."
    sudo cp "$tmp_dir/remote-midi-server-darwin-$arch" "$INSTALL_BIN"
    sudo chmod +x "$INSTALL_BIN"

    # 웹 파일 업데이트 (설정은 유지)
    if [ -d "$tmp_dir/web" ]; then
        sudo cp -r "$tmp_dir/web" "$INSTALL_SHARE/"
        sudo chmod -R a+rX "$INSTALL_SHARE"
    fi

    # 서비스 시작
    echo "서비스 시작 중..."
    launchctl load "$LAUNCH_AGENTS/$PLIST_NAME"

    echo ""
    echo -e "${GREEN}업데이트 완료: $latest${NC}"
}

update_from_source() {
    echo -e "${BLUE}=== 소스에서 빌드 및 업데이트 ===${NC}"
    echo ""

    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    local project_dir="$(dirname "$script_dir")"

    if [ ! -f "$project_dir/go.mod" ]; then
        echo -e "${RED}오류: 프로젝트 디렉토리를 찾을 수 없습니다.${NC}"
        exit 1
    fi

    cd "$project_dir"

    # Git pull (선택적)
    if [ -d ".git" ]; then
        read -p "git pull을 실행하시겠습니까? [Y/n]: " do_pull
        if [[ ! $do_pull =~ ^[Nn]$ ]]; then
            echo "소스 업데이트 중..."
            git pull
        fi
    fi

    # 빌드
    echo "빌드 중..."
    go build -o remote-midi-server cmd/server/main.go

    # 서비스 중지
    echo "서비스 중지 중..."
    launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true

    # 파일 업데이트
    echo "파일 업데이트 중..."
    sudo cp remote-midi-server "$INSTALL_BIN/"
    sudo chmod +x "$INSTALL_BIN"
    sudo cp -r web "$INSTALL_SHARE/"
    sudo chmod -R a+rX "$INSTALL_SHARE"

    # 서비스 시작
    echo "서비스 시작 중..."
    launchctl load "$LAUNCH_AGENTS/$PLIST_NAME"

    # 빌드 파일 정리
    rm -f remote-midi-server

    echo ""
    echo -e "${GREEN}업데이트 완료${NC}"
}

# 메인
echo ""
echo -e "${BLUE}=== Remote MIDI Server 업데이트 ===${NC}"
echo ""
echo "업데이트 방법을 선택하세요:"
echo ""
echo "  1) GitHub Release에서 다운로드 (권장)"
echo "  2) 소스에서 빌드"
echo "  0) 취소"
echo ""
read -p "선택 [0-2]: " choice

case $choice in
    1)
        update_from_release
        ;;
    2)
        update_from_source
        ;;
    0)
        echo "취소되었습니다."
        exit 0
        ;;
    *)
        echo "잘못된 선택입니다."
        exit 1
        ;;
esac
