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

func (t TextInputModel) Init() tea.Cmd {
	return nil
}

func (t TextInputModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "esc":
			return NewMenuModel(), nil

		case "enter":
			if t.value == "" {
				return t, nil
			}

			cfg := GetConfig()
			switch t.action {
			case "new":
				if err := CreateSession(t.value); err != nil {
					TmuxDisplay("Failed to create session: " + err.Error())
					return NewMenuModel(), nil
				}
				if cfg.AutoSwitch {
					if err := SwitchSession(t.value); err != nil {
						TmuxDisplay("Created session but failed to switch: " + err.Error())
						return NewMenuModel(), nil
					}
				}
				TmuxDisplay("Created session: " + t.value)

			case "rename":
				if t.oldName != "" {
					if err := RenameSession(t.oldName, t.value); err != nil {
						TmuxDisplay("Failed to rename session: " + err.Error())
						return NewMenuModel(), nil
					}
					TmuxDisplay("Renamed: " + t.oldName + " → " + t.value)
				}
			}
			return NewMenuModel(), nil

		case "backspace":
			if len(t.value) > 0 {
				t.value = t.value[:len(t.value)-1]
			}

		default:
			if len(msg.String()) == 1 {
				t.value += msg.String()
			}
		}
	}
	return t, nil
}

func (t TextInputModel) View() string {
	var s strings.Builder
	s.WriteString(TitleStyle.Render("✏️ "+t.prompt) + "\n\n")
	s.WriteString(InputStyle.Render(" > "+t.value+"█") + "\n\n")
	s.WriteString(HelpStyle.Render("Type name • Enter = confirm • Esc = cancel"))
	return s.String()
}
