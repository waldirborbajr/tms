package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
)

// Config holds all application settings
type Config struct {
	DefaultSession   string `toml:"default_session"`
	DefaultDirectory string `toml:"default_directory"`
	AutoSwitch       bool   `toml:"auto_switch"`
	Theme            string `toml:"theme"`
}

var config Config

const (
	configDir  = ".config/tms"
	configFile = "config.toml"
)

// LoadConfig reads configuration from file or creates default
func LoadConfig() {
	home, err := os.UserHomeDir()
	if err != nil {
		config = defaultConfig()
		return
	}

	fullConfigDir := filepath.Join(home, configDir)
	configPath := filepath.Join(fullConfigDir, configFile)

	// Create default config if it doesn't exist
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		os.MkdirAll(fullConfigDir, 0755)
		defaultContent := `# TMS - Tmux Session Manager Configuration

default_session = "main"
default_directory = ""          # Example: "/home/user/projects"
auto_switch = true
theme = "default"
`
		os.WriteFile(configPath, []byte(defaultContent), 0644)
		fmt.Println("Created default config at:", configPath)
	}

	// Load config
	if _, err := toml.DecodeFile(configPath, &config); err != nil {
		config = defaultConfig()
	}
}

// defaultConfig returns hardcoded default values
func defaultConfig() Config {
	return Config{
		DefaultSession:   "main",
		DefaultDirectory: "",
		AutoSwitch:       true,
		Theme:            "default",
	}
}

// GetConfig returns the loaded configuration
func GetConfig() Config {
	return config
}
