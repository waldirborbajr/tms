package main

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// FilterModel gerencia o estado da pesquisa/filtro na TUI
type FilterModel struct {
	Text      string
	Active    bool
	Filtered  []string
	AllItems  []string
	Selected  int
	OnFilter  func([]string)
	OnCancel  func()
	OnConfirm func(string)
}

// NewFilterModel cria um novo modelo de filtro
func NewFilterModel(items []string) *FilterModel {
	return &FilterModel{
		Text:     "",
		Active:   false,
		AllItems: items,
		Filtered: items,
		Selected: 0,
	}
}

// Init implementa tea.Model
func (f *FilterModel) Init() tea.Cmd {
	return nil
}

// Update implementa tea.Model
func (f *FilterModel) Update(msg tea.Msg) (*FilterModel, tea.Cmd) {
	if !f.Active {
		return f, nil
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "esc":
			f.Active = false
			f.Text = ""
			f.Filtered = f.AllItems
			if f.OnCancel != nil {
				f.OnCancel()
			}
			return f, nil

		case "enter":
			f.Active = false
			if f.OnConfirm != nil && len(f.Filtered) > 0 {
				f.OnConfirm(f.Filtered[f.Selected])
			}
			return f, nil

		case "up", "k":
			if f.Selected > 0 {
				f.Selected--
			}
			return f, nil

		case "down", "j":
			if f.Selected < len(f.Filtered)-1 {
				f.Selected++
			}
			return f, nil

		case "backspace":
			if len(f.Text) > 0 {
				f.Text = f.Text[:len(f.Text)-1]
				f.applyFilter()
			}
			return f, nil

		default:
			// Adicionar caractere ao texto do filtro
			if len(msg.String()) == 1 {
				f.Text += msg.String()
				f.applyFilter()
			}
			return f, nil
		}
	}
	return f, nil
}

// applyFilter aplica o filtro atual à lista de itens
func (f *FilterModel) applyFilter() {
	if f.Text == "" {
		f.Filtered = f.AllItems
	} else {
		text := strings.ToLower(f.Text)
		filtered := []string{}
		for _, item := range f.AllItems {
			if strings.Contains(strings.ToLower(item), text) {
				filtered = append(filtered, item)
			}
		}
		f.Filtered = filtered
	}

	if f.Selected >= len(f.Filtered) && len(f.Filtered) > 0 {
		f.Selected = len(f.Filtered) - 1
	}
	if len(f.Filtered) == 0 {
		f.Selected = 0
	}

	if f.OnFilter != nil {
		f.OnFilter(f.Filtered)
	}
}

// SetItems atualiza a lista de itens
func (f *FilterModel) SetItems(items []string) {
	f.AllItems = items
	f.applyFilter()
}

// View renderiza o campo de filtro
func (f *FilterModel) View() string {
	if !f.Active {
		return ""
	}

	style := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFFFF")).
		Background(lipgloss.Color("#333333")).
		Padding(0, 1)

	prompt := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00FF00")).
		Render("🔍 ")

	cursor := "▌"
	if len(f.Text) > 0 {
		cursor = ""
	}

	input := style.Render(f.Text + cursor)
	return prompt + input
}

// Toggle ativa/desativa o filtro
func (f *FilterModel) Toggle() {
	f.Active = !f.Active
	if f.Active {
		f.Text = ""
		f.Selected = 0
		f.applyFilter()
	}
}

// IsActive retorna se o filtro está ativo
func (f *FilterModel) IsActive() bool {
	return f.Active
}

// GetFiltered retorna a lista filtrada
func (f *FilterModel) GetFiltered() []string {
	return f.Filtered
}

// GetSelected retorna o item selecionado
func (f *FilterModel) GetSelected() string {
	if len(f.Filtered) > 0 && f.Selected < len(f.Filtered) {
		return f.Filtered[f.Selected]
	}
	return ""
}
