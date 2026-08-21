package main

import (
	"fmt"
	"strings"

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
	sessions := ListSessionsSafe()

	if len(sessions) == 0 {
		return "📭 Nenhuma sessão ativa"
	}

	var b strings.Builder
	b.WriteString("📋 Sessões ativas:\n")

	for _, name := range sessions {
		info := GetSessionInfoSafe(name)
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
