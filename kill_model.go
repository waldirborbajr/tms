package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// KillModel handles multi-select session deletion
type KillModel struct {
	sessions []string
	selected map[string]bool
	cursor   int
}

// NewKillModel creates a new kill model
func NewKillModel() KillModel {
	return KillModel{
		sessions: ListSessions(),
		selected: make(map[string]bool),
		cursor:   0,
	}
}

func (m KillModel) Init() tea.Cmd {
	return nil
}

func (m KillModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return NewMenuModel(), nil

		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}

		case "down", "j":
			if m.cursor < len(m.sessions)-1 {
				m.cursor++
			}

		case " ":
			if len(m.sessions) > 0 {
				sess := m.sessions[m.cursor]
				m.selected[sess] = !m.selected[sess]
			}

		case "enter":
			killed := 0
			for sess, sel := range m.selected {
				if sel {
					KillSession(sess)
					killed++
				}
			}
			if killed > 0 {
				TmuxDisplay(fmt.Sprintf("Killed %d session(s)", killed))
			}
			return NewMenuModel(), nil
		}
	}
	return m, nil
}

func (m KillModel) View() string {
	if len(m.sessions) == 0 {
		return "No sessions found.\n"
	}

	var s strings.Builder
	s.WriteString(TitleStyle.Render("🗑️ Kill Sessions (Multiple)") + "\n\n")

	for i, session := range m.sessions {
		info := GetSessionInfo(session)
		check := " "
		if m.selected[session] {
			check = "✓"
		}
		line := fmt.Sprintf("[%s] %s (%s)", check, session, info)

		if i == m.cursor {
			s.WriteString(SelectedStyle.Render(" → "+line) + "\n")
		} else {
			s.WriteString(ItemStyle.Render("   "+line) + "\n")
		}
	}

	s.WriteString("\n" + HelpStyle.Render("↑↓/jk • Space = toggle • Enter = kill selected • q = back"))
	return s.String()
}
