package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"unicode"
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
	safeName = strings.ReplaceAll(safeName, "/", "_")
	safeName = strings.ReplaceAll(safeName, "\\", "_")
	return fmt.Sprintf("%s.json", safeName)
}

func ValidateSessionName(name string) error {
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		return errors.New("session name is required")
	}
	if strings.ContainsAny(trimmed, "/\\") {
		return errors.New("session name must not contain path separators")
	}
	if strings.IndexFunc(trimmed, func(r rune) bool {
		return unicode.IsSpace(r) || unicode.IsControl(r)
	}) != -1 {
		return errors.New("session name must not contain whitespace or control characters")
	}
	if len(trimmed) > 64 {
		return errors.New("session name must be 64 characters or fewer")
	}
	return nil
}

func sessionFilePath(name string) (string, error) {
	dir, err := sessionStorageDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, sessionFileName(name)), nil
}

func SaveSessionMetadata(name, directory string) error {
	if err := ValidateSessionName(name); err != nil {
		return err
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

// ========== DEFINIÇÕES DE SESSÃO PARA IMPORTAÇÃO/EXPORTAÇÃO ==========

// SessionDefinition representa uma definição de sessão
type SessionDefinition struct {
	Name        string
	Directory   string
	Windows     []WindowDefinition
	PreCommands []string
}

// WindowDefinition representa uma janela na definição
type WindowDefinition struct {
	Name     string
	Layout   string
	Panes    []PaneDefinition
	Commands []string
}

// PaneDefinition representa um painel na definição
type PaneDefinition struct {
	Command string
}

// getSessionsDir retorna o diretório de sessões salvas
func getSessionsDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "tms", "sessions")
}

// loadSessionDefinition carrega uma definição de sessão
func loadSessionDefinition(name string) (SessionDefinition, error) {
	var session SessionDefinition
	sessionFile := filepath.Join(getSessionsDir(), name+".toml")
	if _, err := toml.DecodeFile(sessionFile, &session); err != nil {
		return session, fmt.Errorf("erro ao carregar sessão: %w", err)
	}
	return session, nil
}

// saveSessionDefinition salva uma definição de sessão
func saveSessionDefinition(path string, session SessionDefinition) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	encoder := toml.NewEncoder(f)
	return encoder.Encode(session)
}
