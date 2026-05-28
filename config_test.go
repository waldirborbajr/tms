package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDefaultConfig(t *testing.T) {
	cfg := defaultConfig()

	if cfg.DefaultSession != "main" {
		t.Fatalf("expected DefaultSession=main, got %q", cfg.DefaultSession)
	}
	if cfg.DefaultDirectory != "" {
		t.Fatalf("expected DefaultDirectory empty, got %q", cfg.DefaultDirectory)
	}
	if cfg.AutoSwitch != true {
		t.Fatalf("expected AutoSwitch=true, got %v", cfg.AutoSwitch)
	}
	if cfg.Theme != "default" {
		t.Fatalf("expected Theme=default, got %q", cfg.Theme)
	}
}

func TestLoadConfigCreatesDefault(t *testing.T) {
	tempHome := t.TempDir()
	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tempHome)
	defer os.Setenv("HOME", oldHome)

	LoadConfig()

	configPath := filepath.Join(tempHome, configDir, configFile)
	if _, err := os.Stat(configPath); err != nil {
		t.Fatalf("expected config file to be created, got error: %v", err)
	}

	cfg := GetConfig()
	if cfg.DefaultSession != "main" {
		t.Fatalf("expected DefaultSession=main, got %q", cfg.DefaultSession)
	}
	if cfg.AutoSwitch != true {
		t.Fatalf("expected AutoSwitch=true, got %v", cfg.AutoSwitch)
	}
}

func TestLoadConfigReadsExisting(t *testing.T) {
	tempHome := t.TempDir()
	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tempHome)
	defer os.Setenv("HOME", oldHome)

	configDirPath := filepath.Join(tempHome, configDir)
	if err := os.MkdirAll(configDirPath, 0755); err != nil {
		t.Fatalf("failed to create config directory: %v", err)
	}

	content := `default_session = "work"
default_directory = "/tmp"
auto_switch = false
theme = "dracula"
`
	if err := os.WriteFile(filepath.Join(configDirPath, configFile), []byte(content), 0644); err != nil {
		t.Fatalf("failed to write config file: %v", err)
	}

	LoadConfig()

	cfg := GetConfig()
	if cfg.DefaultSession != "work" {
		t.Fatalf("expected DefaultSession=work, got %q", cfg.DefaultSession)
	}
	if cfg.DefaultDirectory != "/tmp" {
		t.Fatalf("expected DefaultDirectory=/tmp, got %q", cfg.DefaultDirectory)
	}
	if cfg.AutoSwitch != false {
		t.Fatalf("expected AutoSwitch=false, got %v", cfg.AutoSwitch)
	}
	if cfg.Theme != "dracula" {
		t.Fatalf("expected Theme=dracula, got %q", cfg.Theme)
	}
}
