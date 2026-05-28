package main

import (
	"fmt"
	"strings"
)

// renderVersion returns the formatted version info box as a string.
func renderVersion() string {
	var s strings.Builder
	s.WriteString("\n")
	s.WriteString("┌─────────────────────────────────────┐\n")
	s.WriteString(fmt.Sprintf("│ tms v%s\n", Version))
	s.WriteString("├─────────────────────────────────────┤\n")
	s.WriteString(fmt.Sprintf("│ Git Commit  : %-20s │\n", GitCommit))
	s.WriteString(fmt.Sprintf("│ Built       : %-20s │\n", BuildTime))
	s.WriteString("└─────────────────────────────────────┘\n")
	s.WriteString("\n")
	return s.String()
}

// renderConfig returns the formatted configuration box as a string.
func renderConfig() string {
	cfg := GetConfig()
	var s strings.Builder
	s.WriteString("\n")
	s.WriteString("┌──────────────────────────────────────┐\n")
	s.WriteString("│ TMS Configuration\n")
	s.WriteString("├──────────────────────────────────────┤\n")
	s.WriteString(fmt.Sprintf("│ Default Session  : %-18s │\n", cfg.DefaultSession))
	s.WriteString(fmt.Sprintf("│ Default Directory: %-18s │\n", cfg.DefaultDirectory))
	s.WriteString(fmt.Sprintf("│ Auto Switch      : %-18v │\n", cfg.AutoSwitch))
	s.WriteString(fmt.Sprintf("│ Theme            : %-18s │\n", cfg.Theme))
	s.WriteString("└──────────────────────────────────────┘\n")
	s.WriteString("\n")
	return s.String()
}

// renderSessionList returns the formatted session list as a string.
func renderSessionList() string {
	sessions := ListSessions()
	if len(sessions) == 0 {
		return "No active tmux sessions.\n"
	}
	var s strings.Builder
	s.WriteString("Active sessions:\n")
	for _, sess := range sessions {
		s.WriteString(fmt.Sprintf(" • %s (%s)\n", sess, GetSessionInfo(sess)))
	}
	return s.String()
}

func renderSavedSessionList() string {
	saved, err := ListSavedSessions()
	if err != nil {
		return fmt.Sprintf("Failed to load saved sessions: %v\n", err)
	}
	if len(saved) == 0 {
		return "No saved sessions found.\n"
	}
	var s strings.Builder
	s.WriteString("Saved sessions:\n")
	for _, name := range saved {
		s.WriteString(fmt.Sprintf(" • %s\n", name))
	}
	return s.String()
}
