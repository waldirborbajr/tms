#!/bin/bash
# Script para corrigir session.go e switch_model.go

set -e

echo "🔧 Corrigindo session.go e switch_model.go..."

# ========== 1. SUBSTITUIR SESSION.GO ==========

cat > session.go << 'EOF'
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
)

// Configuração do tms
type Config struct {
	DefaultSession  string `toml:"default_session"`
	DefaultDirectory string `toml:"default_directory"`
	AutoSwitch      bool   `toml:"auto_switch"`
	Theme           string `toml:"theme"`
}

// SessionDefinition representa uma definição de sessão salva
type SessionDefinition struct {
	Name        string
	Directory   string
	Windows     []WindowDefinition
	PreCommands []string
}

// WindowDefinition representa uma janela na definição
type WindowDefinition struct {
	Name     string
	Layout   string
	Panes    []PaneDefinition
	Commands []string
}

// PaneDefinition representa um painel na definição
type PaneDefinition struct {
	Command string
}

// ConfigPath retorna o caminho do arquivo de configuração
func ConfigPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".config", "tms", "config.toml")
}

// LoadConfig carrega a configuração
func LoadConfig() Config {
	var config Config
	configPath := ConfigPath()

	if _, err := toml.DecodeFile(configPath, &config); err != nil {
		// Configuração padrão
		config = Config{
			DefaultSession:  "main",
			DefaultDirectory: "",
			AutoSwitch:      true,
			Theme:           "default",
		}
	}
	return config
}

// SaveConfig salva a configuração
func SaveConfig(config Config) error {
	configPath := ConfigPath()
	if err := os.MkdirAll(filepath.Dir(configPath), 0755); err != nil {
		return err
	}

	f, err := os.Create(configPath)
	if err != nil {
		return err
	}
	defer f.Close()

	encoder := toml.NewEncoder(f)
	return encoder.Encode(config)
}

// getSessionsDir retorna o diretório de sessões salvas
func getSessionsDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".config", "tms", "sessions")
}

// loadSessionDefinition carrega uma definição de sessão
func loadSessionDefinition(name string) (SessionDefinition, error) {
	var session SessionDefinition
	sessionFile := filepath.Join(getSessionsDir(), name+".toml")
	if _, err := toml.DecodeFile(sessionFile, &session); err != nil {
		return session, fmt.Errorf("erro ao carregar sessão: %w", err)
	}
	return session, nil
}

// saveSessionDefinition salva uma definição de sessão
func saveSessionDefinition(name string, session SessionDefinition) error {
	sessionsDir := getSessionsDir()
	if err := os.MkdirAll(sessionsDir, 0755); err != nil {
		return err
	}

	sessionFile := filepath.Join(sessionsDir, name+".toml")
	f, err := os.Create(sessionFile)
	if err != nil {
		return err
	}
	defer f.Close()

	encoder := toml.NewEncoder(f)
	return encoder.Encode(session)
}

// ListSavedSessions lista sessões salvas
func ListSavedSessions() ([]string, error) {
	sessionsDir := getSessionsDir()
	files, err := os.ReadDir(sessionsDir)
	if err != nil {
		return []string{}, nil
	}

	var names []string
	for _, file := range files {
		if strings.HasSuffix(file.Name(), ".toml") {
			name := strings.TrimSuffix(file.Name(), ".toml")
			names = append(names, name)
		}
	}
	return names, nil
}

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
}
EOF

# ========== 2. SUBSTITUIR SWITCH_MODEL.GO ==========

cat > switch_model.go << 'EOF'
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
EOF

# ========== 3. EXECUTAR GO MOD TIDY E BUILD ==========

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