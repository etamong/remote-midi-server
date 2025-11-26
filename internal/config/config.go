package config

import (
	"fmt"
	"log"
	"sync"

	"github.com/fsnotify/fsnotify"
	"github.com/spf13/viper"
)

type Config struct {
	Server ServerConfig `mapstructure:"server"`
	MIDI   MIDIConfig   `mapstructure:"midi"`
}

type ServerConfig struct {
	Port     int    `mapstructure:"port"`
	Password string `mapstructure:"password"`
}

type MIDIConfig struct {
	PortName string         `mapstructure:"port_name"`
	Buttons  []ButtonConfig `mapstructure:"buttons"`
	Velocity uint8          `mapstructure:"velocity"`
	Channel  uint8          `mapstructure:"channel"`
}

type ButtonConfig struct {
	Note  uint8  `mapstructure:"note"`
	Label string `mapstructure:"label"`
}

func Load(configPath string) (*Config, error) {
	viper.SetConfigFile(configPath)
	viper.SetConfigType("yaml")

	// Set defaults
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("server.password", "changeme")
	viper.SetDefault("midi.velocity", 127)
	viper.SetDefault("midi.channel", 0)

	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("failed to read config: %w", err)
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Validate config
	if len(cfg.MIDI.Buttons) != 9 {
		return nil, fmt.Errorf("config must have exactly 9 buttons, got %d", len(cfg.MIDI.Buttons))
	}

	return &cfg, nil
}

// Watcher watches for config file changes and reloads automatically
type Watcher struct {
	config     *Config
	configPath string
	mu         sync.RWMutex
	onChange   []func(*Config)
}

// NewWatcher creates a new config watcher
func NewWatcher(configPath string) (*Watcher, error) {
	cfg, err := Load(configPath)
	if err != nil {
		return nil, err
	}

	w := &Watcher{
		config:     cfg,
		configPath: configPath,
		onChange:   make([]func(*Config), 0),
	}

	// Set up viper to watch for changes
	viper.WatchConfig()
	viper.OnConfigChange(func(e fsnotify.Event) {
		log.Printf("Config file changed: %s", e.Name)
		w.reload()
	})

	return w, nil
}

// reload reloads the configuration
func (w *Watcher) reload() {
	newCfg, err := Load(w.configPath)
	if err != nil {
		log.Printf("Failed to reload config: %v", err)
		return
	}

	w.mu.Lock()
	w.config = newCfg
	callbacks := w.onChange
	w.mu.Unlock()

	log.Println("Config reloaded successfully")

	// Notify listeners
	for _, callback := range callbacks {
		callback(newCfg)
	}
}

// Get returns the current configuration (thread-safe)
func (w *Watcher) Get() *Config {
	w.mu.RLock()
	defer w.mu.RUnlock()
	return w.config
}

// OnChange registers a callback to be called when config changes
func (w *Watcher) OnChange(callback func(*Config)) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.onChange = append(w.onChange, callback)
}
