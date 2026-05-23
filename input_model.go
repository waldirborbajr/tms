package main

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// TextInputModel handles user text input in the TUI
type TextInputModel struct {
	prompt  string
	value   string
	action  string // "new", "rename", etc.
	oldName string // used for rename operations
}

// NewTextInput creates a new text input model
func NewTextInput(prompt, action, oldName string) TextInputModel {
	return TextInputModel{
		prompt:  prompt,
		value:   "",
		action:  action,
		oldName: oldName,
	}
}

func (m TextInputModel) Init() tea.Cmd {
	return nil
}

func (m TextInputModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "esc":
			return NewMenuModel(), nil

		case "enter":
			if m.value == "" {
				return m, nil
			}

			cfg := GetConfig()
			switch m.action {
			case "new":
				CreateSession(m.value)
				if cfg.AutoSwitch {
					SwitchSession(m.value)
				}
				TmuxDisplay("Created session: " + m.value)

			case "rename":
				if m.oldName != "" {
					RenameSession(m.oldName, m.value)
					TmuxDisplay("Renamed: " + m.oldName + " → " + m.value)
				}
			}
			return NewMenuModel(), nil

		case "backspace":
			if len(m.value) > 0 {
				m.value = m.value[:len(m.value)-1]
			}

		default:
			if len(msg.String()) == 1 {
				m.value += msg.String()
			}
		}
	}
	return m, nil
}

func (m TextInputModel) View() string {
	var s strings.Builder
	s.WriteString(TitleStyle.Render("✏️ "+m.prompt) + "\n\n")
	s.WriteString(InputStyle.Render(" > "+m.value+"█") + "\n\n")
	s.WriteString(HelpStyle.Render("Type name • Enter = confirm • Esc = cancel"))
	return s.String()
}
