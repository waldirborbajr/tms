package main

import "github.com/charmbracelet/lipgloss"

// Style definitions for TUI components
var (
	TitleStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF5555")).Bold(true)
	SelectedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF5555")).Bold(true)
	ItemStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("#BBBBBB"))
	HelpStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("#888888"))
	InputStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFCC00")).Bold(true)
)
