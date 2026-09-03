package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// SwitchModel é um modelo para selecionar uma sessão
type SwitchModel struct {
	Sessions []string
	Cursor   int
	Done     bool
	Quit     bool
}

// NewSwitchModel cria um novo modelo de switch
func NewSwitchModel() (*SwitchModel, error) {
	sessions := ListSessionsSafe()
	if len(sessions) == 0 {
		return nil, fmt.Errorf("nenhuma sessão ativa")
	}

	return &SwitchModel{
		Sessions: sessions,
		Cursor:   0,
		Done:     false,
	}, nil
}

// Init implementa tea.Model
func (m *SwitchModel) Init() tea.Cmd {
	return nil
}

// Update implementa tea.Model
func (m *SwitchModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
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

		case "enter":
			m.Done = true
			return m, m.switchToSession()

		default:
			return m, nil
		}
	}
	return m, nil
}

// switchToSession alterna para a sessão selecionada
func (m *SwitchModel) switchToSession() tea.Cmd {
	name := m.Sessions[m.Cursor]
	return func() tea.Msg {
		if err := SwitchSession(name); err != nil {
			TmuxDisplay(fmt.Sprintf("❌ Erro ao alternar: %v", err))
		} else {
			TmuxDisplay(fmt.Sprintf("✅ Alternado para '%s'", name))
		}
		return tea.Quit()
	}
}

// View implementa tea.Model
func (m *SwitchModel) View() string {
	var b strings.Builder

	titleStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00FF00")).
		Bold(true).
		MarginBottom(1)

	b.WriteString(titleStyle.Render("🔀 Selecione a sessão"))
	b.WriteString("\n\n")

	for i, name := range m.Sessions {
		cursor := " "
		if m.Cursor == i {
			cursor = ">"
		}

		// Verificar se está attachada
		info := GetSessionInfoSafe(name)
		attached := ""
		if info != nil && info.Attached {
			attached = " 🔗"
		}

		style := lipgloss.NewStyle()
		if m.Cursor == i {
			style = style.Foreground(lipgloss.Color("#00FF00")).Bold(true)
		}

		b.WriteString(style.Render(fmt.Sprintf("%s %s%s", cursor, name, attached)))
		b.WriteString("\n")
	}

	helpStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#666666")).
		MarginTop(1)

	b.WriteString(helpStyle.Render("\n↑/↓: navigate • enter: switch • q: quit"))

	return b.String()
}

// GetSelected retorna o nome da sessão selecionada
func (m *SwitchModel) GetSelected() string {
	if m.Cursor >= 0 && m.Cursor < len(m.Sessions) {
		return m.Sessions[m.Cursor]
	}
	return ""
}

// IsDone retorna se o modelo foi concluído
func (m *SwitchModel) IsDone() bool {
	return m.Done
}

// IsQuit retorna se o usuário saiu
func (m *SwitchModel) IsQuit() bool {
	return m.Quit
}
