package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// SwitchModel handles session switching state
type SwitchModel struct {
	sessions []string
	cursor   int
}

// NewSwitchModel creates a new switch model
func NewSwitchModel() SwitchModel {
	return SwitchModel{
		sessions: ListSessions(),
		cursor:   0,
	}
}

func (s SwitchModel) Init() tea.Cmd {
	return nil
}

func (s SwitchModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return NewMenuModel(), nil

		case "up", "k":
			if s.cursor > 0 {
				s.cursor--
			}

		case "down", "j":
			if s.cursor < len(s.sessions)-1 {
				s.cursor++
			}

		case "enter":
			if len(s.sessions) > 0 {
				selected := s.sessions[s.cursor]
				SwitchSession(selected)
				TmuxDisplay("Switched to: " + selected)
			}
			return NewMenuModel(), nil
		}
	}
	return s, nil
}

func (s SwitchModel) View() string {
	if len(s.sessions) == 0 {
		return "No sessions found.\n"
	}

	var sb strings.Builder
	sb.WriteString(TitleStyle.Render("🔄 Switch Session") + "\n\n")

	for i, session := range s.sessions {
		info := GetSessionInfo(session)
		line := fmt.Sprintf("%s (%s)", session, info)
		if i == s.cursor {
			sb.WriteString(SelectedStyle.Render(" → "+line) + "\n")
		} else {
			sb.WriteString(ItemStyle.Render("   "+line) + "\n")
		}
	}

	sb.WriteString("\n" + HelpStyle.Render("↑↓/jk • Enter = switch • q = back"))
	return sb.String()
}
