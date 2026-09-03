package main

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// InputModel é um modelo para entrada de texto
type InputModel struct {
	Prompt     string
	Value      string
	Done       bool
	Cancelled  bool
	OnSubmit   func(string) tea.Cmd
	OnCancel   func() tea.Cmd
	Placeholder string
}

// NewInputModel cria um novo modelo de entrada
func NewInputModel(prompt string) *InputModel {
	return &InputModel{
		Prompt:     prompt,
		Value:      "",
		Done:       false,
		Cancelled:  false,
		Placeholder: "digite o nome...",
	}
}

// Init implementa tea.Model
func (m *InputModel) Init() tea.Cmd {
	return nil
}

// Update implementa tea.Model
func (m *InputModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if m.Done || m.Cancelled {
		return m, nil
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			if m.Value != "" {
				m.Done = true
				if m.OnSubmit != nil {
					return m, m.OnSubmit(m.Value)
				}
				return m, tea.Quit
			}
			return m, nil

		case "esc", "ctrl+c":
			m.Cancelled = true
			if m.OnCancel != nil {
				return m, m.OnCancel()
			}
			return m, tea.Quit

		case "backspace":
			if len(m.Value) > 0 {
				m.Value = m.Value[:len(m.Value)-1]
			}
			return m, nil

		default:
			// Adicionar caractere
			if len(msg.String()) == 1 {
				m.Value += msg.String()
			}
			return m, nil
		}
	}
	return m, nil
}

// View implementa tea.Model
func (m *InputModel) View() string {
	if m.Done || m.Cancelled {
		return ""
	}

	var b strings.Builder

	promptStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00FF00")).
		Bold(true)

	b.WriteString(promptStyle.Render(m.Prompt))
	b.WriteString("\n\n")

	if m.Value == "" {
		placeholderStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("#666666")).
			Italic(true)
		b.WriteString(placeholderStyle.Render(m.Placeholder))
	} else {
		valueStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFFFF"))
		b.WriteString(valueStyle.Render(m.Value))
	}

	b.WriteString("▌")

	helpStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#666666")).
		MarginTop(1)

	b.WriteString(helpStyle.Render("\n\nenter: confirm • esc: cancel"))

	return b.String()
}

// GetValue retorna o valor da entrada
func (m *InputModel) GetValue() string {
	return m.Value
}

// IsDone retorna se a entrada foi concluída
func (m *InputModel) IsDone() bool {
	return m.Done
}

// IsCancelled retorna se a entrada foi cancelada
func (m *InputModel) IsCancelled() bool {
	return m.Cancelled
}
