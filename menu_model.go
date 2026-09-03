package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// MenuModel representa o menu principal
type MenuModel struct {
	Choices       []string
	Cursor        int
	Selected      int
	Width         int
	Height        int
	Filter        *FilterModel
	FilterActive  bool
	Quit          bool
}

// NewMenuModel cria um novo modelo de menu
func NewMenuModel() *MenuModel {
	items := []string{"New Session", "Switch Session", "Kill Session", "Rename Session", "List Sessions", "Save Session", "Restore Session", "Import Session", "Export Session", "Quit"}
	return &MenuModel{
		Choices:      items,
		Cursor:       0,
		Selected:     -1,
		Filter:       NewFilterModel(items),
		FilterActive: false,
	}
}

// Init implementa tea.Model
func (m *MenuModel) Init() tea.Cmd {
	return nil
}

// Update implementa tea.Model
func (m *MenuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if m.FilterActive {
		return m.updateFilter(msg)
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
			if m.Cursor < len(m.Choices)-1 {
				m.Cursor++
			}
			return m, nil

		case "enter":
			m.Selected = m.Cursor
			return m, m.handleSelection()

		case "/":
			m.FilterActive = true
			m.Filter.Toggle()
			return m, nil

		default:
			return m, nil
		}
	}
	return m, nil
}

// updateFilter atualiza o estado do filtro
func (m *MenuModel) updateFilter(msg tea.Msg) (tea.Model, tea.Cmd) {
	newFilter, cmd := m.Filter.Update(msg)
	m.Filter = newFilter

	if !m.Filter.IsActive() {
		m.FilterActive = false
		// Restaurar lista original
		m.Choices = []string{"New Session", "Switch Session", "Kill Session", "Rename Session", "List Sessions", "Save Session", "Restore Session", "Import Session", "Export Session", "Quit"}
	} else {
		m.Choices = m.Filter.GetFiltered()
	}

	return m, cmd
}

// handleSelection processa a seleção do menu
func (m *MenuModel) handleSelection() tea.Cmd {
	choice := m.Choices[m.Cursor]
	switch choice {
	case "New Session":
		return func() tea.Msg { return NewSessionMsg{} }
	case "Switch Session":
		return func() tea.Msg { return SwitchSessionMsg{} }
	case "Kill Session":
		return func() tea.Msg { return KillSessionMsg{} }
	case "Rename Session":
		return func() tea.Msg { return RenameSessionMsg{} }
	case "List Sessions":
		return func() tea.Msg { return ListSessionsMsg{} }
	case "Save Session":
		return func() tea.Msg { return SaveSessionMsg{} }
	case "Restore Session":
		return func() tea.Msg { return RestoreSessionMsg{} }
	case "Import Session":
		return func() tea.Msg { return ImportSessionMsg{} }
	case "Export Session":
		return func() tea.Msg { return ExportSessionMsg{} }
	case "Quit":
		m.Quit = true
		return tea.Quit
	}
	return nil
}

// View implementa tea.Model
func (m *MenuModel) View() string {
	if m.Quit {
		return ""
	}

	var b strings.Builder

	// Título
	titleStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00FF00")).
		Bold(true).
		MarginBottom(1)

	b.WriteString(titleStyle.Render("🚀 tms - Tmux Session Manager"))
	b.WriteString("\n\n")

	// Barra de filtro
	if m.FilterActive {
		filterView := m.Filter.View()
		if filterView != "" {
			filterStyle := lipgloss.NewStyle().
				Background(lipgloss.Color("#333333")).
				Padding(0, 1).
				MarginBottom(1)
			b.WriteString(filterStyle.Render(filterView))
			b.WriteString("\n\n")
		}
	}

	// Lista de itens
	for i, choice := range m.Choices {
		cursor := " "
		if m.Cursor == i {
			cursor = ">"
		}

		style := lipgloss.NewStyle()
		if m.Cursor == i {
			style = style.Foreground(lipgloss.Color("#00FF00")).Bold(true)
		}

		item := fmt.Sprintf("%s %s", cursor, choice)
		b.WriteString(style.Render(item))
		b.WriteString("\n")
	}

	// Dicas de teclado
	helpStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#666666")).
		MarginTop(1)

	help := "↑/↓: navigate • enter: select • q: quit • /: filter"
	if m.FilterActive {
		help = "🔍 filter mode: type to search • enter: select • esc: cancel"
	}
	b.WriteString(helpStyle.Render(help))

	return b.String()
}

// ========== MENSAGENS PARA COMANDOS ==========

type NewSessionMsg struct{}
type SwitchSessionMsg struct{}
type KillSessionMsg struct{}
type RenameSessionMsg struct{}
type ListSessionsMsg struct{}
type SaveSessionMsg struct{}
type RestoreSessionMsg struct{}
type ImportSessionMsg struct{}
type ExportSessionMsg struct{}
