#!/bin/bash
# Script para corrigir display.go e outras incompatibilidades

set -e

echo "🔧 Corrigindo display.go..."

# ========== 1. SUBSTITUIR DISPLAY.GO COMPLETAMENTE ==========

cat > display.go << 'EOF'
package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Variáveis de build (substituídas em tempo de compilação)
var (
	Version   = "dev"
	GitCommit = "unknown"
	BuildTime = "unknown"
)

// DisplaySessions exibe a lista de sessões formatada
func DisplaySessions() string {
	sessions, err := ListSessions()
	if err != nil {
		return "❌ Erro ao listar sessões: " + err.Error()
	}

	if len(sessions) == 0 {
		return "📭 Nenhuma sessão ativa"
	}

	var b strings.Builder
	b.WriteString("📋 Sessões ativas:\n")

	for _, name := range sessions {
		info, err := GetSessionInfo(name)
		if err != nil {
			b.WriteString(fmt.Sprintf("  - %s (erro ao obter info)\n", name))
			continue
		}
		attached := ""
		if info != nil && info.Attached {
			attached = " 🔗 attached"
		}
		b.WriteString(fmt.Sprintf("  - %s%s\n", name, attached))
	}

	return b.String()
}

// DisplayConfig exibe a configuração atual
func DisplayConfig() string {
	return "⚙️ Configuração atual:\n" +
		"  default_session: main\n" +
		"  default_directory: \n" +
		"  auto_switch: true\n" +
		"  theme: default"
}

// DisplayVersion exibe a versão
func DisplayVersion() string {
	return fmt.Sprintf("tms %s (build: %s, commit: %s)", Version, BuildTime, GitCommit)
}

// RenderMenu renderiza o menu principal com estilo
func RenderMenu(title string, items []string, cursor int, filterActive bool, filterText string) string {
	var b strings.Builder

	titleStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00FF00")).
		Bold(true).
		MarginBottom(1)

	b.WriteString(titleStyle.Render(title))
	b.WriteString("\n\n")

	// Barra de filtro
	if filterActive {
		filterStyle := lipgloss.NewStyle().
			Background(lipgloss.Color("#333333")).
			Padding(0, 1).
			MarginBottom(1)
		b.WriteString(filterStyle.Render("🔍 " + filterText + "▌"))
		b.WriteString("\n\n")
	}

	// Lista de itens
	for i, item := range items {
		cursorMarker := " "
		if i == cursor {
			cursorMarker = ">"
		}
		style := lipgloss.NewStyle()
		if i == cursor {
			style = style.Foreground(lipgloss.Color("#00FF00")).Bold(true)
		}
		b.WriteString(style.Render(fmt.Sprintf("%s %s", cursorMarker, item)))
		b.WriteString("\n")
	}

	// Dicas
	helpStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#666666")).
		MarginTop(1)

	help := "↑/↓: navigate • enter: select • q: quit • /: filter"
	if filterActive {
		help = "🔍 filter mode: type to search • enter: select • esc: cancel"
	}
	b.WriteString(helpStyle.Render(help))

	return b.String()
}

// TmuxDisplayMsg exibe uma mensagem no tmux (para integração)
func TmuxDisplayMsg(msg string) {
	// Esta função é um wrapper para TmuxDisplay (definida em tmux.go)
	TmuxDisplay(msg)
}
EOF

# ========== 2. CORRIGIR INPUT_MODEL.GO ==========

if [ -f input_model.go ]; then
    cat > input_model.go << 'EOF'
package main

import (
	"fmt"
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
EOF
fi

# ========== 3. CORRIGIR KILL_MODEL.GO ==========

if [ -f kill_model.go ]; then
    cat > kill_model.go << 'EOF'
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
	sessions, err := ListSessions()
	if err != nil {
		return nil, err
	}

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
EOF
fi

# ========== 4. CORRIGIR SESSION.GO ==========

if [ -f session.go ]; then
    # Adicionar CreateSessionWithDir se não existir
    if ! grep -q "func CreateSessionWithDir" session.go; then
        echo '
// CreateSessionWithDir é um alias para CreateSession (compatibilidade)
func CreateSessionWithDir(name, dir string) error {
    return CreateSession(name, dir)
}

// ListSessionsSafe retorna lista de sessões (ignora erro)
func ListSessionsSafe() []string {
    sessions, err := ListSessions()
    if err != nil {
        return []string{}
    }
    return sessions
}

// GetSessionInfoSafe retorna info da sessão (ignora erro)
func GetSessionInfoSafe(name string) *TmuxSession {
    info, err := GetSessionInfo(name)
    if err != nil {
        return nil
    }
    return info
}' >> session.go
    fi
fi

# ========== 5. LIMPAR E BUILDAR ==========

echo "🧹 Executando go mod tidy..."
go mod tidy

echo "🔨 Verificando build..."
if go build -o tms .; then
    echo "✅ Build bem-sucedido!"
else
    echo "❌ Erro no build. Verifique os arquivos manualmente."
    exit 1
fi

echo ""
echo "✅ Correções aplicadas com sucesso!"
echo ""
echo "📋 Para testar:"
echo "  ./tms --help"
echo "  ./tms list"