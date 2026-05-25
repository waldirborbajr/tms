package main

import (
	tea "github.com/charmbracelet/bubbletea"
)

// InformationModel displays informational content and returns to menu on any key
type InformationModel struct {
	content string
}

// NewInformationModel creates a new information model with content
func NewInformationModel(content string) InformationModel {
	return InformationModel{
		content: content,
	}
}

func (m InformationModel) Init() tea.Cmd {
	return nil
}

func (m InformationModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg.(type) {
	case tea.KeyMsg:
		return NewMenuModel(), nil
	}
	return m, nil
}

func (m InformationModel) View() string {
	return m.content + "\nPress any key to return to menu...\n"
}
