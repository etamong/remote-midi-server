# Remote MIDI Server

[![Build and Push Docker Image](https://github.com/etamong/remote-midi-server/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/etamong/remote-midi-server/actions/workflows/docker-publish.yml)
[![Release](https://github.com/etamong/remote-midi-server/actions/workflows/release.yml/badge.svg)](https://github.com/etamong/remote-midi-server/actions/workflows/release.yml)
[![Docker Image](https://ghcr-badge.egpl.dev/etamong/remote-midi-server/latest_tag?trim=major&label=latest)](https://github.com/etamong/remote-midi-server/pkgs/container/remote-midi-server)
[![GitHub Release](https://img.shields.io/github/v/release/etamong/remote-midi-server)](https://github.com/etamong/remote-midi-server/releases/latest)

웹 브라우저에서 접속하여 MIDI 신호를 전송할 수 있는 원격 MIDI 컨트롤러입니다. QLab 5 및 다른 MIDI 지원 애플리케이션과 함께 사용할 수 있습니다.

## 주요 기능

- 🎹 웹 기반 MIDI 컨트롤러 (9개 버튼)
- 📱 다양한 기기 지원 (맥북, 아이폰, 안드로이드, 태블릿)
- 🔒 비밀번호 기반 인증
- ⚡ WebSocket 기반 실시간 통신
- 🎨 반응형 UI 디자인
- 🎵 QLab 5 호환

## 시스템 요구사항

- Go 1.19 이상 (또는 Nix 사용)
- **macOS** (MIDI 출력 지원을 위해 필수)
- 네트워크 연결 (원격 접속용)

## 설치 방법

### 옵션 1: 사전 빌드된 바이너리 (가장 간단)

[Releases 페이지](https://github.com/etamong/remote-midi-server/releases/latest)에서 macOS 바이너리를 다운로드하세요:

- **macOS (Intel)**: `remote-midi-server-darwin-amd64.tar.gz`
- **macOS (Apple Silicon)**: `remote-midi-server-darwin-arm64.tar.gz`

다운로드 후:
```bash
# 압축 해제
tar xzf remote-midi-server-*.tar.gz

# 실행
./remote-midi-server
```

### 옵션 2: Nix 사용

Nix를 사용하면 모든 의존성이 자동으로 관리됩니다:

1. 저장소 클론 또는 다운로드

2. direnv 허용 (direnv가 설치되어 있는 경우):
```bash
direnv allow
```

또는 Nix 개발 환경 직접 진입:
```bash
nix develop
```

이제 모든 의존성(Go, RtMidi, CGO 라이브러리 등)이 자동으로 설정됩니다!

### 옵션 3: 수동 설치

1. 저장소 클론 또는 다운로드

2. Go 의존성 설치:
```bash
make install
```

또는:
```bash
go mod download
```

3. macOS에서 RtMidi 설치:
```bash
brew install rtmidi
```

### 옵션 4: Docker 사용

> **⚠️ 주의: Docker 환경에서는 MIDI 출력이 지원되지 않습니다.**
>
> macOS에서 Docker는 Linux VM 내부에서 실행됩니다. macOS는 CoreMIDI를, Linux는 ALSA를 사용하며
> 이 두 시스템은 완전히 다른 API입니다. CoreMIDI 장치는 파일 시스템에 노출되지 않아 볼륨 마운트로도
> 해결할 수 없습니다. Docker는 웹 UI 테스트 용도로만 사용하고, 실제 MIDI 출력이 필요하면
> 네이티브로 실행하거나 [launchd 설정](#macos-부팅-시-자동-실행-launchd)을 사용하세요.

Docker를 사용하면 의존성 설치 없이 바로 실행할 수 있습니다:

#### GitHub Container Registry에서 가져오기:
```bash
docker pull ghcr.io/etamong/remote-midi-server:latest
```

#### 실행:
```bash
docker run -d \
  --name remote-midi-server \
  -p 8080:8080 \
  -v $(pwd)/config.yaml:/app/config.yaml:ro \
  ghcr.io/etamong/remote-midi-server:latest
```

#### Docker Compose 사용:
```bash
# docker-compose.yml 파일 수정 (이미지를 ghcr.io/etamong/remote-midi-server:latest로 변경)
docker-compose up -d
```

#### 로컬에서 빌드:
```bash
make docker-build
make docker-run
```

## 설정

`config.yaml` 파일을 편집하여 설정을 변경할 수 있습니다:

```yaml
server:
  port: 8080              # 서버 포트
  password: "changeme"    # 로그인 비밀번호 (반드시 변경하세요!)

midi:
  port_name: "Remote MIDI Server"
  buttons:
    - note: 60            # MIDI 노트 번호 (0-127)
      label: "버튼 1"     # 버튼에 표시될 텍스트
    - note: 61
      label: "버튼 2"
    # ... 총 9개의 버튼 설정
  velocity: 127           # MIDI 벨로시티 (0-127)
  channel: 0              # MIDI 채널 (0-15)
```

### 버튼 라벨 및 MIDI 노트 커스터마이징

각 버튼의 `label`과 `note` 값을 원하는 대로 변경할 수 있습니다:

- **label**: 버튼에 표시될 한글/영문 텍스트
- **note**: MIDI 노트 번호 (C4 = 60, C#4 = 61, D4 = 62, ...)

## 실행 방법

### 개발 모드로 실행:
```bash
make run
```

또는:
```bash
go run cmd/server/main.go
```

### 빌드 후 실행:
```bash
make build
./bin/remote-midi-server
```

### 커스텀 설정 파일 사용:
```bash
./bin/remote-midi-server -config /path/to/config.yaml
```

### macOS 부팅 시 자동 실행 (launchd)

macOS에서 시스템 부팅 시 자동으로 서버를 실행하려면 LaunchAgent를 사용합니다.

#### 스크립트로 설치 (권장):
```bash
./scripts/install-launchd.sh
```

#### 제거:
```bash
./scripts/uninstall-launchd.sh
```

#### 수동 설치:
```bash
# 1. 바이너리 빌드
go build -o remote-midi-server cmd/server/main.go

# 2. 파일 설치
sudo mkdir -p /usr/local/bin
sudo mkdir -p /usr/local/share/remote-midi-server
sudo mkdir -p /usr/local/var/log

sudo cp remote-midi-server /usr/local/bin/
sudo cp -r web /usr/local/share/remote-midi-server/
sudo cp config.yaml /usr/local/share/remote-midi-server/

# 3. LaunchAgent 등록
cp com.etamong.remote-midi-server.plist ~/Library/LaunchAgents/

# 4. 서비스 시작
launchctl load ~/Library/LaunchAgents/com.etamong.remote-midi-server.plist
```

#### 서비스 관리 명령어:
```bash
# 상태 확인
launchctl list | grep remote-midi

# 중지
launchctl unload ~/Library/LaunchAgents/com.etamong.remote-midi-server.plist

# 시작
launchctl load ~/Library/LaunchAgents/com.etamong.remote-midi-server.plist

# 로그 확인
tail -f /usr/local/var/log/remote-midi-server.log
tail -f /usr/local/var/log/remote-midi-server.error.log
```

## 사용 방법

1. 서버 실행:
```bash
make run
```

2. 서버 시작 후 출력되는 메시지 확인:
```
Server listening on http://localhost:8080
Login with password: changeme
```

3. 브라우저에서 접속:
   - 로컬: `http://localhost:8080`
   - 네트워크: `http://[서버IP]:8080` (예: http://192.168.1.100:8080)

4. 비밀번호 입력하여 로그인

5. 9개의 버튼을 눌러 MIDI 신호 전송

## QLab 5와 연동하기

1. Remote MIDI Server 실행

2. QLab 5 열기

3. QLab 설정에서 MIDI 입력 확인:
   - QLab > Settings > MIDI
   - "Remote MIDI Server" 포트가 표시되는지 확인

4. QLab에서 MIDI 트리거 설정:
   - Cue 생성
   - Triggers 탭에서 MIDI 트리거 추가
   - 원하는 노트 번호 설정 (config.yaml의 note 값과 일치)

5. 웹 브라우저에서 버튼 클릭하여 QLab Cue 실행

## 프로젝트 구조

```
remote-midi-server/
├── cmd/
│   └── server/
│       └── main.go           # 메인 진입점
├── internal/
│   ├── config/
│   │   └── config.go         # 설정 로드
│   ├── handler/
│   │   └── handler.go        # HTTP/WebSocket 핸들러
│   ├── midi/
│   │   └── midi.go           # MIDI 출력
│   └── auth/
│       └── auth.go           # 인증 미들웨어
├── web/
│   ├── index.html            # 메인 UI
│   └── static/
│       ├── css/
│       │   └── style.css     # 스타일시트
│       ├── js/
│       │   └── app.js        # WebSocket 클라이언트
│       └── login.html        # 로그인 페이지
├── config.yaml               # 설정 파일
├── Makefile                  # 빌드 스크립트
└── README.md                 # 이 파일
```

## API 엔드포인트

- `POST /api/login` - 로그인
- `GET /api/config` - 버튼 설정 조회
- `GET /api/logout` - 로그아웃
- `WS /ws` - WebSocket 연결 (MIDI 이벤트 전송)

## 문제 해결

### MIDI 포트가 보이지 않는 경우

macOS에서는 rtmidi 드라이버가 자동으로 가상 MIDI 포트를 생성합니다. 만약 QLab에서 포트가 보이지 않는다면:

1. Audio MIDI Setup 앱 열기
2. Window > Show MIDI Studio
3. MIDI 장치 확인

### 원격 기기에서 접속이 안되는 경우

1. 방화벽 설정 확인
2. 서버와 클라이언트가 같은 네트워크에 있는지 확인
3. 서버 IP 주소 확인: `ifconfig` (macOS/Linux) 또는 `ipconfig` (Windows)

### 버튼을 눌러도 반응이 없는 경우

1. 브라우저 개발자 도구(F12) 열어서 콘솔 에러 확인
2. WebSocket 연결 상태 확인 (페이지 상단의 "연결됨" 표시)
3. 서버 로그 확인

## 개발

### 의존성

- `github.com/gorilla/websocket` - WebSocket 지원
- `github.com/spf13/viper` - 설정 관리
- `gitlab.com/gomidi/midi/v2` - MIDI 처리
- `gitlab.com/gomidi/midi/v2/drivers/rtmididrv` - MIDI 드라이버

### Makefile 명령어

```bash
# 개발
make build           # 빌드
make run             # 실행
make install         # 의존성 설치 (rtmidi 포함)
make clean           # 빌드 파일 삭제

# Docker (MIDI 미지원, 웹 UI 테스트용)
make docker-build    # Docker 이미지 빌드
make docker-run      # Docker Compose로 실행
make docker-stop     # Docker 컨테이너 중지
make docker-logs     # Docker 로그 보기

# macOS launchd 서비스
make service-install    # launchd 서비스 설치
make service-uninstall  # 서비스 제거
make service-status     # 상태 확인
make service-start      # 시작
make service-stop       # 중지
make service-restart    # 재시작
make service-logs       # 로그 보기
make service-config     # 설정 편집
make service-update     # 바이너리 업데이트

make help            # 도움말
```

## 라이선스

MIT License

## 기여

이슈 및 PR을 환영합니다!
