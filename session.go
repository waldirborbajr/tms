package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
)

// SessionDefinition representa uma definição de sessão salva
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
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
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
func saveSessionDefinition(name string, session SessionDefinition) error {
	sessionsDir := getSessionsDir()
	if err := os.MkdirAll(sessionsDir, 0755); err != nil {
		return err
	}

	sessionFile := filepath.Join(sessionsDir, name+".toml")
	f, err := os.Create(sessionFile)
	if err != nil {
		return err
	}
	defer f.Close()

	encoder := toml.NewEncoder(f)
	return encoder.Encode(session)
}

// ListSavedSessions lista sessões salvas
func ListSavedSessions() ([]string, error) {
	sessionsDir := getSessionsDir()
	files, err := os.ReadDir(sessionsDir)
	if err != nil {
		return []string{}, nil
	}

	var names []string
	for _, file := range files {
		if strings.HasSuffix(file.Name(), ".toml") {
			name := strings.TrimSuffix(file.Name(), ".toml")
			names = append(names, name)
		}
	}
	return names, nil
}

// ========== FUNÇÕES AUXILIARES PARA COMPATIBILIDADE ==========

// ListSessionsSafe retorna lista de sessões (1 valor, ignora erro)
func ListSessionsSafe() []string {
	sessions, err := ListSessions()
	if err != nil {
		return []string{}
	}
	return sessions
}

// GetSessionInfoSafe retorna info da sessão (1 valor, ignora erro)
func GetSessionInfoSafe(name string) *TmuxSession {
	info, err := GetSessionInfo(name)
	if err != nil {
		return nil
	}
	return info
}
