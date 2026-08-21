package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// SessionCache global para listagem de sessões
var sessionCache = NewSessionCache(2 * time.Second)

// TmuxSession representa uma sessão do tmux com informações detalhadas
type TmuxSession struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Path        string `json:"path"`
	Windows     int    `json:"windows"`
	Attached    bool   `json:"attached"`
	Created     string `json:"created"`
	LastAttached string `json:"last_attached"`
}

// TmuxCommand executa um comando tmux e retorna a saída
func TmuxCommand(args ...string) ([]byte, error) {
	cmd := exec.Command("tmux", args...)
	return cmd.CombinedOutput()
}

// TmuxCommandOutput executa e retorna saída como string (trimmed)
func TmuxCommandOutput(args ...string) (string, error) {
	output, err := TmuxCommand(args...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// ListSessionsRaw lista sessões usando formato JSON para parsing robusto
func ListSessionsRaw() ([]TmuxSession, error) {
	// Usar JSON para parsing robusto
	output, err := TmuxCommand("list-sessions", "-F", `{"id":"#{session_id}","name":"#{session_name}","path":"#{session_path}","windows":#{session_windows},"attached":#{session_attached},"created":"#{session_created}","last_attached":"#{session_last_attached}"}`)
	if err != nil {
		return nil, fmt.Errorf("erro ao listar sessões: %w", err)
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	var sessions []TmuxSession

	for _, line := range lines {
		if line == "" {
			continue
		}
		var session TmuxSession
		if err := json.Unmarshal([]byte(line), &session); err != nil {
			continue // Pular linha com erro
		}
		sessions = append(sessions, session)
	}

	return sessions, nil
}

// ListSessions retorna lista de nomes de sessões (usa cache)
func ListSessions() ([]string, error) {
	// Verificar cache
	if cached, ok := sessionCache.Get(); ok {
		return cached, nil
	}

	sessions, err := ListSessionsRaw()
	if err != nil {
		return nil, err
	}

	names := make([]string, len(sessions))
	for i, s := range sessions {
		names[i] = s.Name
	}

	// Atualizar cache
	sessionCache.Set(names)
	return names, nil
}

// SessionExists verifica se uma sessão existe (usa cache)
func SessionExists(name string) bool {
	sessions, err := ListSessions()
	if err != nil {
		return false
	}
	for _, s := range sessions {
		if s == name {
			return true
		}
	}
	return false
}

// GetSessionInfo obtém informações detalhadas de uma sessão
func GetSessionInfo(name string) (*TmuxSession, error) {
	sessions, err := ListSessionsRaw()
	if err != nil {
		return nil, err
	}
	for _, s := range sessions {
		if s.Name == name {
			return &s, nil
		}
	}
	return nil, fmt.Errorf("sessão '%s' não encontrada", name)
}

// NewSession cria uma nova sessão
func NewSession(name, dir string) error {
	args := []string{"new-session", "-d", "-s", name}
	if dir != "" {
		args = append(args, "-c", dir)
	}
	_, err := TmuxCommand(args...)
	if err == nil {
		sessionCache.Invalidate() // Invalidar cache
	}
	return err
}

// KillSession mata uma sessão
func KillSession(name string) error {
	_, err := TmuxCommand("kill-session", "-t", name)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

// SwitchSession alterna para uma sessão
func SwitchSession(name string) error {
	_, err := TmuxCommand("switch-client", "-t", name)
	return err
}

// RenameSession renomeia uma sessão
func RenameSession(old, new string) error {
	_, err := TmuxCommand("rename-session", "-t", old, new)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

// SessionPath retorna o caminho da sessão
func SessionPath(name string) (string, error) {
	return TmuxCommandOutput("display", "-t", name, "-p", "#{session_path}")
}

// IsSessionAttached verifica se a sessão está anexada
func IsSessionAttached(name string) bool {
	info, err := GetSessionInfo(name)
	if err != nil {
		return false
	}
	return info.Attached
}

// InvalidateCache invalida o cache de sessões
func InvalidateCache() {
	sessionCache.Invalidate()
}

// RefreshCache força a atualização do cache
func RefreshCache() error {
	sessions, err := ListSessionsRaw()
	if err != nil {
		return err
	}
	names := make([]string, len(sessions))
	for i, s := range sessions {
		names[i] = s.Name
	}
	sessionCache.Set(names)
	return nil
}
