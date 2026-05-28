package main

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// MenuModel represents the main menu state
type MenuModel struct {
	cursor int
}

var menuOptions = []string{
	"New Session",
	"Switch Session",
	"Kill Sessions",
	"Rename Current Session",
	"List Active Sessions",
	"Save Current Session",
	"Restore Saved Session",
	"List Saved Sessions",
	"Show Version",
	"Show Config",
	"Quit",
}

// NewMenuModel creates a new menu model
func NewMenuModel() MenuModel {
	return MenuModel{cursor: 0}
}

func (m MenuModel) Init() tea.Cmd {
	return nil
}

func (m MenuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit

		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}

		case "down", "j":
			if m.cursor < len(menuOptions)-1 {
				m.cursor++
			}

		case "enter":
			return m.handleSelection()
		}
	}
	return m, nil
}

// handleSelection processes the selected menu option
func (m MenuModel) handleSelection() (tea.Model, tea.Cmd) {
	switch menuOptions[m.cursor] {
	case "New Session":
		return NewTextInput("New Session Name", "new", ""), nil

	case "Switch Session":
		return NewSwitchModel(), nil

	case "Kill Sessions":
		return NewKillModel(), nil

	case "Rename Current Session":
		current, _ := GetCurrentSession()
		return NewTextInput("New name for: "+current, "rename", current), nil

	case "List Active Sessions":
		return NewInformationModel(renderSessionList()), nil

	case "Save Current Session":
		return NewTextInput("Save session name", "save", ""), nil

	case "Restore Saved Session":
		return NewTextInput("Restore saved session name", "restore", ""), nil

	case "List Saved Sessions":
		return NewInformationModel(renderSavedSessionList()), nil

	case "Show Version":
		return NewInformationModel(renderVersion()), nil

	case "Show Config":
		return NewInformationModel(renderConfig()), nil

	case "Quit":
		return m, tea.Quit
	}

	return m, nil
}

func (m MenuModel) View() string {
	var s strings.Builder
	s.WriteString(TitleStyle.Render("🚀 TMS - Tmux Session Manager") + "\n\n")

	for i, option := range menuOptions {
		if i == m.cursor {
			s.WriteString(SelectedStyle.Render(" → "+option) + "\n")
		} else {
			s.WriteString(ItemStyle.Render("   "+option) + "\n")
		}
	}

	s.WriteString("\n" + HelpStyle.Render("↑↓/jk • Enter = select • q = quit"))
	return s.String()
}
