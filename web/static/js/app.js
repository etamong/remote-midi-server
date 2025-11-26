// Remote MIDI Controller Client
class MIDIController {
    constructor() {
        this.ws = null;
        this.buttons = [];
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.reconnectDelay = 2000;

        this.init();
    }

    async init() {
        // Load configuration
        await this.loadConfig();

        // Setup UI
        this.setupUI();

        // Connect WebSocket
        this.connect();
    }

    async loadConfig() {
        try {
            const response = await fetch('/api/config', {
                credentials: 'same-origin'
            });
            if (!response.ok) {
                throw new Error('Failed to load config');
            }
            const data = await response.json();
            this.buttons = data.buttons;
            console.log('Config loaded:', this.buttons);
        } catch (error) {
            console.error('Failed to load config:', error);
            alert('설정을 불러오는데 실패했습니다.');
        }
    }

    setupUI() {
        const buttonGrid = document.getElementById('buttonGrid');
        const logoutBtn = document.getElementById('logoutBtn');

        // Check if buttons are loaded
        if (!this.buttons || this.buttons.length === 0) {
            console.error('No buttons configured');
            buttonGrid.innerHTML = '<p style="color: red; text-align: center;">설정을 불러올 수 없습니다.</p>';
            return;
        }

        console.log('Setting up UI with buttons:', this.buttons);

        // Create buttons
        this.buttons.forEach((button, index) => {
            const btn = document.createElement('button');
            btn.className = 'midi-button';
            btn.textContent = button.label || `Button ${index + 1}`;
            btn.dataset.index = index;
            btn.disabled = true;

            console.log(`Creating button ${index}: ${button.label}`);

            // Handle both mouse and touch events
            btn.addEventListener('mousedown', (e) => this.handleButtonPress(e, index));
            btn.addEventListener('touchstart', (e) => {
                e.preventDefault();
                this.handleButtonPress(e, index);
            });

            buttonGrid.appendChild(btn);
        });

        // Logout handler
        logoutBtn.addEventListener('click', () => {
            window.location.href = '/api/logout';
        });
    }

    connect() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws`;

        console.log('Connecting to WebSocket:', wsUrl);
        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            console.log('WebSocket connected');
            this.updateConnectionStatus(true);
            this.enableButtons();
            this.reconnectAttempts = 0;
        };

        this.ws.onclose = () => {
            console.log('WebSocket disconnected');
            this.updateConnectionStatus(false);
            this.disableButtons();
            this.attemptReconnect();
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };

        this.ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                console.log('Received:', data);

                if (data.status === 'ok' && data.buttonIndex !== undefined) {
                    this.highlightButton(data.buttonIndex);
                }
            } catch (error) {
                console.error('Failed to parse message:', error);
            }
        };
    }

    attemptReconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            console.log('Max reconnect attempts reached');
            alert('서버 연결이 끊어졌습니다. 페이지를 새로고침해주세요.');
            return;
        }

        this.reconnectAttempts++;
        console.log(`Reconnecting in ${this.reconnectDelay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

        setTimeout(() => {
            this.connect();
        }, this.reconnectDelay);
    }

    handleButtonPress(event, index) {
        if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
            console.error('WebSocket not connected');
            return;
        }

        const message = {
            buttonIndex: index
        };

        console.log('Sending button press:', message);
        this.ws.send(JSON.stringify(message));

        // Immediate visual feedback
        this.highlightButton(index);
    }

    highlightButton(index) {
        const buttons = document.querySelectorAll('.midi-button');
        const button = buttons[index];

        if (button) {
            button.classList.add('pressed');
            setTimeout(() => {
                button.classList.remove('pressed');
            }, 200);
        }
    }

    updateConnectionStatus(connected) {
        const statusElement = document.getElementById('connectionStatus');
        if (connected) {
            statusElement.textContent = '연결됨';
            statusElement.className = 'status-connected';
        } else {
            statusElement.textContent = '연결 안됨';
            statusElement.className = 'status-disconnected';
        }
    }

    enableButtons() {
        const buttons = document.querySelectorAll('.midi-button');
        buttons.forEach(btn => btn.disabled = false);
    }

    disableButtons() {
        const buttons = document.querySelectorAll('.midi-button');
        buttons.forEach(btn => btn.disabled = true);
    }
}

// Initialize controller when page loads
document.addEventListener('DOMContentLoaded', () => {
    new MIDIController();
});
