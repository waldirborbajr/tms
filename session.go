package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// SessionMetadata stores persistent session definition details.
type SessionMetadata struct {
	Name      string `json:"name"`
	Directory string `json:"directory,omitempty"`
}

func sessionStorageDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}

	path := filepath.Join(home, configDir, "sessions")
	if err := os.MkdirAll(path, 0755); err != nil {
		return "", err
	}
	return path, nil
}

func sessionFileName(name string) string {
	safeName := strings.ReplaceAll(name, string(filepath.Separator), "_")
	return fmt.Sprintf("%s.json", safeName)
}

func sessionFilePath(name string) (string, error) {
	dir, err := sessionStorageDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, sessionFileName(name)), nil
}

func SaveSessionMetadata(name, directory string) error {
	if strings.TrimSpace(name) == "" {
		return errors.New("session name is required")
	}

	meta := SessionMetadata{
		Name:      name,
		Directory: directory,
	}
	data, err := json.MarshalIndent(meta, "", "  ")
	if err != nil {
		return err
	}

	path, err := sessionFilePath(name)
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

func LoadSessionMetadata(name string) (SessionMetadata, error) {
	path, err := sessionFilePath(name)
	if err != nil {
		return SessionMetadata{}, err
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return SessionMetadata{}, err
	}

	var meta SessionMetadata
	if err := json.Unmarshal(data, &meta); err != nil {
		return SessionMetadata{}, err
	}
	return meta, nil
}

func ListSavedSessions() ([]string, error) {
	dir, err := sessionStorageDir()
	if err != nil {
		return nil, err
	}

	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	var saved []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.HasSuffix(name, ".json") {
			saved = append(saved, strings.TrimSuffix(name, ".json"))
		}
	}
	return saved, nil
}

func SaveSession(name, directory string) error {
	return SaveSessionMetadata(name, directory)
}

func containsSession(name string, sessions []string) bool {
	for _, s := range sessions {
		if s == name {
			return true
		}
	}
	return false
}

func RestoreSession(name string) error {
	meta, err := LoadSessionMetadata(name)
	if err != nil {
		return err
	}

	if containsSession(name, ListSessions()) {
		return SwitchSession(name)
	}

	dir := meta.Directory
	if dir == "" {
		dir = GetConfig().DefaultDirectory
	}

	if err := CreateSessionWithDir(name, dir); err != nil {
		return err
	}

	if GetConfig().AutoSwitch {
		return SwitchSession(name)
	}

	return nil
}
