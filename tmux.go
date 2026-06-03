package main

import (
	"fmt"
	"os/exec"
	"strings"
)

// RunTmux executes a tmux command and returns output
func RunTmux(args ...string) (string, error) {
	cmd := exec.Command("tmux", args...)
	output, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(output)), err
}

// ListSessions returns all active tmux session names
func ListSessions() []string {
	output, err := RunTmux("ls", "-F", "#{session_name}")
	if err != nil || output == "" {
		return []string{}
	}
	return strings.Split(output, "\n")
}

// GetSessionInfo returns a formatted string with session window count
func GetSessionInfo(session string) string {
	windows, _ := RunTmux("list-windows", "-t", session, "-F", "#{window_index}")
	count := len(strings.Split(strings.TrimSpace(windows), "\n"))
	if count == 1 && windows == "" {
		count = 0
	}
	return fmt.Sprintf("%d windows", count)
}

// TmuxDisplay shows a message in tmux status line
func TmuxDisplay(message string) {
	RunTmux("display-message", message)
}

// CreateSession creates a new tmux session
func CreateSession(name string) error {
	return CreateSessionWithDir(name, GetConfig().DefaultDirectory)
}

// CreateSessionWithDir creates a new tmux session in a specific directory
func CreateSessionWithDir(name, directory string) error {
	if err := ValidateSessionName(name); err != nil {
		return err
	}
	cmd := []string{"new-session", "-d", "-s", name}
	if directory != "" {
		cmd = append(cmd, "-c", directory)
	}
	_, err := RunTmux(cmd...)
	return err
}

// SwitchSession switches to a different session
func SwitchSession(name string) error {
	if err := ValidateSessionName(name); err != nil {
		return err
	}
	_, err := RunTmux("switch-client", "-t", name)
	return err
}

// KillSession terminates a session
func KillSession(name string) error {
	if err := ValidateSessionName(name); err != nil {
		return err
	}
	_, err := RunTmux("kill-session", "-t", name)
	return err
}

// RenameSession renames an existing session
func RenameSession(oldName, newName string) error {
	if err := ValidateSessionName(oldName); err != nil {
		return err
	}
	if err := ValidateSessionName(newName); err != nil {
		return err
	}
	_, err := RunTmux("rename-session", "-t", oldName, newName)
	return err
}

// GetCurrentSession returns the current session name
func GetCurrentSession() (string, error) {
	return RunTmux("display-message", "-p", "#S")
}
