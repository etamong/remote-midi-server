package config

import (
	"fmt"

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
