package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

var sessionCache = NewSessionCache(2 * time.Second)

type TmuxSession struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Path        string `json:"path"`
	Windows     int    `json:"windows"`
	Attached    bool   `json:"attached"`
	Created     string `json:"created"`
	LastAttached string `json:"last_attached"`
}

func TmuxCommand(args ...string) ([]byte, error) {
	cmd := exec.Command("tmux", args...)
	return cmd.CombinedOutput()
}

func TmuxCommandOutput(args ...string) (string, error) {
	output, err := TmuxCommand(args...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// TmuxDisplay exibe uma mensagem no tmux (para TUI)
func TmuxDisplay(msg string) {
	cmd := exec.Command("tmux", "display-message", "-p", msg)
	_ = cmd.Run() // Ignora erro, apenas tenta exibir
}

func ListSessionsRaw() ([]TmuxSession, error) {
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
			continue
		}
		sessions = append(sessions, session)
	}

	return sessions, nil
}

func ListSessions() ([]string, error) {
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

	sessionCache.Set(names)
	return names, nil
}

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

func CreateSession(name, dir string) error {
	args := []string{"new-session", "-d", "-s", name}
	if dir != "" {
		args = append(args, "-c", dir)
	}
	_, err := TmuxCommand(args...)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

func KillSession(name string) error {
	_, err := TmuxCommand("kill-session", "-t", name)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

func SwitchSession(name string) error {
	_, err := TmuxCommand("switch-client", "-t", name)
	return err
}

func RenameSession(old, new string) error {
	_, err := TmuxCommand("rename-session", "-t", old, new)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

func SessionPath(name string) (string, error) {
	return TmuxCommandOutput("display", "-t", name, "-p", "#{session_path}")
}

func IsSessionAttached(name string) bool {
	info, err := GetSessionInfo(name)
	if err != nil {
		return false
	}
	return info.Attached
}

func InvalidateCache() {
	sessionCache.Invalidate()
}

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
