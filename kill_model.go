package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// KillModel é um modelo para seleção múltipla de sessões para matar
type KillModel struct {
	Sessions    []string
	Selected    map[int]bool
	Cursor      int
	Done        bool
	Quit        bool
}

// NewKillModel cria um novo modelo de kill
func NewKillModel() (*KillModel, error) {
	sessions := ListSessionsSafe()

	return &KillModel{
		Sessions: sessions,
		Selected: make(map[int]bool),
		Cursor:   0,
		Done:     false,
	}, nil
}

// Init implementa tea.Model
func (m *KillModel) Init() tea.Cmd {
	return nil
}

// Update implementa tea.Model
func (m *KillModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if m.Done || m.Quit {
		return m, tea.Quit
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.Quit = true
			return m, tea.Quit

		case "up", "k":
			if m.Cursor > 0 {
				m.Cursor--
			}
			return m, nil

		case "down", "j":
			if m.Cursor < len(m.Sessions)-1 {
				m.Cursor++
			}
			return m, nil

		case " ":
			m.Selected[m.Cursor] = !m.Selected[m.Cursor]
			return m, nil

		case "enter":
			m.Done = true
			return m, m.killSelected()

		default:
			return m, nil
		}
	}
	return m, nil
}

// killSelected mata as sessões selecionadas
func (m *KillModel) killSelected() tea.Cmd {
	var toKill []string
	for i, selected := range m.Selected {
		if selected {
			toKill = append(toKill, m.Sessions[i])
		}
	}

	if len(toKill) == 0 {
		TmuxDisplay("⚠️ Nenhuma sessão selecionada")
		return tea.Quit
	}

	return func() tea.Msg {
		for _, name := range toKill {
			if err := KillSession(name); err == nil {
				TmuxDisplay(fmt.Sprintf("🗑️ Sessão '%s' morta", name))
			} else {
				TmuxDisplay(fmt.Sprintf("❌ Erro ao matar '%s': %v", name, err))
			}
		}
		return tea.Quit()
	}
}

// View implementa tea.Model
func (m *KillModel) View() string {
	if len(m.Sessions) == 0 {
		return "📭 Nenhuma sessão ativa para matar"
	}

	var b strings.Builder

	titleStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FF0000")).
		Bold(true).
		MarginBottom(1)

	b.WriteString(titleStyle.Render("🗑️ Selecione as sessões para matar"))
	b.WriteString("\n\n")

	for i, name := range m.Sessions {
		checkbox := "☐"
		if m.Selected[i] {
			checkbox = "☑"
		}

		cursor := " "
		if m.Cursor == i {
			cursor = ">"
		}

		style := lipgloss.NewStyle()
		if m.Selected[i] {
			style = style.Foreground(lipgloss.Color("#FF0000"))
		}
		if m.Cursor == i {
			style = style.Bold(true)
		}

		b.WriteString(style.Render(fmt.Sprintf("%s %s %s", cursor, checkbox, name)))
		b.WriteString("\n")
	}

	helpStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#666666")).
		MarginTop(1)

	b.WriteString(helpStyle.Render("\nspace: toggle • enter: kill selected • q: quit"))

	return b.String()
}

// IsDone retorna se o modelo foi concluído
func (m *KillModel) IsDone() bool {
	return m.Done
}

// IsQuit retorna se o usuário saiu
func (m *KillModel) IsQuit() bool {
	return m.Quit
}
